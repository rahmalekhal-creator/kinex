/// Port of reference_python/shoulder_lib.py (the parts analyze_video runs): resampling, side evidence,
/// per-frame signals, rep segmentation, and the causal on-screen counter.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/np_port.dart';
import '../core/pose_recording.dart';

// MediaPipe Pose landmark ids ('left' = the person's left)
const int nose = 0, lEar = 7, rEar = 8;
const int lSh = 11, rSh = 12, lEl = 13, rEl = 14, lWr = 15, rWr = 16;
const int lHip = 23, rHip = 24;

class ArmIds {
  final int sh, el, wr, hip, ear;
  const ArmIds(this.sh, this.el, this.wr, this.hip, this.ear);
}

const Map<String, ArmIds> armIds = {
  'left': ArmIds(lSh, lEl, lWr, lHip, lEar),
  'right': ArmIds(rSh, rEl, rWr, rHip, rEar),
};
const Map<String, String> otherSide = {'left': 'right', 'right': 'left'};
const Map<String, String> countSignal = {
  'e1': 'lift',
  'e2': 'elev_a',
  'e3': 'rot',
};
const List<List<int>> skeleton = [
  [11, 12],
  [11, 13],
  [13, 15],
  [12, 14],
  [14, 16],
  [11, 23],
  [12, 24],
  [23, 24],
  [23, 25],
  [25, 27],
  [24, 26],
  [26, 28],
  [0, 7],
  [0, 8],
];

/// sl.resample output: uniform grid, pixel coordinates and world landmarks (float32 values, as numpy).
class Resampled {
  final Float64List t;
  final Float64List p; // n x 33 x 2 pixels
  final Float64List world; // n x 33 x 3
  final List<bool> valid;
  final double w, h, fs;

  Resampled(this.t, this.p, this.world, this.valid, this.w, this.h, this.fs);

  int get n => t.length;
  double px(int i, int j) => p[(i * kLandmarks + j) * 2];
  double py(int i, int j) => p[(i * kLandmarks + j) * 2 + 1];
  double wx(int i, int j) => world[(i * kLandmarks + j) * 3];
  double wy(int i, int j) => world[(i * kLandmarks + j) * 3 + 1];
  double wz(int i, int j) => world[(i * kLandmarks + j) * 3 + 2];
}

/// sl.resample: uniform fs grid from the first to the last detected frame; linear interpolation;
/// gaps longer than maxGapS stay NaN (valid = false).
Resampled? resample(PoseRecording d, {double fs = 30.0, double maxGapS = 0.5}) {
  final n0 = d.length;
  var idx = <int>[];
  for (var i = 0; i < n0; i++) {
    final t = d.tMs[i] / 1000.0;
    if (d.lm[i * kLandmarks * 5].isFinite && t.isFinite) idx.add(i);
  }
  if (idx.length < 2) return null;
  var tv = [for (final i in idx) d.tMs[i] / 1000.0];
  var increasing = true;
  for (var k = 1; k < tv.length; k++) {
    if (tv[k] - tv[k - 1] <= 0) increasing = false;
  }
  if (!increasing) {
    // np.unique(tv, return_index=True): sorted unique times, first occurrence of each
    final order = List<int>.generate(tv.length, (k) => k);
    mergeSortBy(order, (a, b) => tv[a].compareTo(tv[b]));
    final ntv = <double>[], nidx = <int>[];
    for (final k in order) {
      if (ntv.isEmpty || tv[k] != ntv.last) {
        ntv.add(tv[k]);
        nidx.add(idx[k]);
      }
    }
    tv = ntv;
    idx = nidx;
  }
  final m = tv.length;
  final grid = arange(tv[0], tv[m - 1] + 0.5 / fs, 1.0 / fs);
  final n = grid.length;
  final p = Float64List(n * kLandmarks * 2);
  final wl = Float64List(n * kLandmarks * 3);
  final valid = List<bool>.filled(n, false);
  final sx = f32(d.width), sy = f32(d.height);
  for (var g = 0; g < n; g++) {
    final j = searchsorted(tv, grid[g], right: true);
    final j0 = (j - 1).clamp(0, m - 1), j1 = j.clamp(0, m - 1);
    final t0 = tv[j0], t1 = tv[j1];
    final span = t1 - t0;
    final w = f32(clip(span > 0 ? (grid[g] - t0) / span : 0.0, 0, 1));
    final near =
        math.min((grid[g] - t0).abs(), (t1 - grid[g]).abs()) <= 0.5 / fs;
    valid[g] = span <= maxGapS || near;
    final a = idx[j0], b = idx[j1];
    final w1 = f32(1 - w);
    for (var l = 0; l < kLandmarks; l++) {
      for (var c = 0; c < 2; c++) {
        final va = d.lm[(a * kLandmarks + l) * 5 + c],
            vb = d.lm[(b * kLandmarks + l) * 5 + c];
        final v = f32(f32(va * w1) + f32(vb * w));
        p[(g * kLandmarks + l) * 2 + c] = valid[g]
            ? f32(v * (c == 0 ? sx : sy))
            : double.nan;
      }
      for (var c = 0; c < 3; c++) {
        final va = d.world[(a * kLandmarks + l) * 3 + c],
            vb = d.world[(b * kLandmarks + l) * 3 + c];
        wl[(g * kLandmarks + l) * 3 + c] = valid[g]
            ? f32(f32(va * w1) + f32(vb * w))
            : double.nan;
      }
    }
  }
  return Resampled(grid, p, wl, valid, d.width, d.height, fs);
}

