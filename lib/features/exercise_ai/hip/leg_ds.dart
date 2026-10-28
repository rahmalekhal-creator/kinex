/// Port of e4_app_bundle/reference_python/leg_ds.py (exercise 4, standing hip abduction): the code path that
/// `analyze_video(d, side, n_geo=0, rr_levels=())` runs. Only the leg geometry is new; resampling, smoothing,
/// segmentation, baseline, windows and to_T are the shoulder port's (shared with e1-e3).
/// Unlike shoulder_lib, leg_ds casts the pixels to float64 first, so everything here is plain double arithmetic.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/np_port.dart';
import '../shoulder/shoulder_lib.dart' show Resampled, ang2, ang3, torsoLen;

// MediaPipe ids ('left' = the person's left)
const int _nose = 0;

class LegIds {
  final int hip, knee, ank, heel, foot, sh, wr;
  const LegIds(
    this.hip,
    this.knee,
    this.ank,
    this.heel,
    this.foot,
    this.sh,
    this.wr,
  );
}

const Map<String, LegIds> legIds = {
  'left': LegIds(23, 25, 27, 29, 31, 11, 15),
  'right': LegIds(24, 26, 28, 30, 32, 12, 16),
};
const Map<String, String> _other = {'left': 'right', 'right': 'left'};

/// Leg (hip -> ankle) away from the body axis: one rise and fall per rep.
const countSignalE4 = 'abd_leg_a';

const legPoints = [
  'nose',
  'sh_a',
  'sh_o',
  'wr_a',
  'wr_o',
  'hip_a',
  'hip_o',
  'knee_a',
  'knee_o',
  'ank_a',
  'ank_o',
  'foot_a',
  'foot_o',
];
const legAngles = [
  'abd_leg_a',
  'abd_thigh_a',
  'abd_leg_o',
  'knee2d_a',
  'knee2d_o',
  'knee3d_a',
  'knee3d_o',
  'lean_to_leg',
  'pelvis_tilt',
  'sh_tilt',
  'ank_h_a',
  'ank_lat_a',
  'foot_sep',
  'head_lat',
  'trunk_shift',
];
const legDepth = ['knee_dz_a', 'ank_dz_a', 'abd3d_a', 'lean3d'];
const legBasePoints = ['nose', 'sh_a', 'sh_o', 'hip_a', 'hip_o'];
const legBaseAngles = [
  'lean_to_leg',
  'pelvis_tilt',
  'sh_tilt',
  'knee2d_a',
  'knee2d_o',
  'abd_leg_a',
  'head_lat',
];

/// Signals stored / 90 (degrees).
const legDeg = {
  'abd_leg_a',
  'abd_thigh_a',
  'abd_leg_o',
  'knee2d_a',
  'knee2d_o',
  'knee3d_a',
  'knee3d_o',
  'lean_to_leg',
  'pelvis_tilt',
  'sh_tilt',
  'abd3d_a',
  'lean3d',
};

double _scale(String k) => legDeg.contains(k) ? 90.0 : 1.0;

/// lds.channel_names: coords, angles, depth, base points, base angles, log_duration.
List<String> legChannelNames() => [
  for (final p in legPoints)
    for (final ax in const ['x', 'y']) 'g4_${p}_$ax',
  for (final k in legAngles) 'g4_$k',
  for (final k in legDepth) 'g4_$k',
  for (final p in legBasePoints)
    for (final ax in const ['x', 'y']) 'g4_${p}_${ax}_rel',
  for (final k in legBaseAngles) 'g4_${k}_rel',
  'log_duration',
];

// ----------------------------------------------------------------------------- helpers
Float64List _frames(int n, double Function(int i) fn) {
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = fn(i);
  }
  return out;
}

/// lds._nanmed / _nanmin / _nanmax / _nanmean: NaN when nothing is finite.
double _nanmed(List<double> x) => anyFinite(x) ? nanmedian(x) : double.nan;
double _nanmin(List<double> x) => anyFinite(x) ? nanmin(x) : double.nan;
double _nanmax(List<double> x) => anyFinite(x) ? nanmax(x) : double.nan;
double _nanmean(List<double> x) => anyFinite(x) ? nanmean(x) : double.nan;

