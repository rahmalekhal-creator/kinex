/// One recording -> reps -> model inputs (x, f) -> verdicts. Port of `sds.analyze_video` (n_geo=0, rr_levels=())
/// and `reference_predict.head_inputs / run_reference / verdict`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/np_port.dart';
import '../core/pose_recording.dart';
import 'shoulder_config.dart';
import 'shoulder_ds.dart';
import 'shoulder_lib.dart';

/// Per-frame matrix of `_frame_matrix`: model channels (M, filled) and feature signals (S).
class FrameMatrix {
  final Map<String, Float64List>
  m; // stored channels that do not depend on the sample
  final List<String> names;
  final Map<String, Float64List>
  s; // signals for the features (all-NaN columns stay NaN)

  FrameMatrix(this.m, this.names, this.s);
}

FrameMatrix frameMatrix(
  Resampled r,
  Map<String, Float64List> sig,
  Scalars scal,
  String ex,
  String arm,
  int b0,
  int b1,
  String countKey,
  Map<String, Float64List> silsig,
) {
  final n = r.n;
  final allsig = <String, Float64List>{...sig}
    ..addAll(depthSignals(r, arm, scal.outSign))
    ..addAll(extraSignals(r, arm, scal.outSign))
    ..addAll(silsig);
  final g = channelGroups(ex);
  final c = canonicalCoords(r, arm);
  final plain = [
    ...g['angles']!,
    ...g['depth']!,
    for (final k in [...g['shld']!, ...g['gap']!, ...g['sil']!])
      if (!k.endsWith('_d0')) k,
  ];
  final raw = <String, List<double>>{};
  for (var j = 0; j < coordNames.length; j++) {
    raw[coordNames[j]] = c[j];
  }
  for (final k in plain) {
    final sc = scaleOf(k);
    raw[k] = [for (final v in allsig[k]!) v / sc];
  }
  // first-break reference: median over the baseline frames (whole recording if they hold no finite value)
  List<double> medians(List<List<double>> cols) {
    var any = false;
    for (final col in cols) {
      for (var i = b0; i < b1 && i < n; i++) {
        if (col[i].isFinite) any = true;
      }
    }
    return [
      for (final col in cols)
        () {
          final v = any
              ? nanmedian(col.sublist(math.min(b0, n), math.min(b1, n)))
              : nanmedian(col);
          return v.isFinite ? v : 0.0;
        }(),
    ];
  }

  final pid = {for (var i = 0; i < pointNames.length; i++) pointNames[i]: i};
  final cbCols = [
    for (final p in basePoints)
      for (final j in const [0, 1]) c[2 * pid[p]! + j],
  ];
  final bC = medians(cbCols);
  final basePtNames = g['base_pts']!;
  for (var j = 0; j < cbCols.length; j++) {
    raw[basePtNames[j]] = [for (final v in cbCols[j]) v - bC[j]];
  }
  final baseKeys = [...baseAngles, ...baseExtra[ex]!, ...baseNew[ex]!];
  final abCols = [for (final k in baseKeys) allsig[k]!];
  final bA = medians(abCols);
  for (var j = 0; j < baseKeys.length; j++) {
    final sc = scaleOf(baseKeys[j]);
    raw['${baseKeys[j]}_rel'] = [for (final v in abCols[j]) (v - bA[j]) / sc];
  }
  final names = [
    ...coordNames,
    ...plain,
    ...basePtNames,
    for (final k in baseKeys) '${k}_rel',
  ];
  final m = {for (final k in names) k: fillCol(raw[k]!)};
  final sd = <String, List<double>>{...allsig};
  for (var j = 0; j < baseKeys.length; j++) {
    sd['${baseKeys[j]}_rel'] = [for (final v in abCols[j]) v - bA[j]];
  }
  sd['_count'] = sig[countKey]!;
  final s = <String, Float64List>{};
  for (final e in sd.entries) {
    s[e.key] = anyFinite(e.value)
        ? fillCol(e.value)
        : Float64List.fromList(e.value);
  }
  return FrameMatrix(m, names, s);
}

/// sds._sample_channels: stored channels of one window (channel_names(ex) order, without log_duration).
List<Float64List> sampleChannels(
  Map<String, Float64List> mw,
  int len,
  String ex,
  int start,
) {
  final k0 = math.max(2, start);
  final gk = gateKey[ex];
  List<int>? hold;
  if (gk != null && mw.containsKey(gk)) {
    final gcol = mw[gk]!;
    final sc = scaleOf(gk);
    hold = List<int>.filled(len, 0);
    var run = 0;
    for (var i = 0; i < len; i++) {
      final idx = gcol[i] * sc <= gateDeg ? i : 0;
      run = math.max(run, idx);
      hold[i] = run;
    }
  }
  final names = channelNames(ex);
  final out = <Float64List>[];
  for (final nm in names.sublist(0, names.length - 1)) {
    if (mw.containsKey(nm)) {
      out.add(mw[nm]!);
    } else if (nm.endsWith('_g')) {
      final v =
          mw[nm == 'sil_neck_g'
              ? 'sil_neck_a'
              : nm.substring(0, nm.length - 2)]!;
      final m = npMean(v.sublist(0, math.min(k0, len)));
      final d = Float64List.fromList([for (final x in v) x - m]);
      out.add(
        hold == null ? d : Float64List.fromList([for (final h in hold) d[h]]),
      );
    } else {
      final v = mw[nm.substring(0, nm.length - 3)]!;
      final m = npMean(v.sublist(0, math.min(k0, len)));
      out.add(Float64List.fromList([for (final x in v) x - m]));
    }
  }
  return out;
}