// ----------------------------------------------------------------------------- small vector helpers
double _norm2(double x, double y) => math.sqrt(x * x + y * y);
double _norm3(double x, double y, double z) => math.sqrt(x * x + y * y + z * z);

/// sl._ang for 2-D vectors (degrees).
double ang2(double ax, double ay, double bx, double by) {
  final c = (ax * bx + ay * by) / (_norm2(ax, ay) * _norm2(bx, by));
  return degrees(math.acos(clip(c, -1.0, 1.0)));
}

/// sl._ang for 3-D vectors (degrees).
double ang3(double ax, double ay, double az, double bx, double by, double bz) {
  final c =
      (ax * bx + ay * by + az * bz) / (_norm3(ax, ay, az) * _norm3(bx, by, bz));
  return degrees(math.acos(clip(c, -1.0, 1.0)));
}

Float64List _perFrame(int n, double Function(int i) fn) {
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = fn(i);
  }
  return out;
}

// numpy runs sl.side_evidence / sl.compute_signals on the float32 pixel array of sl.resample, so most of their
// arithmetic is float32 (Python floats such as TL are cast to float32 first). These helpers reproduce it:
// every float32 operation = the double result rounded to float32 (exact for + - * / sqrt).
double _sub(double a, double b) => f32(a - b);
double _mid(double a, double b) => 0.5 * f32(a + b);
double _div(double a, double b) => f32(a / f32(b));
double _norm2f(double x, double y) =>
    f32(math.sqrt(f32(f32(x * x) + f32(y * y))));
final double _k32 = f32(kRad2Deg);
double _deg32(double rad) => f32(f32(rad) * _k32);

/// sl.torso_len on float64 pixels (canonical_coords casts P to float64).
double torsoLen(Resampled r) => nanmedian(
  _perFrame(
    r.n,
    (i) => _norm2(
      0.5 * (r.px(i, lSh) + r.px(i, rSh)) -
          0.5 * (r.px(i, lHip) + r.px(i, rHip)),
      0.5 * (r.py(i, lSh) + r.py(i, rSh)) -
          0.5 * (r.py(i, lHip) + r.py(i, rHip)),
    ),
  ),
);

/// sl.torso_len on the float32 pixels (side_evidence).
double _torsoLen32(Resampled r) => nanmedian(
  _perFrame(
    r.n,
    (i) => _norm2f(
      _sub(
        _mid(r.px(i, lSh), r.px(i, rSh)),
        _mid(r.px(i, lHip), r.px(i, rHip)),
      ),
      _sub(
        _mid(r.py(i, lSh), r.py(i, rSh)),
        _mid(r.py(i, lHip), r.py(i, rHip)),
      ),
    ),
  ),
);

/// sl.side_evidence: how much each arm moves (wrist relative to shoulder, p95 - p5, torso units) and how
/// high each elbow goes (95th percentile of the vertical elevation estimate).
Map<String, double> sideEvidence(Resampled r) {
  final tl = _torsoLen32(r);
  final out = <String, double>{};
  for (final s in const ['left', 'right']) {
    final a = armIds[s]!;
    final rx = _perFrame(
      r.n,
      (i) => _div(_sub(r.px(i, a.wr), r.px(i, a.sh)), tl),
    );
    final ry = _perFrame(
      r.n,
      (i) => _div(_sub(r.py(i, a.wr), r.py(i, a.sh)), tl),
    );
    out['motion_$s'] = _norm2f(
      f32(f32(nanpercentile(rx, 95)) - f32(nanpercentile(rx, 5))),
      f32(f32(nanpercentile(ry, 95)) - f32(nanpercentile(ry, 5))),
    );
    final lu = nanpercentile(
      _perFrame(
        r.n,
        (i) => _norm2f(
          _sub(r.px(i, a.el), r.px(i, a.sh)),
          _sub(r.py(i, a.el), r.py(i, a.sh)),
        ),
      ),
      95,
    );
    final est = _perFrame(
      r.n,
      (i) => _deg32(
        math.acos(clip(_div(_sub(r.py(i, a.el), r.py(i, a.sh)), lu), -1, 1)),
      ),
    );
    out['elev95_$s'] = nanpercentile(est, 95);
  }
  return out;
}