/// `float(np.sign(x) or 1.0)`: 0 -> 1, NaN stays NaN (NaN is truthy in Python).
double _signOr1(double x) {
  final s = sign(x);
  return s == 0 ? 1.0 : s;
}

double _norm2(double x, double y) => math.sqrt(x * x + y * y);
double _norm3(double x, double y, double z) => math.sqrt(x * x + y * y + z * z);

// ----------------------------------------------------------------------------- side
class LegChoice {
  final String leg;
  final bool sideConflict;
  final Map<String, double> span;
  const LegChoice(this.leg, this.sideConflict, this.span);
}

/// How far each ankle moves sideways (p95 - p5 of its offset from the hip midpoint, torso lengths) over the frames
/// [i0]..[i1] (inclusive; the whole recording by default).
Map<String, double> ankleSpan(Resampled r, [int i0 = 0, int? i1]) {
  final end = i1 ?? r.n - 1;
  final tl0 = torsoLen(r);
  final tl = tl0.isFinite && tl0 > 0 ? tl0 : 1.0;
  final out = <String, double>{};
  for (final s in const ['left', 'right']) {
    final ank = legIds[s]!.ank;
    final x = <double>[
      for (var i = i0; i <= end; i++)
        (r.px(i, ank) - 0.5 * (r.px(i, 23) + r.px(i, 24))) / tl,
    ];
    out[s] = anyFinite(x) ? nanpercentile(x, 95) - nanpercentile(x, 5) : 0.0;
  }
  return out;
}

/// The moving leg of [span], and whether it clearly (>= 1.5x) moves more than the other one.
(String, bool) _moving(Map<String, double> span) {
  final l = span['left']!, rr = span['right']!;
  final moving = l >= rr ? 'left' : 'right';
  final clear = math.max(l, rr) / math.max(math.min(l, rr), 1e-6) >= 1.5;
  return (moving, clear);
}

/// lds.choose_leg: the lifted leg = the ankle that moves most sideways; the given side decides when unclear.
LegChoice chooseLeg(Resampled r, String? side) {
  final span = ankleSpan(r);
  final (moving, clear) = _moving(span);
  final leg = (clear || side == null) ? moving : side;
  return LegChoice(leg, side != null && clear && moving != side, span);
}

/// True when, between frames [i0] and [i1], the leg other than [side] clearly moves more (the patient lifts the
/// wrong leg in this rep).
bool wrongLegInWindow(Resampled r, int i0, int i1, String side) {
  final (moving, clear) = _moving(ankleSpan(r, i0, i1));
  return clear && moving != side;
}

// ----------------------------------------------------------------------------- per-frame signals
class LegScalars {
  final double tl, ll, outSign;
  const LegScalars(this.tl, this.ll, this.outSign);
}

