/// Port of reference_python/shoulder_ds.py: the code path that
/// `analyze_video(d, ex, side, single_arm, ..., n_geo=0, rr_levels=())` runs (plain windows only).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/np_port.dart';
import '../core/pose_recording.dart';
import 'shoulder_lib.dart';

// ----------------------------------------------------------------------------- channels
const pointNames = [
  'nose',
  'ear_a',
  'ear_o',
  'sh_a',
  'sh_o',
  'el_a',
  'el_o',
  'wr_a',
  'wr_o',
  'hip_a',
  'hip_o',
];
final coordNames = [
  for (final p in pointNames)
    for (final ax in const ['x', 'y']) '${p}_$ax',
];
const angleCommon = [
  'elev_a',
  'elev_o',
  'abd_trunk_a',
  'elev_est_a',
  'elev_est_o',
  'elev3d_a',
  'elbow2d_a',
  'elbow2d_o',
  'elbow3d_a',
  'elbow3d_o',
  'wr_h_a',
  'wr_h_o',
  'ua_ratio_a',
  'lean_to_arm',
  'hike',
  'ear_sh',
];
const angleExtra = {
  'e1': ['stick_tilt', 'asym', 'lift'],
  'e2': <String>[],
  'e3': ['rot', 'el_out'],
};
const depthNames = ['wr_dz_a', 'el_dz_a', 'wr_dz_o', 'fa_ratio_a', 'rot3d_a'];
const basePoints = ['nose', 'ear_a', 'ear_o', 'sh_a', 'sh_o', 'hip_a', 'hip_o'];
const baseAngles = ['hike', 'ear_sh', 'lean_to_arm', 'elbow2d_a', 'elev_a'];
const baseExtra = {
  'e1': ['stick_tilt'],
  'e2': <String>[],
  'e3': ['el_out'],
};
const shldNames = [
  'hike_d0',
  'ear_sh_d0',
  'neck_ratio',
  'neck_ratio_d0',
  'hike3d',
  'hike3d_d0',
];
const gapNames = [
  'ua_abd',
  'ua_abd3d',
  'ua_abd_d0',
  'ua_abd3d_d0',
  'el_out_d0',
];
const baseNew = {
  'e1': ['neck_ratio', 'hike3d'],
  'e2': ['neck_ratio', 'hike3d'],
  'e3': ['ua_abd', 'ua_abd3d'],
};
const shldEx = {'e1', 'e2'}, gapEx = {'e3'};
const silArmNames = ['sil_gap_mean', 'sil_gap_min', 'sil_gap85', 'sil_contact'];
const silShNames = [
  'sil_neck_a',
  'sil_neck_ratio',
  'sil_shtop_a',
  'sil_neck_a_d0',
  'sil_shtop_a_d0',
];
const gatedNames = [
  'hike_g',
  'ear_sh_g',
  'neck_ratio_g',
  'hike3d_g',
  'sil_neck_g',
];
const double gateDeg = 100.0;
const gateKey = {'e1': 'elev_est_a', 'e2': 'elev_a'};
const double contactGap = 0.02;
const degNames = {
  'elev_a',
  'elev_o',
  'abd_trunk_a',
  'elev_est_a',
  'elev_est_o',
  'elev3d_a',
  'elbow2d_a',
  'elbow2d_o',
  'elbow3d_a',
  'elbow3d_o',
  'lean_to_arm',
  'stick_tilt',
  'asym',
  'rot3d_a',
  'ua_abd',
  'ua_abd3d',
};
const elevKey = {'e1': 'elev_mean', 'e2': 'elev_a', 'e3': 'elev_a'};
const groupOrder = [
  'coords',
  'angles',
  'depth',
  'base_pts',
  'base_ang',
  'shld',
  'gap',
  'base_new',
  'sil',
  'gated',
  'dur',
];
const silRaw = [
  'gap40',
  'gap55',
  'gap70',
  'gap85',
  'shtop65',
  'shtop80',
  'neck65',
  'neck80',
  'mask_ok',
];