class Scalars {
  final double tl, sw, outSign, luA, luO;
  const Scalars(this.tl, this.sw, this.outSign, this.luA, this.luO);
}

/// sl.compute_signals: per-frame angles and distances relative to the arm of interest (suffix _a) and the
/// other arm (_o), smoothed (Savitzky-Golay, smoothS seconds) with NaN positions kept.
/// float32 where numpy is float32; `_ang` (float64 on the float32 differences) and the smoothing in float64.
(Map<String, Float64List>, Scalars) computeSignals(
  Resampled r,
  String ex,
  String arm, {
  double smoothS = 0.25,
}) {
  final n = r.n;
  final a = armIds[arm]!, o = armIds[otherSide[arm]]!;
  double x(int i, int j) => r.px(i, j);
  double y(int i, int j) => r.py(i, j);
  double smx(int i) => _mid(x(i, lSh), x(i, rSh));
  double smy(int i) => _mid(y(i, lSh), y(i, rSh));
  double hmx(int i) => _mid(x(i, lHip), x(i, rHip));
  double hmy(int i) => _mid(y(i, lHip), y(i, rHip));
  double dx(int i, int p, int q) => _sub(x(i, p), x(i, q));
  double dy(int i, int p, int q) => _sub(y(i, p), y(i, q));
  double dw(int i, int p, int q, int c) => _sub(
    r.world[(i * kLandmarks + p) * 3 + c],
    r.world[(i * kLandmarks + q) * 3 + c],
  );
  final tx = _perFrame(n, (i) => _sub(smx(i), hmx(i))),
      ty = _perFrame(n, (i) => _sub(smy(i), hmy(i)));
  final tl = nanmedian(_perFrame(n, (i) => _norm2f(tx[i], ty[i])));
  final sw = nanmedian(
    _perFrame(n, (i) => _norm2f(dx(i, lSh, rSh), dy(i, lSh, rSh))),
  );
  final s0 = sign(nanmedian(_perFrame(n, (i) => _sub(x(i, a.sh), smx(i)))));
  final outSign = s0 == 0 ? 1.0 : s0; // `float(np.sign(...) or 1.0)`
  final upx = Float64List(n), upy = Float64List(n);
  for (var i = 0; i < n; i++) {
    final nn = _norm2f(tx[i], ty[i]);
    upx[i] = f32(tx[i] / nn);
    upy[i] = f32(ty[i] / nn);
  }
  final sig = <String, Float64List>{};
  sig['lean_to_arm'] = _perFrame(
    n,
    (i) => outSign * _deg32(math.atan2(tx[i], -ty[i])),
  );
  final lu = <String, double>{};
  for (final (tag, j) in [('a', a), ('o', o)]) {
    final uax = _perFrame(n, (i) => dx(i, j.el, j.sh)),
        uay = _perFrame(n, (i) => dy(i, j.el, j.sh));
    final l = nanpercentile(_perFrame(n, (i) => _norm2f(uax[i], uay[i])), 95);
    lu[tag] = l;
    sig['elev_$tag'] = _perFrame(n, (i) => ang2(uax[i], uay[i], 0.0, 1.0));
    sig['abd_trunk_$tag'] = _perFrame(
      n,
      (i) => ang2(uax[i], uay[i], dx(i, j.hip, j.sh), dy(i, j.hip, j.sh)),
    );
    sig['elev_est_$tag'] = _perFrame(
      n,
      (i) => _deg32(math.acos(clip(_div(dy(i, j.el, j.sh), l), -1, 1))),
    );
    sig['elbow2d_$tag'] = _perFrame(
      n,
      (i) => ang2(
        dx(i, j.sh, j.el),
        dy(i, j.sh, j.el),
        dx(i, j.wr, j.el),
        dy(i, j.wr, j.el),
      ),
    );
    sig['wr_h_$tag'] = _perFrame(n, (i) => _div(_sub(smy(i), y(i, j.wr)), tl));
    sig['ua_ratio_$tag'] = _perFrame(
      n,
      (i) => _div(_norm2f(uax[i], uay[i]), l),
    );
    sig['elbow3d_$tag'] = _perFrame(
      n,
      (i) => ang3(
        dw(i, j.sh, j.el, 0),
        dw(i, j.sh, j.el, 1),
        dw(i, j.sh, j.el, 2),
        dw(i, j.wr, j.el, 0),
        dw(i, j.wr, j.el, 1),
        dw(i, j.wr, j.el, 2),
      ),
    );
    sig['elev3d_$tag'] = _perFrame(
      n,
      (i) => ang3(
        dw(i, j.el, j.sh, 0),
        dw(i, j.el, j.sh, 1),
        dw(i, j.el, j.sh, 2),
        dw(i, j.hip, j.sh, 0),
        dw(i, j.hip, j.sh, 1),
        dw(i, j.hip, j.sh, 2),
      ),
    );
  }
  double along(int i, double vx, double vy) =>
      f32(f32(vx * upx[i]) + f32(vy * upy[i]));
  sig['hike'] = _perFrame(
    n,
    (i) => _div(along(i, dx(i, a.sh, o.sh), dy(i, a.sh, o.sh)), sw),
  );
  sig['ear_sh'] = _perFrame(
    n,
    (i) => _div(along(i, dx(i, a.ear, a.sh), dy(i, a.ear, a.sh)), sw),
  );
  if (ex == 'e1') {
    final wa = sig['wr_h_a']!, wo = sig['wr_h_o']!;
    sig['lift'] = _perFrame(n, (i) {
      if (wa[i].isNaN) return wo[i];
      if (wo[i].isNaN) return wa[i];
      return f32(wa[i] + wo[i]) * 0.5;
    });
    sig['stick_tilt'] = _perFrame(
      n,
      (i) => _deg32(math.atan2(dy(i, a.wr, o.wr), dx(i, a.wr, o.wr).abs())),
    );
    final ea = sig['elev_est_a']!, eo = sig['elev_est_o']!;
    sig['asym'] = _perFrame(n, (i) => f32(eo[i] - ea[i]));
    sig['elev_mean'] = _perFrame(n, (i) => 0.5 * f32(ea[i] + eo[i]));
  } else if (ex == 'e3') {
    final p95 = nanpercentile(
      _perFrame(n, (i) => _norm2f(dx(i, a.wr, a.el), dy(i, a.wr, a.el))),
      95,
    );
    final alt = 0.78 * lu['a']!;
    final lf = p95.isNaN
        ? p95
        : (alt > p95 ? alt : p95); // Python max(p95, alt)
    sig['rot'] = _perFrame(n, (i) => _div(outSign * dx(i, a.wr, a.el), lf));
    final rot = sig['rot']!;
    sig['rot_deg'] = _perFrame(
      n,
      (i) => _deg32(math.asin(clip(rot[i], -1, 1))),
    );
    final lim = f32(1e-6);
    sig['el_out'] = _perFrame(n, (i) {
      final dyb = dy(i, a.hip, a.sh);
      final frac = f32(
        dy(i, a.el, a.sh) / (dyb.abs() > lim ? dyb : double.nan),
      );
      final line = f32(x(i, a.sh) + f32(dx(i, a.hip, a.sh) * frac));
      return _div(outSign * _sub(x(i, a.el), line), sw);
    });
  }
  if (smoothS > 0) {
    for (final k in sig.keys.toList()) {
      sig[k] = smoothNan(sig[k]!, r.fs, smoothS);
    }
  }
  return (sig, Scalars(tl, sw, outSign, lu['a']!, lu['o']!));
}