/// lds.compute_signals: per-frame signals of the lifted leg (a) and the standing leg (o), mirrored so the lifted
/// leg is always on the same side; each smoothed with sl.smooth_nan (0.25 s).
(Map<String, Float64List>, LegScalars) computeLegSignals(
  Resampled r,
  String leg, {
  double smoothS = 0.25,
}) {
  final n = r.n;
  final a = legIds[leg]!, o = legIds[_other[leg]]!;
  double px(int i, int j) => r.px(i, j);
  double py(int i, int j) => r.py(i, j);
  double hmx(int i) => 0.5 * (px(i, 23) + px(i, 24));
  double hmy(int i) => 0.5 * (py(i, 23) + py(i, 24));
  double smx(int i) => 0.5 * (px(i, 11) + px(i, 12));
  double smy(int i) => 0.5 * (py(i, 11) + py(i, 12));
  final trx = _frames(n, (i) => smx(i) - hmx(i));
  final tryy = _frames(n, (i) => smy(i) - hmy(i));
  var tl = _nanmed(_frames(n, (i) => _norm2(trx[i], tryy[i])));
  tl = tl.isFinite && tl > 0 ? tl : 1.0;
  final outSign = _signOr1(_nanmed(_frames(n, (i) => px(i, a.hip) - hmx(i))));
  // up = unit(trunk); down = -up; lat = out_sign * (-up_y, up_x)  (sideways, toward the lifted leg)
  final upx = Float64List(n), upy = Float64List(n);
  for (var i = 0; i < n; i++) {
    final nn = _norm2(trx[i], tryy[i]);
    final d = nn > 1e-9 ? nn : double.nan;
    upx[i] = trx[i] / d;
    upy[i] = tryy[i] / d;
  }
  double downX(int i) => -upx[i];
  double downY(int i) => -upy[i];
  double latX(int i) => outSign * -upy[i];
  double latY(int i) => outSign * upx[i];

  var anyOAnk = false;
  for (var i = 0; i < n && !anyOAnk; i++) {
    if (px(i, o.ank).isFinite || py(i, o.ank).isFinite) anyOAnk = true;
  }
  var ll = anyOAnk
      ? nanpercentile(
          _frames(
            n,
            (i) => _norm2(
              px(i, o.ank) - px(i, o.hip),
              py(i, o.ank) - py(i, o.hip),
            ),
          ),
          95,
        )
      : tl;
  ll = ll.isFinite && ll > 0 ? ll : tl;

  /// lds._signed_angle(v, ref_down, ref_out): angle of v away from ref_down, + toward ref_out.
  double signed(
    double vx,
    double vy,
    double dx,
    double dy,
    double ox,
    double oy,
  ) => degrees(math.atan2(vx * ox + vy * oy, vx * dx + vy * dy));

  final sig = <String, Float64List>{};
  sig['abd_leg_a'] = _frames(n, (i) {
    return signed(
      px(i, a.ank) - px(i, a.hip),
      py(i, a.ank) - py(i, a.hip),
      downX(i),
      downY(i),
      latX(i),
      latY(i),
    );
  });
  sig['abd_thigh_a'] = _frames(n, (i) {
    return signed(
      px(i, a.knee) - px(i, a.hip),
      py(i, a.knee) - py(i, a.hip),
      downX(i),
      downY(i),
      latX(i),
      latY(i),
    );
  });
  sig['abd_leg_o'] = _frames(n, (i) {
    return signed(
      px(i, o.ank) - px(i, o.hip),
      py(i, o.ank) - py(i, o.hip),
      downX(i),
      downY(i),
      -latX(i),
      -latY(i),
    );
  });
  Float64List knee2d(LegIds j) => _frames(
    n,
    (i) => ang2(
      px(i, j.hip) - px(i, j.knee),
      py(i, j.hip) - py(i, j.knee),
      px(i, j.ank) - px(i, j.knee),
      py(i, j.ank) - py(i, j.knee),
    ),
  );
  Float64List knee3d(LegIds j) => _frames(
    n,
    (i) => ang3(
      r.wx(i, j.hip) - r.wx(i, j.knee),
      r.wy(i, j.hip) - r.wy(i, j.knee),
      r.wz(i, j.hip) - r.wz(i, j.knee),
      r.wx(i, j.ank) - r.wx(i, j.knee),
      r.wy(i, j.ank) - r.wy(i, j.knee),
      r.wz(i, j.ank) - r.wz(i, j.knee),
    ),
  );
  sig['knee2d_a'] = knee2d(a);
  sig['knee2d_o'] = knee2d(o);
  sig['knee3d_a'] = knee3d(a);
  sig['knee3d_o'] = knee3d(o);
  sig['lean_to_leg'] = _frames(
    n,
    (i) => outSign * degrees(math.atan2(trx[i], -tryy[i])),
  );
  sig['pelvis_tilt'] = _frames(n, (i) {
    final hx = px(i, a.hip) - px(i, o.hip), hy = py(i, a.hip) - py(i, o.hip);
    return degrees(math.atan2(-hy, hx.abs() + 1e-9));
  });
  sig['sh_tilt'] = _frames(n, (i) {
    final sx = px(i, a.sh) - px(i, o.sh), sy = py(i, a.sh) - py(i, o.sh);
    return degrees(math.atan2(-sy, sx.abs() + 1e-9));
  });
  sig['ank_h_a'] = _frames(n, (i) => (py(i, o.ank) - py(i, a.ank)) / ll);
  sig['ank_lat_a'] = _frames(
    n,
    (i) =>
        ((px(i, a.ank) - hmx(i)) * latX(i) +
            (py(i, a.ank) - hmy(i)) * latY(i)) /
        tl,
  );
  sig['foot_sep'] = _frames(
    n,
    (i) =>
        _norm2(px(i, a.ank) - px(i, o.ank), py(i, a.ank) - py(i, o.ank)) / tl,
  );
  sig['head_lat'] = _frames(
    n,
    (i) =>
        ((px(i, _nose) - hmx(i)) * latX(i) +
            (py(i, _nose) - hmy(i)) * latY(i)) /
        tl,
  );
  sig['trunk_shift'] = _frames(
    n,
    (i) => (trx[i] * latX(i) + tryy[i] * latY(i)) / tl,
  );

  // 3D (MediaPipe world landmarks, metres, hip-centred, z < 0 = toward the camera)
  double hwx(int i) => 0.5 * (r.wx(i, 23) + r.wx(i, 24));
  double hwy(int i) => 0.5 * (r.wy(i, 23) + r.wy(i, 24));
  double hwz(int i) => 0.5 * (r.wz(i, 23) + r.wz(i, 24));
  double swx(int i) => 0.5 * (r.wx(i, 11) + r.wx(i, 12));
  double swy(int i) => 0.5 * (r.wy(i, 11) + r.wy(i, 12));
  double swz(int i) => 0.5 * (r.wz(i, 11) + r.wz(i, 12));
  List<double> unit3(double x, double y, double z) {
    final nn = _norm3(x, y, z);
    final d = nn > 1e-9 ? nn : double.nan;
    return [x / d, y / d, z / d];
  }

  sig['abd3d_a'] = _frames(n, (i) {
    final up = unit3(swx(i) - hwx(i), swy(i) - hwy(i), swz(i) - hwz(i));
    final ax = r.wx(i, a.hip) - r.wx(i, o.hip),
        ay = r.wy(i, a.hip) - r.wy(i, o.hip),
        az = r.wz(i, a.hip) - r.wz(i, o.hip);
    final dot = ax * up[0] + ay * up[1] + az * up[2];
    final out = unit3(ax - dot * up[0], ay - dot * up[1], az - dot * up[2]);
    final tx = r.wx(i, a.knee) - r.wx(i, a.hip),
        ty = r.wy(i, a.knee) - r.wy(i, a.hip),
        tz = r.wz(i, a.knee) - r.wz(i, a.hip);
    return degrees(
      math.atan2(
        tx * out[0] + ty * out[1] + tz * out[2],
        -(tx * up[0] + ty * up[1] + tz * up[2]),
      ),
    );
  });
  var lw = _nanmed(
    _frames(
      n,
      (i) => _norm3(
        r.wx(i, o.ank) - r.wx(i, o.hip),
        r.wy(i, o.ank) - r.wy(i, o.hip),
        r.wz(i, o.ank) - r.wz(i, o.hip),
      ),
    ),
  );
  lw = lw.isFinite && lw > 1e-6 ? lw : 1.0;
  sig['knee_dz_a'] = _frames(n, (i) => (r.wz(i, a.knee) - r.wz(i, a.hip)) / lw);
  sig['ank_dz_a'] = _frames(n, (i) => (r.wz(i, a.ank) - r.wz(i, a.hip)) / lw);
  final osw = _signOr1(_nanmed(_frames(n, (i) => r.wx(i, a.hip) - hwx(i))));
  sig['lean3d'] = _frames(
    n,
    (i) => osw * degrees(math.atan2(swx(i) - hwx(i), -(swy(i) - hwy(i)))),
  );

  if (smoothS > 0) {
    for (final k in sig.keys.toList()) {
      sig[k] = smoothNan(sig[k]!, r.fs, smoothS);
    }
  }
  return (sig, LegScalars(tl, ll, outSign));
}

