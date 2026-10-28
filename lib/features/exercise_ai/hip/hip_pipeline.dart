/// Exercise 4 (standing hip abduction): one recording -> reps -> model inputs (x, f) -> verdicts with the range
/// rule. Port of `leg_ds.analyze_video(d, side, n_geo=0, rr_levels=())` and of reference_predict_e4
/// (head_inputs, range_target, verdict). Settings: models/e4_head.json and app_spec_e4.json (nothing hard-coded).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/np_port.dart';
import '../core/pose_recording.dart';
import '../shoulder/shoulder_config.dart';
import '../shoulder/shoulder_ds.dart'
    show Baseline, baselineFrames, repWindow, toT;
import '../shoulder/shoulder_lib.dart';
import '../shoulder/shoulder_pipeline.dart' show RepRow;
import 'leg_ds.dart';

const e4 = 'e4';

/// Per-rep measure used by the range rule (leg angle at the top of the rep, degrees).
const peakFeatureE4 = 'g4_abd_leg_peak';

// ----------------------------------------------------------------------------- config
/// models/e4_head.json: the same keys as mt_final.json, except that analyze_video.SEG is the e4 settings
/// themselves (not keyed by exercise); it is wrapped so the shared AnalyzeConfig reads it.
ModelConfig hipModelConfig(Map<String, dynamic> j) {
  final av = Map<String, dynamic>.from(
    j['analyze_video'] as Map<String, dynamic>,
  );
  final seg = av['SEG'] as Map<String, dynamic>;
  if (seg.containsKey('prominence')) av['SEG'] = {e4: seg};
  return ModelConfig.fromJson({...j, 'analyze_video': av});
}

/// app_spec_e4.json -> feedback and range.
class HipSpec {
  final Map<String, String> messages; // e4 class messages
  final String rangeLow, unsure, partial, sideConflict;
  final double minConfidence;
  final String rangeMeasure;
  final double relativeFraction, fixedThresholdDeg;

  HipSpec.fromJson(Map<String, dynamic> spec)
    : messages = (spec['feedback']['messages'][e4] as Map<String, dynamic>)
          .cast<String, String>(),
      rangeLow = spec['feedback']['messages']['range_low'] as String,
      unsure = spec['feedback']['messages']['unsure'] as String,
      partial = spec['feedback']['messages']['partial'] as String,
      sideConflict = spec['feedback']['messages']['side_conflict'] as String,
      minConfidence = (spec['feedback']['min_confidence'] as num).toDouble(),
      rangeMeasure = spec['range']['measure'] as String,
      relativeFraction = (spec['range']['relative_fraction'] as num).toDouble(),
      fixedThresholdDeg = (spec['range']['fixed_threshold_deg'] as num)
          .toDouble();
}

// ----------------------------------------------------------------------------- analysis
class HipAnalysis {
  final String leg;
  final bool sideConflict;
  final Resampled r;
  final Map<String, Float64List> sig;
  final List<RepRow> rows;
  final Float64List? s; // smoothed count signal
  final Baseline baseline;
  final List<int> use; // indices into rows of the scored reps
  final List<List<Float32List>> x; // per scored rep: C_sel x T
  final List<Float32List> f; // per scored rep: head features
  final List<double>
  peakDeg; // per scored rep: g4_abd_leg_peak (float32 value, degrees)
  final LegFrameMatrix? frames;

  const HipAnalysis(
    this.leg,
    this.sideConflict,
    this.r,
    this.sig,
    this.rows,
    this.s,
    this.baseline,
    this.use,
    this.x,
    this.f,
    this.peakDeg,
    this.frames,
  );
}

