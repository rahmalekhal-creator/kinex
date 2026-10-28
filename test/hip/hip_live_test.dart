// e4 live behaviour on the golden recordings: the on-screen counter, the wrong-leg rule, the range-target order
// and the spec message formatting.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinex_pose/kinex_pose.dart';
import 'package:reeducation/features/exercise_ai/core/pose_recording.dart';
import 'package:reeducation/features/exercise_ai/hip/hip_module.dart';
import 'package:reeducation/features/exercise_ai/hip/hip_pipeline.dart';

const bundle = 'e4_app_bundle';

void main() {
  final spec = HipSpec.fromJson(jsonDecode(File('$bundle/app_spec_e4.json').readAsStringSync()) as Map<String, dynamic>);
  final cfg = hipModelConfig(jsonDecode(File('$bundle/models/e4_head.json').readAsStringSync()) as Map<String, dynamic>);
  final head = cfg.heads[e4]!;
  final files = Directory('$bundle/golden').listSync().whereType<File>().map((f) => f.path).where((p) => p.contains('e4__')).toList()
    ..sort();

  group('range target', () {
    test('the physiotherapist target comes first', () {
      final t = rangeTarget(spec, therapistDeg: 35, usualLiftDeg: 60);
      expect(t.deg, 35);
      expect(t.source, RangeSource.therapist);
    });
    test('else relative_fraction x the usual lift', () {
      final t = rangeTarget(spec, usualLiftDeg: 60);
      expect(t.deg, closeTo(spec.relativeFraction * 60, 1e-12));
      expect(t.source, RangeSource.usualLift);
    });
    test('else the fixed default angle', () {
      final t = rangeTarget(spec);
      expect(t.deg, spec.fixedThresholdDeg);
      expect(t.source, RangeSource.fixed);
    });
    test('numbers come from app_spec_e4.json', () {
      expect(spec.relativeFraction, 0.755);
      expect(spec.fixedThresholdDeg, 27.4);
      expect(spec.rangeMeasure, peakFeatureE4);
    });
    test('usual lift = median of the good reps', () {
      expect(usualLift([40, 50, double.nan, 46]), 46);
      expect(usualLift(const []), isNull);
    });
  });

  group('verdict', () {
    test('range judged only on good form', () {
      final t = rangeTarget(spec, therapistDeg: 30);
      // good, below the target
      expect(verdictE4(spec, head, [0.9, 0.05, 0.03, 0.02], 'left', 20, t).status, 'below_target');
      // good, at the target
      expect(verdictE4(spec, head, [0.9, 0.05, 0.03, 0.02], 'left', 30, t).status, 'good');
      // a form mistake with a small lift stays a mistake (the range is not judged)
      final m = verdictE4(spec, head, [0.1, 0.8, 0.05, 0.05], 'right', 10, t);
      expect(m.status, 'mistake');
      expect(m.message, 'Keep your right knee straight while you lift the leg');
      // low confidence
      expect(verdictE4(spec, head, [0.4, 0.3, 0.2, 0.1], 'left', 10, t).status, 'unsure');
    });
    test('range_low message as Python formats it', () {
      final v = verdictE4(spec, head, [0.9, 0.05, 0.03, 0.02], 'left', 12.5, rangeTarget(spec));
      expect(v.message, 'Good form - lift your leg a bit higher: target 27 deg, you reached 12 deg');
    });
  });

  for (final path in files) {
    final name = path.split(RegExp(r'[\\/]')).last.replaceAll('.json', '');
    final g = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final side = g['side'] as String;
    final other = side == 'left' ? 'right' : 'left';
    final rec = PoseRecording.fromJson(g['input'] as Map<String, dynamic>);
    final reps = (g['expected']['reps'] as List).cast<Map<String, dynamic>>();
    final complete = reps.where((r) => r['partial'] != true).length;

    test('$name: on-screen counter close to the offline reps', () {
      final tr = HipTracker(side);
      for (var i = 0; i < rec.length; i++) {
        final lm = Float32List.sublistView(rec.lm, i * 165, (i + 1) * 165);
        tr.add(PoseFrame(rec.tMs[i], rec.width.toInt(), rec.height.toInt(), lm.first.isNaN ? null : lm, null, null, 0,
            0, 0, 0, 0));
      }
      // the counter also counts the reps cut by the start / end of the recording
      expect(tr.count, inInclusiveRange(complete - 1, reps.length + 1),
          reason: 'counter ${tr.count} vs $complete complete / ${reps.length} reps');
    });

    test('$name: right leg -> no rep flagged as the wrong leg', () {
      final r = analyzeForLiveE4(rec, side, cfg.analyze, head, const [], true)!;
      expect(r.repSummary.where((x) => x.$2), isEmpty);
      expect(r.x.length, (g['expected']['samples'] as List).length);
    });

    test('$name: the other leg chosen -> every complete rep flagged, none scored', () {
      final r = analyzeForLiveE4(rec, other, cfg.analyze, head, const [], true)!;
      expect(r.sideConflict, isTrue);
      final flagged = r.repSummary.where((x) => x.$2).length;
      expect(flagged, complete);
      expect(r.x, isEmpty);
    });
  }
}