/// lds.canonical_coords: (n, 26) hip-centred, torso-length units, y up, mirrored so the lifted leg is on +x.
List<Float64List> legCanonicalCoords(
  Resampled r,
  String leg, {
  double smoothS = 0.25,
}) {
  final n = r.n;
  double hmx(int i) => 0.5 * (r.px(i, 23) + r.px(i, 24));
  double hmy(int i) => 0.5 * (r.py(i, 23) + r.py(i, 24));
  final tl0 = torsoLen(r);
  final tl = tl0.isFinite && tl0 > 0 ? tl0 : 1.0;
  final a = legIds[leg]!, o = legIds[_other[leg]]!;
  final qhx = _frames(n, (i) => (r.px(i, a.hip) - hmx(i)) / tl);
  final s = anyFinite(qhx) ? nanmedian(qhx) : 1.0;
  final flip = s >= 0 ? 1.0 : -1.0;
  final ids = [
    _nose,
    a.sh,
    o.sh,
    a.wr,
    o.wr,
    a.hip,
    o.hip,
    a.knee,
    o.knee,
    a.ank,
    o.ank,
    a.foot,
    o.foot,
  ];
  final cols = <Float64List>[];
  for (final j in ids) {
    cols.add(_frames(n, (i) => ((r.px(i, j) - hmx(i)) / tl) * flip));
    cols.add(_frames(n, (i) => ((r.py(i, j) - hmy(i)) / tl) * -1.0));
  }
  if (smoothS > 0) return [for (final c in cols) smoothNan(c, r.fs, smoothS)];
  return cols;
}

