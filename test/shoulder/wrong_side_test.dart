// The wrong-arm rule of the live assistant (e2 / e3): a rep done with the arm other than the prescribed one is not
// counted. On the golden recordings: the prescribed arm -> no rep flagged; the other arm prescribed -> every complete
// rep flagged.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/pose_recording.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_config.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_ds.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_pipeline.dart';
import 'package:reeducation/features/exercise_ai/shoulder/side_check.dart';

const bundle = 'shoulder_app_bundle';

void main() {
  final cfg = ModelConfig.fromJson(jsonDecode(File('$bundle/models/mt_final.json').readAsStringSync()));
  final files = Directory('$bundle/golden').listSync().whereType<File>().map((f) => f.path)
      .where((p) => RegExp(r'e[23]__').hasMatch(p)).toList()
    ..sort();

  test('e2 / e3 golden files found', () => expect(files, isNotEmpty));

  for (final path in files) {
    final name = path.split(RegExp(r'[\\/]')).last.replaceAll('.json', '');
    final g = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final ex = g['exercise'] as String, side = g['side'] as String;
    final other = side == 'left' ? 'right' : 'left';
    final rec = PoseRecording.fromJson(g['input'] as Map<String, dynamic>);

    List<bool> flags(String prescribed) {
      final a = analyzeVideo(rec, ex, prescribed, cfg.analyze, cfg.heads[ex]!)!;
      return [
        for (final row in a.rows)
          if (!row.seg.partial)
            () {
              final (w0, w1) = repWindow(row.seg, a.r.n, cfg.analyze.fs, cfg.analyze.marginS);
              return wrongArmInWindow(a.r, w0, w1, prescribed);
            }(),
      ];
    }

    test('$name: the prescribed arm -> no rep flagged', () {
      expect(flags(side).where((f) => f), isEmpty);
    });

    test('$name: the other arm prescribed -> every complete rep flagged', () {
      final f = flags(other);
      expect(f, isNotEmpty);
      expect(f.every((x) => x), isTrue, reason: '$f');
    });
  }
}