/// lds.analyze_video(d, side, n_geo=0, rr_levels=()) followed by reference_predict_e4.head_inputs.
HipAnalysis? analyzeVideoE4(
  PoseRecording d,
  String? side,
  AnalyzeConfig cfg,
  HeadConfig head, {
  bool keepFrames = false,
}) {
  final fs = cfg.fs;
  final r = resample(d, fs: fs, maxGapS: cfg.maxGapS);
  if (r == null) return null;
  final choice = chooseLeg(r, side);
  final leg = choice.leg;
  final (sig, _) = computeLegSignals(r, leg);
  final sc = cfg.seg[e4]!;
  final (reps, s) = segmentReps(
    sig[countSignalE4]!,
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
  final fm = legFrameMatrix(r, sig, leg, base.start, base.end);
  final stored = legChannelNames();
  final logIdx = stored.length - 1;
  final peakIdx = head.features.indexOf(peakFeatureE4);
  final xs = <List<Float32List>>[], fs2 = <Float32List>[], peaks = <double>[];
  for (final i in use) {
    final rp = reps[i];
    final (w0, w1) = repWindow(rp, n, fs, cfg.marginS);
    final len = w1 - w0 + 1;
    final ch = toT(
      [for (final col in fm.m) Float64List.sublistView(col, w0, w1 + 1)],
      len,
      cfg.tLen,
    );
    final logDur = math.log(math.max((rp.iEnd - rp.iStart) / fs, 0.1));
    xs.add([
      for (final ci in head.inputSelection)
        ci == logIdx
            ? (Float32List(cfg.tLen)..fillRange(0, cfg.tLen, logDur))
            : Float32List.fromList(ch[ci]),
    ]);
    final sm = {
      for (final e in fm.s.entries)
        e.key: Float64List.sublistView(e.value, w0, w1 + 1),
    };
    final feats = legRepFeatures(
      sm,
      rp.iStart - w0,
      rp.iPeak - w0,
      rp.iEnd - w0,
      fs,
    );
    final fv = Float32List.fromList([
      for (final nm in head.features) feats[nm] ?? double.nan,
    ]);
    fs2.add(fv);
    // the float32 value, as the reference reads it from F
    peaks.add(
      peakIdx >= 0 ? fv[peakIdx] : f32(feats[peakFeatureE4] ?? double.nan),
    );
  }
  return HipAnalysis(
    leg,
    choice.sideConflict,
    r,
    sig,
    rows,
    s,
    base,
    use,
    xs,
    fs2,
    peaks,
    keepFrames ? fm : null,
  );
}

// ----------------------------------------------------------------------------- range rule and verdict
enum RangeSource { therapist, usualLift, fixed, session }

class RangeTarget {
  final double deg;
  final RangeSource source;
  const RangeTarget(this.deg, this.source);
}

/// reference_predict_e4.range_target: the physiotherapist's target, else relative_fraction x the patient's usual
/// lift, else the fixed default angle.
RangeTarget rangeTarget(
  HipSpec spec, {
  double? therapistDeg,
  double? usualLiftDeg,
}) {
  if (therapistDeg != null && therapistDeg.isFinite) {
    return RangeTarget(therapistDeg, RangeSource.therapist);
  }
  if (usualLiftDeg != null && usualLiftDeg.isFinite) {
    return RangeTarget(
      spec.relativeFraction * usualLiftDeg,
      RangeSource.usualLift,
    );
  }
  return RangeTarget(spec.fixedThresholdDeg, RangeSource.fixed);
}

/// The patient's usual lift: the median peak angle of their good-form reps (null when there is none).
double? usualLift(Iterable<double> goodPeaks) {
  final v = [
    for (final p in goodPeaks)
      if (p.isFinite) p,
  ];
  return v.isEmpty ? null : nanmedian(v);
}

/// Python str.format for the spec messages: {name} and {name:.Nf} (.0f rounds half to even, as Python).
String pyFormat(String template, Map<String, Object> values) =>
    template.replaceAllMapped(RegExp(r'\{(\w+)(?::\.(\d+)f)?\}'), (m) {
      final v = values[m[1]!];
      if (v == null) return m[0]!;
      if (m[2] == null) return v.toString();
      final d = (v as num).toDouble();
      final p = int.parse(m[2]!);
      return p == 0 ? '${pyRound(d)}' : d.toStringAsFixed(p);
    });

class HipVerdict {
  final String label, status, message;
  final double confidence;
  final List<double> probs;
  const HipVerdict(
    this.label,
    this.status,
    this.message,
    this.confidence,
    this.probs,
  );
}

/// Forgiving tolerance margin (degrees) for e4 hip abduction:
/// A patient who reaches within this margin of the nominal target angle is credited
/// with a good rep to encourage progress and avoid patient frustration.
const double e4ForgivingToleranceDeg = 2.0;

/// reference_predict_e4.verdict: unsure (low confidence) -> mistake (form class) -> range check on good form
/// (below the target -> below_target) -> good. [target] null: the range is not judged (session calibration).
HipVerdict verdictE4(
  HipSpec spec,
  HeadConfig head,
  List<double> probs,
  String side,
  double peakDeg,
  RangeTarget? target,
) {
  var k = 0;
  for (var i = 1; i < probs.length; i++) {
    if (probs[i] > probs[k]) k = i;
  }
  final label = head.classes[k], conf = probs[k];
  if (conf < spec.minConfidence) {
    return HipVerdict(label, 'unsure', spec.unsure, conf, probs);
  }
  if (label != 'good') {
    return HipVerdict(
      label,
      'mistake',
      pyFormat(spec.messages[label]!, {'leg': side}),
      conf,
      probs,
    );
  }
  // Forgiving evaluation: apply e4ForgivingToleranceDeg buffer so that near-target
  // reps (e.g. 23.5° when target is 25°) are counted as good instead of frustrating the patient.
  if (target != null && peakDeg.isFinite && peakDeg < (target.deg - e4ForgivingToleranceDeg)) {
    return HipVerdict(
      label,
      'below_target',
      pyFormat(spec.rangeLow, {'target': target.deg, 'reached': peakDeg}),
      conf,
      probs,
    );
  }
  return HipVerdict(label, 'good', spec.messages['good']!, conf, probs);
}

// ----------------------------------------------------------------------------- session baseline of the range
/// Good-form reps at the start of a set that calibrate the patient's own range for that set.
const sessionCalibrationReps = 3;

/// The range rule adapted to the set: a patient whose range is small from the very first reps (their pain-free range
/// today) is not asked to lift higher at every rep; only a noticeable drop from their own start is flagged.
///
/// The first [calibrationReps] good-form reps (label good, judged with confidence) are not judged against any target:
/// their median peak angle is the session baseline. After that the target is the lower of the prescription target
/// (physiotherapist / usual lift / default angle, see [rangeTarget]) and relative_fraction x the session baseline,
/// so a rep is below target only when it also falls clearly under what the patient did at the start of the set.
class SessionRange {
  final double relativeFraction;
  final int calibrationReps;
  final List<double> _calibration = [];

  SessionRange(this.relativeFraction, {this.calibrationReps = sessionCalibrationReps});

  bool get calibrating => _calibration.length < calibrationReps;

  /// Median peak angle of the calibration reps (null while calibrating).
  double? get baselineDeg => calibrating ? null : nanmedian(_calibration);

  /// The target for the next rep: null while calibrating (the range is not judged).
  RangeTarget? target(RangeTarget prescription) {
    final b = baselineDeg;
    if (b == null) return null;
    final own = relativeFraction * b;
    return own < prescription.deg ? RangeTarget(own, RangeSource.session) : prescription;
  }

  /// Feeds a judged rep (in order): calibration takes the good-form reps with a finite peak angle.
  void add(HipVerdict v, double peakDeg) {
    if (calibrating && v.label == 'good' && v.status == 'good' && peakDeg.isFinite) {
      _calibration.add(peakDeg);
    }
  }

  void reset() => _calibration.clear();
}
