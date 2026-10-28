// The range rule adapted to the set (SessionRange): a patient whose range is small from the first reps is not asked
// to lift higher at every rep; a clear drop from their own start is still flagged.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/hip/hip_pipeline.dart';

void main() {
  final spec = HipSpec.fromJson(jsonDecode(File('e4_app_bundle/app_spec_e4.json').readAsStringSync()) as Map<String, dynamic>);
  final head = hipModelConfig(
    jsonDecode(File('e4_app_bundle/models/e4_head.json').readAsStringSync()) as Map<String, dynamic>,
  ).heads[e4]!;
  const goodProbs = [0.9, 0.05, 0.03, 0.02], kneeProbs = [0.1, 0.8, 0.05, 0.05], unsureProbs = [0.4, 0.3, 0.2, 0.1];

  /// Judges [peaks] in order as one set, as HipModule.score does; returns the statuses.
  List<String> runSet(List<double> peaks, {RangeTarget? prescription, List<List<double>>? probs}) {
    final session = SessionRange(spec.relativeFraction);
    final prior = prescription ?? rangeTarget(spec);
    final out = <String>[];
    for (var i = 0; i < peaks.length; i++) {
      final v = verdictE4(spec, head, probs?[i] ?? goodProbs, 'left', peaks[i], session.target(prior));
      session.add(v, peaks[i]);
      out.add(v.status);
    }
    return out;
  }

  test('a small range from the start is the baseline: no "lift higher" (golden shallow patient p09)', () {
    // peaks of the golden shallow recording (all good form, 8-16 deg; the default target is 27.4 deg)
    final g = jsonDecode(File('e4_app_bundle/golden/e4__e4_shallow_p09_left.json').readAsStringSync()) as Map<String, dynamic>;
    final peaks = [for (final s in (g['expected']['samples'] as List)) (s['peak_deg'] as num).toDouble()];
    // without the session baseline every rep was below target ...
    expect(peaks.every((p) => p < spec.fixedThresholdDeg), isTrue);
    // ... with it, only a rep clearly under the patient's own start is flagged
    final st = runSet(peaks);
    final baseline = ([...peaks.take(3)]..sort())[1];
    final expected = [
      for (var i = 0; i < peaks.length; i++) i < 3 || peaks[i] >= spec.relativeFraction * baseline ? 'good' : 'below_target',
    ];
    expect(st, expected);
    expect(st.where((s) => s == 'below_target').length, lessThanOrEqualTo(1));
  });

  test('the calibration reps are never flagged, then a clear drop is', () {
    expect(runSet([12, 11, 13, 12, 10, 8]), ['good', 'good', 'good', 'good', 'good', 'below_target']);
  });

  test('a patient lifting well who fades is flagged against their own start', () {
    // baseline 60 deg: 0.755 x 60 = 45.3 < default 27.4? no: the lower of the two applies (27.4)
    expect(runSet([60, 58, 62, 50, 30, 25]), ['good', 'good', 'good', 'good', 'good', 'below_target']);
  });

  test('the physiotherapist target applies when it is lower than the session rule', () {
    final t = rangeTarget(spec, therapistDeg: 35);
    // baseline 60 -> own 45.3; the physio target 35 is lower: 40 deg is fine, 30 is below
    expect(runSet([60, 60, 60, 40, 30], prescription: t), ['good', 'good', 'good', 'good', 'below_target']);
    // baseline 20 -> own 15.1 < 35: a patient at 18 deg is not asked for 35 at every rep
    expect(runSet([20, 19, 21, 18, 14], prescription: t), ['good', 'good', 'good', 'good', 'below_target']);
  });

  test('only good-form, confident reps calibrate', () {
    final st = runSet(
      [40, 30, 12, 11, 13, 12],
      probs: [kneeProbs, unsureProbs, goodProbs, goodProbs, goodProbs, goodProbs],
    );
    expect(st, ['mistake', 'unsure', 'good', 'good', 'good', 'good']);
  });

  test('a new set calibrates again', () {
    final s = SessionRange(spec.relativeFraction);
    for (final p in <double>[50, 50, 50]) {
      s.add(verdictE4(spec, head, goodProbs, 'left', p, null), p);
    }
    expect(s.baselineDeg, 50);
    s.reset();
    expect(s.calibrating, isTrue);
    expect(s.target(rangeTarget(spec)), isNull);
  });
}