// ----------------------------------------------------------------------------- frame matrix
/// lds._frame_matrix: the stored channels per frame (m, filled, legChannelNames order without log_duration) and the
/// signals of the per-rep measures (s: filled, all-NaN columns stay NaN).
class LegFrameMatrix {
  final List<Float64List> m;
  final Map<String, Float64List> s;
  const LegFrameMatrix(this.m, this.s);
}

Float64List _fillCol(List<double> c) => fillNan(c) ?? Float64List(c.length);

LegFrameMatrix legFrameMatrix(
  Resampled r,
  Map<String, Float64List> sig,
  String leg,
  int b0,
  int b1,
) {
  final n = r.n;
  final c = legCanonicalCoords(r, leg);
  final cols = <List<double>>[
    ...c,
    for (final k in legAngles) [for (final v in sig[k]!) v / _scale(k)],
    for (final k in legDepth) [for (final v in sig[k]!) v / _scale(k)],
  ];
  // first-break reference: per-column median over the baseline frames (all frames if they hold no finite value)
  List<double> medians(List<List<double>> m) {
    var ok = false;
    for (final col in m) {
      for (var i = b0; i < b1 && i < n; i++) {
        if (col[i].isFinite) ok = true;
      }
    }
    return [
      for (final col in m)
        () {
          final v = ok
              ? nanmedian(col.sublist(math.min(b0, n), math.min(b1, n)))
              : nanmedian(col);
          return v.isFinite ? v : 0.0;
        }(),
    ];
  }

  final pid = {for (var i = 0; i < legPoints.length; i++) legPoints[i]: i};
  final cb = [
    for (final p in legBasePoints)
      for (final j in const [0, 1]) c[2 * pid[p]! + j],
  ];
  final bC = medians(cb);
  for (var j = 0; j < cb.length; j++) {
    cols.add([for (final v in cb[j]) v - bC[j]]);
  }
  final ab = [for (final k in legBaseAngles) sig[k]!];
  final bA = medians(ab);
  for (var j = 0; j < legBaseAngles.length; j++) {
    final sc = _scale(legBaseAngles[j]);
    cols.add([for (final v in ab[j]) (v - bA[j]) / sc]);
  }
  final m = [for (final col in cols) _fillCol(col)];

  final sd = <String, List<double>>{...sig};
  for (var j = 0; j < legBaseAngles.length; j++) {
    sd['${legBaseAngles[j]}_rel'] = [for (final v in ab[j]) v - bA[j]];
  }
  sd['_count'] = sig[countSignalE4]!;
  final s = <String, Float64List>{
    for (final e in sd.entries)
      e.key: anyFinite(e.value)
          ? _fillCol(e.value)
          : Float64List.fromList(e.value),
  };
  return LegFrameMatrix(m, s);
}

// ----------------------------------------------------------------------------- per-rep measures
const _phase = [
  ('knee2d_a', 'min'),
  ('knee3d_a', 'min'),
  ('lean_to_leg', 'absmax'),
  ('pelvis_tilt', 'absmax'),
  ('abd_leg_a', 'max'),
];