// ----------------------------------------------------------------------------- rep segmentation
class Rep {
  final int iStart, iPeak, iEnd, iValleyL, iValleyR;
  final double prominence, amp;
  final bool partial;
  const Rep(
    this.iStart,
    this.iPeak,
    this.iEnd,
    this.iValleyL,
    this.iValleyR,
    this.prominence,
    this.amp,
    this.partial,
  );
}

/// sl.segment_reps: peaks with a prominence >= prominence x (p95 - p5) and >= minRelAmp x the median peak,
/// at least 0.8 x minRepS apart; the signal is padded with its rest level so cut reps are found (partial).
/// Returns the reps and the smoothed signal (null when the signal is too short or missing).
(List<Rep>, Float64List?) segmentReps(
  List<double> x,
  double fs, {
  double minRepS = 0.6,
  double maxRepS = 20.0,
  double prominence = 0.35,
  double onset = 0.10,
  double minRelAmp = 0.35,
  double minDurS = 0.4,
  double polarity = 1.0,
  double smoothS = 0.4,
  double edgePadS = 1.0,
}) {
  final filled = fillNan(x);
  if (filled == null || filled.length < (2 * fs).toInt()) {
    return (<Rep>[], null);
  }
  final s = smoothNan(filled, fs, smoothS);
  for (var i = 0; i < s.length; i++) {
    s[i] = polarity * s[i];
  }
  final lo = percentile(s, 5), hi = percentile(s, 95);
  final rng = hi - lo;
  if (!rng.isFinite || rng <= 1e-9) return (<Rep>[], s);
  final n = s.length, pad = math.max(1, pyRound(edgePadS * fs));
  final sp = Float64List(n + 2 * pad)..fillRange(0, n + 2 * pad, lo);
  sp.setRange(pad, pad + n, s);
  final pk = findPeaks(
    sp,
    prominence: prominence * rng,
    distance: math.max(1, (0.8 * minRepS * fs).toInt()).toDouble(),
  );
  final peaks = <int>[], proms = <double>[];
  for (var k = 0; k < pk.peaks.length; k++) {
    if (pk.peaks[k] >= pad && pk.peaks[k] < pad + n) {
      peaks.add(pk.peaks[k]);
      proms.add(pk.prominences[k]);
    }
  }
  if (peaks.isEmpty) return (<Rep>[], s);
  final med = nanmedian(proms);
  final kp = <int>[], kpr = <double>[];
  for (var k = 0; k < peaks.length; k++) {
    if (proms[k] >= minRelAmp * med) {
      kp.add(peaks[k]);
      kpr.add(proms[k]);
    }
  }
  final bigN = sp.length, maxw = (maxRepS * fs).toInt();
  int toReal(int i) => math.min(math.max(i - pad, 0), n - 1);
  final reps = <Rep>[];
  for (var k = 0; k < kp.length; k++) {
    final p = kp[k];
    final lb = k > 0 ? kp[k - 1] : math.max(0, p - maxw);
    final rb = k < kp.length - 1 ? kp[k + 1] : math.min(bigN - 1, p + maxw);
    final vl = lb + argminRange(sp, lb, p);
    final vr = p + argminRange(sp, p, rb);
    final thrL = sp[vl] + onset * (sp[p] - sp[vl]);
    final thrR = sp[vr] + onset * (sp[p] - sp[vr]);
    var lastBelowL = -1;
    for (var i = vl; i <= p; i++) {
      if (sp[i] <= thrL) lastBelowL = i - vl;
    }
    var firstBelowR = -1;
    for (var i = p; i <= vr; i++) {
      if (sp[i] <= thrR) {
        firstBelowR = i - p;
        break;
      }
    }
    final start = vl + (lastBelowL >= 0 ? lastBelowL : 0);
    final end = p + (firstBelowR >= 0 ? firstBelowR : vr - p);
    final dur = (end - start) / fs;
    if (dur < minDurS || dur > maxRepS) continue;
    final partial = start < pad || end > pad + n - 1;
    reps.add(
      Rep(
        toReal(start),
        p - pad,
        toReal(end),
        (pad <= vl && vl < pad + n) ? vl - pad : -1,
        (pad <= vr && vr < pad + n) ? vr - pad : -1,
        kpr[k],
        sp[p] - math.min(sp[vl], sp[vr]),
        partial,
      ),
    );
  }
  return (reps, s);
}

