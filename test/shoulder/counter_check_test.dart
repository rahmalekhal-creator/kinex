// Diagnostic: how well does the on-screen (causal) counter agree with the offline rep segmentation?
// Prints one line per golden recording; writes build/shoulder_counter_check.json.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinex_pose/kinex_pose.dart';
import 'package:reeducation/features/exercise_ai/core/pose_recording.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_module.dart';

void main() {
  final files = Directory('shoulder_app_bundle/golden').listSync().whereType<File>().map((f) => f.path)
      .where((p) => RegExp(r'e\d__').hasMatch(p)).toList()
    ..sort();
  final report = <String, dynamic>{};
  for (final path in files) {
    final name = path.split(RegExp(r'[\\/]')).last.replaceAll('.json', '');
    test(name, () {
      final g = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final ex = g['exercise'] as String, side = g['side'] as String;
      final rec = PoseRecording.fromJson(g['input'] as Map<String, dynamic>);
      final tr = ShoulderTracker(ex, side);
      for (var i = 0; i < rec.length; i++) {
        final lm = Float32List.sublistView(rec.lm, i * 165, (i + 1) * 165);
        tr.add(PoseFrame(rec.tMs[i], rec.width.toInt(), rec.height.toInt(), lm.first.isNaN ? null : lm, null, null, 0, 0,
            0, 0, 0));
      }
      final reps = (g['expected']['reps'] as List).cast<Map<String, dynamic>>();
      final full = reps.where((r) => r['partial'] != true).length;
      report[name] = {'counter': tr.count, 'offline_complete_reps': full, 'offline_all_reps': reps.length};
      stdout.writeln('$name: on-screen counter ${tr.count} vs offline complete reps $full (all incl. cut ones ${reps.length})');
      File('build/shoulder_counter_check.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));
    });
  }
}