Map<String, List<String>> channelGroups(String ex) => {
  'coords': coordNames,
  'angles': [...angleCommon, ...angleExtra[ex]!],
  'depth': depthNames,
  'base_pts': [
    for (final p in basePoints)
      for (final ax in const ['x', 'y']) '${p}_${ax}_rel',
  ],
  'base_ang': [
    for (final k in [...baseAngles, ...baseExtra[ex]!]) '${k}_rel',
  ],
  'shld': shldEx.contains(ex) ? shldNames : const [],
  'gap': gapEx.contains(ex) ? gapNames : const [],
  'base_new': [for (final k in baseNew[ex]!) '${k}_rel'],
  'sil': gapEx.contains(ex) ? silArmNames : silShNames,
  'gated': shldEx.contains(ex) ? gatedNames : const [],
  'dur': const ['log_duration'],
};

List<String> channelNames(String ex) {
  final g = channelGroups(ex);
  return [for (final name in groupOrder) ...g[name]!];
}

String _baseName(String name) {
  var n = name.startsWith('d_') ? name.substring(2) : name;
  for (final suf in const ['_rel', '_d0', '_g']) {
    if (n.endsWith(suf)) n = n.substring(0, n.length - suf.length);
  }
  return n;
}

double scaleOf(String name) => degNames.contains(_baseName(name)) ? 90.0 : 1.0;

List<int> pointIds(String arm) {
  final a = armIds[arm]!, o = armIds[otherSide[arm]]!;
  return [nose, a.ear, o.ear, a.sh, o.sh, a.el, o.el, a.wr, o.wr, a.hip, o.hip];
}

Float64List _frames(int n, double Function(int i) fn) {
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = fn(i);
  }
  return out;
}

/// sds._fill_cols for one column: linear interpolation over NaN, all-NaN -> 0.
Float64List fillCol(List<double> c) => fillNan(c) ?? Float64List(c.length);

// ----------------------------------------------------------------------------- per-frame signal groups
/// sds.canonical_coords: (n, 22) hip-centred, torso-length units, y up, mirrored so the arm is on +x.
List<Float64List> canonicalCoords(
  Resampled r,
  String arm, {
  double smoothS = 0.25,
}) {
  final n = r.n;
  double hmx(int i) => 0.5 * (r.px(i, lHip) + r.px(i, rHip));
  double hmy(int i) => 0.5 * (r.py(i, lHip) + r.py(i, rHip));
  final tl0 = torsoLen(r);
  final tl = tl0.isFinite && tl0 > 0 ? tl0 : 1.0;
  final sh = armIds[arm]!.sh;
  final qsx = _frames(n, (i) => (r.px(i, sh) - hmx(i)) / tl);
  final s = anyFinite(qsx) ? nanmedian(qsx) : 1.0;
  final flip = s >= 0 ? 1.0 : -1.0;
  final cols = <Float64List>[];
  for (final j in pointIds(arm)) {
    cols.add(_frames(n, (i) => ((r.px(i, j) - hmx(i)) / tl) * flip));
    cols.add(_frames(n, (i) => ((r.py(i, j) - hmy(i)) / tl) * -1.0));
  }
  if (smoothS > 0) return [for (final c in cols) smoothNan(c, r.fs, smoothS)];
  return cols;
}