/// sl.online_count: causal counter (exponential smoothing; a rep = a rise of up x refAmp above the last low
/// point followed by a fall of drop x refAmp below the rep's high point). Feed samples one at a time.
class OnlineCounter {
  final double alpha, refAmp, up, drop, polarity;
  double? _y, _lo, _hi;
  int _state = 0;
  int count = 0;
  final List<int> events = [];
  int _i = -1;

  OnlineCounter(
    double fs,
    this.refAmp, {
    this.up = 0.3,
    this.drop = 0.3,
    double tauS = 0.1,
    this.polarity = 1.0,
  }) : alpha = 1.0 - math.exp(-1.0 / (fs * tauS));

  /// Returns true when this sample completes a rep.
  bool add(double v) {
    _i++;
    if (!v.isFinite) return false;
    v *= polarity;
    final y = _y = _y == null ? v : _y! + alpha * (v - _y!);
    if (_state == 0) {
      _lo = _lo == null ? y : math.min(_lo!, y);
      if (y >= _lo! + up * refAmp) {
        _state = 1;
        _hi = y;
      }
    } else {
      _hi = math.max(_hi!, y);
      if (y <= _hi! - drop * refAmp) {
        count++;
        events.add(_i);
        _state = 0;
        _lo = y;
        return true;
      }
    }
    return false;
  }
}