/// lds.rep_features: per-rep measures of one window; [sm] = the per-frame signals on the window, [st]/[pk]/[en] the
/// rep's start / peak / end inside it. Keys are `g4_<name>`.
Map<String, double> legRepFeatures(
  Map<String, Float64List> sm,
  int st,
  int pk,
  int en,
  double fs,
) {
  Float64List v(String k) => sm[k]!;
  double at(String k, int i) => v(k)[i].isFinite ? v(k)[i] : double.nan;
  List<double> seg(List<double> x) => x.sublist(st, math.min(en + 1, x.length));
  List<double> rel(String k) {
    final a0 = at(k, st);
    final ref = a0.isFinite ? a0 : _nanmean(seg(v(k)));
    return [for (final x in v(k)) x - ref];
  }

  List<double> absl(List<double> x) => [for (final e in x) e.abs()];
  final c = v('_count');
  // Python's min(a, b): b only when b < a (NaN-safe the way Python is)
  final cMin = c[en] < c[st] ? c[en] : c[st];
  final f = <String, double>{
    'duration_s': (en - st) / fs,
    'up_s': (pk - st) / fs,
    'down_s': (en - pk) / fs,
    'up_ratio': (pk - st) / math.max(en - st, 1),
    'amp': c[pk] - cMin,
    'abd_leg_peak': at('abd_leg_a', pk),
    'abd_leg_max': _nanmax(seg(v('abd_leg_a'))),
    'abd_leg_rom': at('abd_leg_a', pk) - at('abd_leg_a', st),
    'abd_thigh_peak': at('abd_thigh_a', pk),
    'abd3d_peak': at('abd3d_a', pk),
    'abd_leg_o_max': _nanmax(seg(rel('abd_leg_o'))),
    'knee2d_a_min': _nanmin(seg(v('knee2d_a'))),
    'knee3d_a_min': _nanmin(seg(v('knee3d_a'))),
    'knee2d_a_peak': at('knee2d_a', pk),
    'knee_bend_top': at('knee2d_a', st) - at('knee2d_a', pk),
    'knee3d_bend_top': at('knee3d_a', st) - at('knee3d_a', pk),
    'knee2d_o_min': _nanmin(seg(v('knee2d_o'))),
    'knee3d_o_min': _nanmin(seg(v('knee3d_o'))),
    'lean_delta_peak': rel('lean_to_leg')[pk],
    'lean_delta_max': _nanmax(seg(rel('lean_to_leg'))),
    'lean_delta_min': _nanmin(seg(rel('lean_to_leg'))),
    'lean_absmax': _nanmax(absl(seg(rel('lean_to_leg')))),
    'lean3d_delta_peak': rel('lean3d')[pk],
    'lean3d_delta_max': _nanmax(seg(rel('lean3d'))),
    'lean3d_delta_min': _nanmin(seg(rel('lean3d'))),
    'pelvis_delta_peak': rel('pelvis_tilt')[pk],
    'pelvis_delta_max': _nanmax(seg(rel('pelvis_tilt'))),
    'pelvis_delta_min': _nanmin(seg(rel('pelvis_tilt'))),
    'sh_tilt_delta_peak': rel('sh_tilt')[pk],
    'head_lat_delta_peak': rel('head_lat')[pk],
    'head_lat_delta_max': _nanmax(seg(rel('head_lat'))),
    'head_lat_delta_min': _nanmin(seg(rel('head_lat'))),
    'trunk_shift_delta_peak': rel('trunk_shift')[pk],
    'ank_h_peak': at('ank_h_a', pk),
    'ank_lat_peak': at('ank_lat_a', pk),
    'foot_sep_peak': at('foot_sep', pk),
    'knee_dz_peak': at('knee_dz_a', pk),
    'ank_dz_peak': at('ank_dz_a', pk),
    'abd_rest_before': _nanmin(
      v('abd_leg_a').sublist(0, math.min(st + 1, c.length)),
    ),
    'abd_rest_after': _nanmin(v('abd_leg_a').sublist(math.min(en, c.length))),
  };
  for (final k in legBaseAngles) {
    // relative to the person's own posture before rep 1 (first break)
    final x = v('${k}_rel');
    f['${k}_relpeak'] = x[pk];
    f['${k}_relmax'] = _nanmax(absl(seg(x)));
  }
  for (final (k, how) in _phase) {
    // the way up and the way down separately
    final x = how != 'absmax' ? v(k) : absl(rel(k));
    final up = x.sublist(st, math.min(pk + 1, x.length));
    final dn = x.sublist(pk, math.min(en + 1, x.length));
    for (final (ph, part) in [('up', up), ('dn', dn)]) {
      f['ph_${ph}_${how}_$k'] = how == 'min' ? _nanmin(part) : _nanmax(part);
    }
  }
  return {for (final e in f.entries) 'g4_${e.key}': e.value};
}