/// sds.depth_signals: depth from the world landmarks (wr_dz_a, el_dz_a, wr_dz_o, fa_ratio_a, rot3d_a).
Map<String, Float64List> depthSignals(
  Resampled r,
  String arm,
  double outSign, {
  double smoothS = 0.25,
}) {
  final n = r.n;
  final a = armIds[arm]!, o = armIds[otherSide[arm]]!;
  bool anyW(int j) {
    for (var i = 0; i < n; i++) {
      if (r.wx(i, j).isFinite || r.wy(i, j).isFinite || r.wz(i, j).isFinite) {
        return true;
      }
    }
    return false;
  }

  double dist3(int i, int p, int q) {
    final dx = r.wx(i, p) - r.wx(i, q),
        dy = r.wy(i, p) - r.wy(i, q),
        dz = r.wz(i, p) - r.wz(i, q);
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  double armLen(ArmIds j) {
    final u = anyW(j.el)
        ? nanmedian(_frames(n, (i) => dist3(i, j.el, j.sh)))
        : double.nan;
    final f = anyW(j.wr)
        ? nanmedian(_frames(n, (i) => dist3(i, j.wr, j.el)))
        : double.nan;
    final l = u + f;
    return l.isFinite && l > 1e-6 ? l : 1.0;
  }

  final la = armLen(a), lo = armLen(o);
  final fa = _frames(n, (i) {
    final dx = r.px(i, a.wr) - r.px(i, a.el),
        dy = r.py(i, a.wr) - r.py(i, a.el);
    return math.sqrt(dx * dx + dy * dy);
  });
  final fa95 = anyFinite(fa) ? nanpercentile(fa, 95) : double.nan;
  final faOk = fa95.isFinite && fa95 > 0;
  var d = <String, Float64List>{
    'wr_dz_a': _frames(n, (i) => (r.wz(i, a.wr) - r.wz(i, a.sh)) / la),
    'el_dz_a': _frames(n, (i) => (r.wz(i, a.el) - r.wz(i, a.sh)) / la),
    'wr_dz_o': _frames(n, (i) => (r.wz(i, o.wr) - r.wz(i, o.sh)) / lo),
    'fa_ratio_a': _frames(n, (i) => faOk ? fa[i] / fa95 : fa[i] * double.nan),
    'rot3d_a': _frames(
      n,
      (i) => degrees(
        math.atan2(
          outSign * (r.wx(i, a.wr) - r.wx(i, a.el)),
          -(r.wz(i, a.wr) - r.wz(i, a.el)),
        ),
      ),
    ),
  };
  if (smoothS > 0) {
    d = {for (final e in d.entries) e.key: smoothNan(e.value, r.fs, smoothS)};
  }
  return d;
}

/// sds.extra_signals: neck_ratio, ua_abd, ua_abd3d, hike3d.
Map<String, Float64List> extraSignals(
  Resampled r,
  String arm,
  double outSign, {
  double smoothS = 0.25,
}) {
  final n = r.n;
  final a = armIds[arm]!, o = armIds[otherSide[arm]]!;
  double d2(int i, int p, int q) {
    final dx = r.px(i, p) - r.px(i, q), dy = r.py(i, p) - r.py(i, q);
    return math.sqrt(dx * dx + dy * dy);
  }

  final sw0 = nanmedian(_frames(n, (i) => d2(i, lSh, rSh)));
  final sw = sw0.isFinite && sw0 > 1e-9 ? sw0 : 1.0;
  final out = <String, Float64List>{};
  out['neck_ratio'] = _frames(n, (i) {
    final na = d2(i, a.ear, a.sh) / sw, no = d2(i, o.ear, o.sh) / sw;
    return na / (no > 1e-6 ? no : double.nan);
  });
  // 2D body axis and outward lateral axis
  out['ua_abd'] = _frames(n, (i) {
    final vx =
        0.5 * (r.px(i, lSh) + r.px(i, rSh)) -
        0.5 * (r.px(i, lHip) + r.px(i, rHip));
    final vy =
        0.5 * (r.py(i, lSh) + r.py(i, rSh)) -
        0.5 * (r.py(i, lHip) + r.py(i, rHip));
    final nn = math.sqrt(vx * vx + vy * vy);
    final dn = nn > 1e-9 ? nn : double.nan;
    final ux = vx / dn, uy = vy / dn;
    final lx = outSign * -uy, ly = outSign * ux;
    final ax = r.px(i, a.el) - r.px(i, a.sh),
        ay = r.py(i, a.el) - r.py(i, a.sh);
    return degrees(math.atan2(ax * lx + ay * ly, -(ax * ux + ay * uy)));
  });
  final upw = List<List<double>>.filled(n, const []);
  final across = List<List<double>>.filled(n, const []);
  final ua3 = Float64List(n);
  for (var i = 0; i < n; i++) {
    final v = [
      for (var c = 0; c < 3; c++)
        0.5 * (_w(r, i, a.sh, c) + _w(r, i, o.sh, c)) -
            0.5 * (_w(r, i, lHip, c) + _w(r, i, rHip, c)),
    ];
    upw[i] = _unit3(v);
    final ac = [
      for (var c = 0; c < 3; c++) _w(r, i, a.sh, c) - _w(r, i, o.sh, c),
    ];
    across[i] = ac;
    final dotAu = ac[0] * upw[i][0] + ac[1] * upw[i][1] + ac[2] * upw[i][2];
    final outw = _unit3([
      for (var c = 0; c < 3; c++) ac[c] - dotAu * upw[i][c],
    ]);
    final uaw = [
      for (var c = 0; c < 3; c++) _w(r, i, a.el, c) - _w(r, i, a.sh, c),
    ];
    ua3[i] = degrees(
      math.atan2(
        uaw[0] * outw[0] + uaw[1] * outw[1] + uaw[2] * outw[2],
        -(uaw[0] * upw[i][0] + uaw[1] * upw[i][1] + uaw[2] * upw[i][2]),
      ),
    );
  }
  out['ua_abd3d'] = ua3;
  final sww = nanmedian(
    _frames(
      n,
      (i) => math.sqrt(
        across[i][0] * across[i][0] +
            across[i][1] * across[i][1] +
            across[i][2] * across[i][2],
      ),
    ),
  );
  final swwOk = sww.isFinite && sww > 1e-9 ? sww : 1.0;
  out['hike3d'] = _frames(
    n,
    (i) =>
        (across[i][0] * upw[i][0] +
            across[i][1] * upw[i][1] +
            across[i][2] * upw[i][2]) /
        swwOk,
  );
  if (smoothS > 0) {
    return {
      for (final e in out.entries) e.key: smoothNan(e.value, r.fs, smoothS),
    };
  }
  return out;
}

double _w(Resampled r, int i, int j, int c) =>
    r.world[(i * kLandmarks + j) * 3 + c];

List<double> _unit3(List<double> v) {
  final nn = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
  final d = nn > 1e-9 ? nn : double.nan;
  return [v[0] / d, v[1] / d, v[2] / d];
}

// ----------------------------------------------------------------------------- silhouette
/// sds.resample_sil: (n, 2, K) silhouette measurements on the grid of r (side 0 = person's left), or null.
List<List<Float64List>>? resampleSil(
  PoseRecording d,
  Resampled r, {
  double maxGapS = 0.5,
}) {
  final sil = d.sil;
  if (sil == null || d.length == 0) return null;
  final k = d.silK;
  final t = [for (final v in d.tMs) v / 1000.0];
  final g = r.t;
  final out = List.generate(
    2,
    (_) => List.generate(
      k,
      (_) => Float64List(g.length)..fillRange(0, g.length, double.nan),
    ),
  );
  for (var s = 0; s < 2; s++) {
    for (var kk = 0; kk < k; kk++) {
      final tv = <double>[], xv = <double>[];
      for (var i = 0; i < d.length; i++) {
        final x = sil[(i * 2 + s) * k + kk];
        if (x.isFinite && t[i].isFinite) {
          tv.add(t[i]);
          xv.add(x);
        }
      }
      if (tv.length < 2) continue;
      final y = interp(g, tv, xv);
      for (var i = 0; i < g.length; i++) {
        final j = searchsorted(tv, g[i]).clamp(1, tv.length - 1);
        final dist = math.min((g[i] - tv[j - 1]).abs(), (tv[j] - g[i]).abs());
        out[s][kk][i] = dist > maxGapS || !r.valid[i] ? double.nan : f32(y[i]);
      }
    }
  }
  return out;
}

const silKeys = [
  'sil_gap_mean',
  'sil_gap_min',
  'sil_gap85',
  'sil_contact',
  'sil_neck_a',
  'sil_neck_o',
  'sil_neck_ratio',
  'sil_shtop_a',
  'sil_ok',
];

/// sds.sil_signals: per-frame silhouette signals of the arm of interest (a) and the other side (o).
Map<String, Float64List> silSignals(
  PoseRecording d,
  Resampled r,
  String arm, {
  double smoothS = 0.25,
}) {
  final s = resampleSil(d, r);
  final n = r.n;
  if (s == null) {
    return {
      for (final k in silKeys) k: Float64List(n)..fillRange(0, n, double.nan),
    };
  }
  final names = d.silNames ?? silRaw;
  final ia = arm == 'left' ? 0 : 1, io = arm == 'left' ? 1 : 0;
  List<Float64List> pick(int side, String pre) => [
    for (var c = 0; c < names.length; c++)
      if (names[c].startsWith(pre)) s[side][c],
  ];
  // float32 results of nanmean / nanmin over float32 columns
  Float64List rowStat(
    List<Float64List> cols,
    double Function(List<double>) fn,
  ) => _frames(n, (i) => f32(fn([for (final c in cols) c[i]])));
  final gcols = pick(ia, 'gap');
  final out = <String, Float64List>{
    'sil_gap_mean': rowStat(gcols, nanmean),
    'sil_gap_min': rowStat(gcols, nanmin),
    'sil_gap85': Float64List.fromList(gcols.last),
    'sil_contact': _frames(
      n,
      (i) => nanmean([
        for (final c in gcols)
          c[i].isFinite ? (c[i] <= contactGap ? 1.0 : 0.0) : double.nan,
      ]),
    ),
    'sil_neck_a': rowStat(pick(ia, 'neck'), nanmean),
    'sil_neck_o': rowStat(pick(io, 'neck'), nanmean),
    'sil_shtop_a': rowStat(pick(ia, 'shtop'), nanmean),
  };
  final okc = names.indexOf('mask_ok');
  out['sil_ok'] = okc >= 0
      ? Float64List.fromList(s[ia][okc])
      : (Float64List(n)..fillRange(0, n, double.nan));
  final na = out['sil_neck_a']!, no = out['sil_neck_o']!;
  out['sil_neck_ratio'] = _frames(
    n,
    (i) => f32(na[i] / (no[i].abs() > 1e-3 ? no[i] : double.nan)),
  );
  if (smoothS > 0) {
    return {
      for (final e in out.entries)
        e.key: (e.key == 'sil_contact' || e.key == 'sil_ok')
            ? e.value
            : smoothNan(e.value, r.fs, smoothS),
    };
  }
  return out;
}

// ----------------------------------------------------------------------------- first break
class Baseline {
  final int start, end;
  final String source;
  const Baseline(this.start, this.end, this.source);
}

/// sds.baseline_frames: the last baseS seconds before the first rep ('first_break'), else 0.5 s around the
/// lowest point of the count signal ('lowest_point').
Baseline baselineFrames(
  List<Rep> reps,
  Float64List? s,
  int n,
  double fs, {
  double baseS = 1.5,
  double gapS = 0.15,
  double minS = 0.4,
}) {
  if (reps.isNotEmpty && !reps[0].partial) {
    final end = reps[0].iStart - pyRound(gapS * fs);
    final start = math.max(0, end - pyRound(baseS * fs));
    if (end - start >= pyRound(minS * fs)) {
      return Baseline(start, end, 'first_break');
    }
  }
  if (s == null || !anyFinite(s)) {
    return Baseline(0, math.min(n, fs.toInt()), 'video_start');
  }
  final k = nanargmin(s), h = pyRound(0.25 * fs);
  return Baseline(math.max(0, k - h), math.min(n, k + h + 1), 'lowest_point');
}

// ----------------------------------------------------------------------------- windows
/// sds.rep_window: rep onset..end plus up to marginS of rest, never past the neighbouring valleys.
(int, int) repWindow(Rep rep, int n, double fs, double marginS) {
  final m = pyRound(marginS * fs);
  var w0 = rep.iStart - m, w1 = rep.iEnd + m;
  if (rep.iValleyL >= 0) w0 = math.max(w0, rep.iValleyL);
  if (rep.iValleyR >= 0) w1 = math.min(w1, rep.iValleyR);
  return (math.max(0, w0), math.min(n - 1, w1));
}

/// sds.to_T: linear resampling of the rows of a window (columns given separately) to T rows.
List<Float64List> toT(List<Float64List> cols, int len, int t) {
  if (len == 1) {
    return [for (final c in cols) Float64List(t)..fillRange(0, t, c[0])];
  }
  final xs = linspace(0, (len - 1).toDouble(), t);
  final out = [for (final _ in cols) Float64List(t)];
  for (var k = 0; k < t; k++) {
    final i0 = xs[k].floor();
    final i1 = math.min(i0 + 1, len - 1);
    final f = xs[k] - i0;
    for (var c = 0; c < cols.length; c++) {
      out[c][k] = cols[c][i0] * (1 - f) + cols[c][i1] * f;
    }
  }
  return out;
}

// ----------------------------------------------------------------------------- per-rep features
double _at(Float64List x, int i) => x[i].isFinite ? x[i] : double.nan;

double _seg(List<double> x, int i0, int i1, double Function(List<double>) fn) {
  final v = finiteOnly(x.sublist(i0, math.min(i1 + 1, x.length)));
  return v.isEmpty ? double.nan : fn(v);
}

List<double> _sl(List<double> x, int a, [int? b]) => x.sublist(
  math.min(a, x.length),
  b == null ? x.length : math.min(b, x.length),
);

/// sl.rep_features on a sample window (no valid mask, no valleys).
Map<String, double> repFeatures(
  Map<String, Float64List> sig,
  String ex,
  int i0,
  int ip,
  int i1,
  double amp,
  double fs,
) {
  double mx(String k) => _seg(sig[k]!, i0, i1, npMax);
  double mn(String k) => _seg(sig[k]!, i0, i1, npMin);
  double me(String k) => _seg(sig[k]!, i0, i1, npMean);
  double at(String k, [int? i]) => _at(sig[k]!, i ?? ip);
  final f = <String, double>{
    'duration_s': (i1 - i0) / fs,
    'up_s': (ip - i0) / fs,
    'down_s': (i1 - ip) / fs,
    'up_ratio': (ip - i0) / math.max(i1 - i0, 1),
    'amp': amp,
  };
  final lean = sig['lean_to_arm']!, lean0 = at('lean_to_arm', i0);
  f['lean_absmax'] = _seg(
    [for (final v in lean) (v - lean0).abs()],
    i0,
    i1,
    npMax,
  );
  f['hike_delta'] = at('hike') - at('hike', i0);
  if (ex == 'e1') {
    f.addAll({
      'lift_peak': at('lift'),
      'elev_mean_peak': at('elev_mean'),
      'elev_inj_peak': at('elev_est_a'),
      'elev_oth_peak': at('elev_est_o'),
      'asym_peak': at('asym'),
      'elev3d_inj_max': mx('elev3d_a'),
      'elev3d_oth_max': mx('elev3d_o'),
      'stick_tilt_peak': at('stick_tilt'),
      'stick_tilt_mean': me('stick_tilt'),
      'stick_tilt_absmax': _seg(
        [for (final v in sig['stick_tilt']!) v.abs()],
        i0,
        i1,
        npMax,
      ),
      'elbow3d_min': nanmin([mn('elbow3d_a'), mn('elbow3d_o')]),
      'elbow2d_peak': nanmean([at('elbow2d_a'), at('elbow2d_o')]),
    });
  } else if (ex == 'e2') {
    f.addAll({
      'elev_peak': at('elev_a'),
      'abd_trunk_peak': at('abd_trunk_a'),
      'elev_minus_trunk': at('elev_a') - at('abd_trunk_a'),
      'lean_delta': at('lean_to_arm') - at('lean_to_arm', i0),
      'ear_sh_delta': at('ear_sh') - at('ear_sh', i0),
      'elbow2d_peak': at('elbow2d_a'),
      'elbow2d_min': mn('elbow2d_a'),
      'elbow3d_min': mn('elbow3d_a'),
      'ua_ratio_peak': at('ua_ratio_a'),
      'other_elev_max': mx('elev_o'),
      'wr_h_peak': at('wr_h_a'),
    });
  } else if (ex == 'e3') {
    f.addAll({
      'rot_peak': at('rot'),
      'rot_deg_peak': at('rot_deg'),
      'el_out_max': mx('el_out'),
      'el_out_mean': me('el_out'),
      'el_out_delta': at('el_out') - at('el_out', i0),
      'abd_max': mx('elev_a'),
      'elbow3d_mean': me('elbow3d_a'),
    });
  }
  return f;
}

/// sds.angle_matched: shoulder measures when the arm passes 60 and 90 deg on the way up, and the hike slope.
Map<String, double> angleMatched(
  Map<String, Float64List> sig,
  int i0,
  int ip,
  String ex,
) {
  final keys = <String, String>{'hike': 'hike', 'earsh': 'ear_sh'};
  if (sig.containsKey('neck_ratio')) {
    keys.addAll({'neckr': 'neck_ratio', 'hike3d': 'hike3d'});
  }
  if (sig.containsKey('sil_neck_a')) keys['silneck'] = 'sil_neck_a';
  const levels = [60, 90];
  final out = <String, double>{
    for (final k in keys.keys)
      for (final l in levels) '${k}_at$l': double.nan,
    'hike_slope': double.nan,
  };
  if (ex != 'e1' && ex != 'e2') return out;
  final e = sig[ex == 'e2' ? 'elev_a' : 'elev_est_a']!;
  final up = e.sublist(i0, ip + 1);
  for (final l in levels) {
    final k = up.indexWhere((v) => v >= l);
    if (k > 0) {
      final j = i0 + k;
      final f = e[j] != e[j - 1] ? (l - e[j - 1]) / (e[j] - e[j - 1]) : 1.0;
      for (final kv in keys.entries) {
        final h = sig[kv.value]!;
        out['${kv.key}_at$l'] = h[j - 1] + f * (h[j] - h[j - 1]) - h[i0];
      }
    }
  }
  final hs = sig['hike']!.sublist(i0, ip + 1);
  final ux = <double>[], hy = <double>[];
  for (var i = 0; i < up.length; i++) {
    if (up[i].isFinite && hs[i].isFinite) {
      ux.add(up[i]);
      hy.add(hs[i]);
    }
  }
  if (ux.length >= 5 && ptp(ux) > 20) {
    out['hike_slope'] = polyfitSlope(ux, hy) * 90.0;
  }
  return out;
}

const phaseSignals = {
  'e1': [
    ('elbow3d_a', 'min'),
    ('elbow3d_o', 'min'),
    ('elbow2d_a', 'min'),
    ('stick_tilt', 'absmax'),
    ('hike', 'max'),
  ],
  'e2': [
    ('elbow2d_a', 'min'),
    ('elbow3d_a', 'min'),
    ('lean_to_arm', 'absmax'),
    ('hike', 'max'),
    ('ear_sh', 'min'),
  ],
  'e3': [
    ('el_out', 'max'),
    ('ua_abd', 'max'),
    ('ua_abd3d', 'max'),
    ('sil_gap_mean', 'max'),
    ('sil_gap85', 'max'),
    ('sil_contact', 'min'),
    ('elev_a', 'max'),
  ],
};
const bendSignals = {
  'e1': ['elbow3d_a', 'elbow2d_a'],
  'e2': ['elbow2d_a', 'elbow3d_a'],
  'e3': <String>[],
};

/// sds.features_v3 + features_v4 on one sample window: sm = per-frame signals of the window,
/// (st, pk, en) = rep start / peak / end inside the window.
Map<String, double> featuresV4(
  Map<String, Float64List> sm,
  String ex,
  int st,
  int pk,
  int en,
  double fs,
) {
  final cnt = sm['_count']!;
  final amp = cnt[pk] - math.min(cnt[st], cnt[en]);
  final f = repFeatures(sm, ex, st, pk, en, amp, fs);
  f.addAll(angleMatched(sm, st, pk, ex));
  final elev = sm[elevKey[ex]]!;
  final rb = nanmin(_sl(elev, 0, st + 1));
  final ra = en < elev.length
      ? nanmin(_sl(elev, en))
      : nanmin(_sl(elev, elev.length - 1));
  f['rest_before'] = rb;
  f['rest_after'] = ra;
  f['rest_max'] = nanmax([rb, ra]);
  List<double> seg(List<double> v) => _sl(v, st, en + 1);
  f['wr_dz_peak'] = sm['wr_dz_a']![pk];
  f['el_dz_mean'] = nanmean(seg(sm['el_dz_a']!));
  f['fa_ratio_min'] = nanmin(seg(sm['fa_ratio_a']!));
  f['rot3d_peak'] = sm['rot3d_a']![pk];
  for (final k in [...baseAngles, ...baseExtra[ex]!, ...baseNew[ex]!]) {
    final v = sm['${k}_rel']!;
    f['${k}_relpeak'] = v[pk];
    f['${k}_relmax'] = nanmax([for (final x in seg(v)) x.abs()]);
  }
  List<double> d0(String k) {
    final v = sm[k]!;
    final m = nanmean(_sl(v, 0, math.max(2, st)));
    return [for (final x in v) x - m];
  }

  if (shldEx.contains(ex)) {
    final nr = sm['neck_ratio']!, h3 = sm['hike3d']!;
    f.addAll({
      'neck_ratio_min': nanmin(seg(nr)),
      'neck_ratio_delta': nr[pk] - nr[st],
      'neck_ratio_d0min': nanmin(seg(d0('neck_ratio'))),
      'hike3d_delta': h3[pk] - h3[st],
      'hike3d_d0max': nanmax(seg(d0('hike3d'))),
      'hike_d0max': nanmax(seg(d0('hike'))),
      'ear_sh_d0min': nanmin(seg(d0('ear_sh'))),
    });
  }
  if (gapEx.contains(ex)) {
    for (final k in const ['ua_abd', 'ua_abd3d']) {
      final v = sm[k]!;
      f.addAll({
        '${k}_max': nanmax(seg(v)),
        '${k}_mean': nanmean(seg(v)),
        '${k}_delta': v[pk] - v[st],
        '${k}_d0max': nanmax(seg(d0(k))),
      });
    }
    f['el_out_d0max'] = nanmax(seg(d0('el_out')));
  }
  // features_v4 additions
  for (final (k, how) in phaseSignals[ex]!) {
    final v = sm[k];
    if (v == null) continue;
    for (final (ph, part) in [
      ('up', _sl(v, st, pk + 1)),
      ('dn', _sl(v, pk, en + 1)),
    ]) {
      if (how == 'min') {
        f['ph_${ph}_min_$k'] = nanmin(part);
      } else if (how == 'max') {
        f['ph_${ph}_max_$k'] = nanmax(part);
      } else {
        f['ph_${ph}_absmax_$k'] = nanmax([
          for (final x in part) (x - v[st]).abs(),
        ]);
      }
    }
    if (how == 'max') {
      f['ph_all_asym_$k'] = f['ph_dn_max_$k']! - f['ph_up_max_$k']!;
    }
  }
  for (final k in bendSignals[ex]!) {
    final v = sm[k]!;
    f['ph_top_bend_$k'] = v[st] - v[pk];
    f['ph_up_bendmax_$k'] = v[st] - nanmin(_sl(v, st, pk + 1));
  }
  if (shldEx.contains(ex)) {
    final e = seg(sm[gateKey[ex]]!);
    final low = [for (final v in e) v.isFinite && v <= gateDeg];
    final nLow = low.where((b) => b).length;
    List<double> lowOf(List<double> v) => [
      for (var i = 0; i < low.length; i++)
        if (low[i]) v[i],
    ];
    for (final (k, short, isMax) in const [
      ('hike', 'hike', true),
      ('hike3d', 'hike3d', true),
      ('neck_ratio', 'neckr', false),
      ('ear_sh', 'earsh', false),
      ('sil_neck_a', 'silneck', false),
    ]) {
      if (!sm.containsKey(k)) continue;
      final vals = lowOf(seg(d0(k)));
      f['shg_${short}_${isMax ? 'max' : 'min'}'] = nLow > 0
          ? (isMax ? nanmax(vals) : nanmin(vals))
          : double.nan;
    }
    final elow = lowOf(e);
    f['shg_hike_slope'] = nLow >= 5 && ptp(elow) > 15
        ? polyfitSlope(elow, lowOf(seg(d0('hike')))) * 90.0
        : double.nan;
    if (sm.containsKey('sil_neck_a')) {
      f['sil_neck_a_d0min'] = nanmin(seg(d0('sil_neck_a')));
      f['sil_shtop_a_d0max'] = nanmax(seg(d0('sil_shtop_a')));
      f['sil_neck_ratio_min'] = nanmin(seg(sm['sil_neck_ratio']!));
    }
  }
  if (gapEx.contains(ex) && sm.containsKey('sil_gap_mean')) {
    f.addAll({
      'sil_gap_mean_max': nanmax(seg(sm['sil_gap_mean']!)),
      'sil_gap_mean_mean': nanmean(seg(sm['sil_gap_mean']!)),
      'sil_gap_min_mean': nanmean(seg(sm['sil_gap_min']!)),
      'sil_gap85_max': nanmax(seg(sm['sil_gap85']!)),
      'sil_contact_mean': nanmean(seg(sm['sil_contact']!)),
      'sil_contact_min': nanmin(seg(sm['sil_contact']!)),
    });
  }
  if (sm.containsKey('sil_ok')) f['sil_ok_mean'] = nanmean(seg(sm['sil_ok']!));
  return f;
}

// ----------------------------------------------------------------------------- arm choice
/// sds.choose_arm: e2/e3 the arm that moves (the chosen side when it is not clear); e1 the side given.
(String, bool) chooseArm(Resampled r, String ex, String? side, bool singleArm) {
  final ev = sideEvidence(r);
  final ml = ev['motion_left']!, mr = ev['motion_right']!;
  if (singleArm) {
    final moving = ml >= mr ? 'left' : 'right';
    final clear = math.max(ml, mr) / math.max(math.min(ml, mr), 1e-6) >= 1.5;
    final arm = (clear || side == null) ? moving : side;
    return (arm, side != null && clear && moving != side);
  }
  if (side != null) return (side, false);
  final el = ev['elev95_left']!, er = ev['elev95_right']!;
  return ((!el.isNaN && !er.isNaN && el <= er) ? 'left' : 'right', false);
}