class RepRow {
  final int rep; // 1-based, as analyze_video rows
  final Rep seg;
  final bool usable;
  final double tStart, tPeak, tEnd;
  const RepRow(
    this.rep,
    this.seg,
    this.usable,
    this.tStart,
    this.tPeak,
    this.tEnd,
  );
}

/// Output of [analyzeVideo] for one head.
class Analysis {
  final String exercise, arm;
  final bool sideConflict;
  final Resampled r;
  final Map<String, Float64List> sig;
  final List<RepRow> rows;
  final Float64List? s;
  final Baseline baseline;
  final List<int> use; // indices into rows
  final List<List<Float32List>> x; // per scored rep: C_sel x T
  final List<Float32List> f; // per scored rep: head features
  final FrameMatrix? frames;

  Analysis(
    this.exercise,
    this.arm,
    this.sideConflict,
    this.r,
    this.sig,
    this.rows,
    this.s,
    this.baseline,
    this.use,
    this.x,
    this.f,
    this.frames,
  );
}

/// sds.analyze_video(d, ex, side, single_arm, ..., n_geo=0, rr_levels=()) followed by head_inputs.
Analysis? analyzeVideo(
  PoseRecording d,
  String ex,
  String? side,
  AnalyzeConfig cfg,
  HeadConfig head, {
  bool keepFrames = false,
}) {
  final fs = cfg.fs;
  final r = resample(d, fs: fs, maxGapS: cfg.maxGapS);
  if (r == null) return null;
  final (arm, conflict) = chooseArm(r, ex, side, singleArm[ex]!);
  final (sig, scal) = computeSignals(r, ex, arm);
  final countKey = countSignal[ex]!;
  final sc = cfg.seg[ex]!;
  final (reps, s) = segmentReps(
    sig[countKey]!,
    fs,
    minRepS: sc.minRepS,
    maxRepS: sc.maxRepS,
    prominence: sc.prominence,
  );
  final n = r.n;
  final base = baselineFrames(
    reps,
    s,
    n,
    fs,
    baseS: cfg.baseS,
    gapS: cfg.gapS,
    minS: cfg.minS,
  );
  final rows = <RepRow>[];
  for (var k = 0; k < reps.length; k++) {
    final rp = reps[k];
    var nv = 0;
    for (var i = rp.iStart; i <= rp.iEnd; i++) {
      if (r.valid[i]) nv++;
    }
    final validFrac = nv / (rp.iEnd - rp.iStart + 1);
    final (w0, w1) = repWindow(rp, n, fs, cfg.marginS);
    final usable = !rp.partial && validFrac >= cfg.minValid && w1 - w0 >= 3;
    rows.add(
      RepRow(k + 1, rp, usable, r.t[rp.iStart], r.t[rp.iPeak], r.t[rp.iEnd]),
    );
  }
  final use = [
    for (var i = 0; i < rows.length; i++)
      if (rows[i].usable) i,
  ];
  final silsig = silSignals(d, r, arm);
  final fm = frameMatrix(
    r,
    sig,
    scal,
    ex,
    arm,
    base.start,
    base.end,
    countKey,
    silsig,
  );
  final xs = <List<Float32List>>[], fs2 = <Float32List>[];
  final stored = channelNames(ex);
  for (final i in use) {
    final rp = reps[i];
    final (w0, w1) = repWindow(rp, n, fs, cfg.marginS);
    final len = w1 - w0 + 1;
    final mw = {
      for (final e in fm.m.entries)
        e.key: Float64List.sublistView(e.value, w0, w1 + 1),
    };
    final st = rp.iStart - w0, pk = rp.iPeak - w0, en = rp.iEnd - w0;
    final ch = toT(sampleChannels(mw, len, ex, st), len, cfg.tLen);
    final logDur = math.log(math.max((rp.iEnd - rp.iStart) / fs, 0.1));
    final all = {for (var c = 0; c < ch.length; c++) stored[c]: ch[c]};
    xs.add([
      for (final ci in head.inputSelection)
        ci == stored.length - 1
            ? (Float32List(cfg.tLen)..fillRange(0, cfg.tLen, logDur))
            : Float32List.fromList(all[stored[ci]]!),
    ]);
    final sm = {
      for (final e in fm.s.entries)
        e.key: Float64List.sublistView(e.value, w0, w1 + 1),
    };
    final feats = featuresV4(sm, ex, st, pk, en, fs);
    fs2.add(
      Float32List.fromList([
        for (final nm in head.features) feats[nm] ?? double.nan,
      ]),
    );
  }
  return Analysis(
    ex,
    arm,
    conflict,
    r,
    sig,
    rows,
    s,
    base,
    use,
    xs,
    fs2,
    keepFrames ? fm : null,
  );
}

/// Verdict of one rep (reference_predict.verdict).
class Verdict {
  final String label, status, message;
  final double confidence;
  final List<double> probs;
  const Verdict(
    this.label,
    this.status,
    this.message,
    this.confidence,
    this.probs,
  );
}

Verdict verdict(
  FeedbackSpec fb,
  HeadConfig head,
  List<double> probs,
  String? side,
) {
  var k = 0;
  for (var i = 1; i < probs.length; i++) {
    if (probs[i] > probs[k]) k = i;
  }
  final label = head.classes[k], conf = probs[k];
  if (conf < fb.minConfidence) {
    return Verdict(label, 'unsure', fb.unsure, conf, probs);
  }
  final msg = fb.messages[head.exercise]![label]!.replaceAll(
    '{arm}',
    side ?? '',
  );
  return Verdict(label, label == 'good' ? 'good' : 'mistake', msg, conf, probs);
}
