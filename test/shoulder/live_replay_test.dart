// Replays each golden recording the way the live screen scores it (a pass every 15 new frames on the
// buffer so far, then a final pass) through ShoulderModule, and compares the live verdicts with the offline
// run on the whole recording. Needs ORT_LIB. Writes build/shoulder_live_replay.json.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/exercise_module.dart';
import 'package:reeducation/features/exercise_ai/core/pose_recording.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_module.dart';

PoseRecording prefix(PoseRecording r, int n) => PoseRecording(
      tMs: Float64List.sublistView(r.tMs, 0, n),
      lm: Float32List.sublistView(r.lm, 0, n * 165),
      world: Float32List.sublistView(r.world, 0, n * 99),
      sil: r.sil == null ? null : Float32List.sublistView(r.sil!, 0, n * 2 * r.silK),
      silNames: r.silNames,
      width: r.width,
      height: r.height,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final report = <String, dynamic>{};
  final files = Directory('shoulder_app_bundle/golden').listSync().whereType<File>().map((f) => f.path)
      .where((p) => RegExp(r'e\d__').hasMatch(p)).toList()
    ..sort();

  for (final path in files) {
    final name = path.split(RegExp(r'[\\/]')).last.replaceAll('.json', '');
    test(name, () async {
      final g = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final ex = g['exercise'] as String, side = g['side'] as String;
      final rec = PoseRecording.fromJson(g['input'] as Map<String, dynamic>);
      final module = ShoulderModule();
      await module.load(ex, 'multitask');
      final live = <RepVerdict>[];
      for (var n = 15; n <= rec.length; n += 15) {
        final up = await module.score(prefix(rec, n), ex, side, [for (final v in live) v.tPeakS]);
        live.addAll(up.newVerdicts);
      }
      final last = await module.score(rec, ex, side, [for (final v in live) v.tPeakS], finalPass: true);
      live.addAll(last.newVerdicts);
      module.dispose();

      final offline = (g['expected']['samples'] as List).cast<Map<String, dynamic>>();
      final offReps = (g['expected']['reps'] as List).cast<Map<String, dynamic>>();
      final t0 = (g['expected']['t0_s'] as num).toDouble();
      var same = 0, matched = 0;
      var maxDp = 0.0;
      final rows = <Map<String, dynamic>>[];
      for (final s in offline) {
        final r = offReps.firstWhere((r) => r['rep'] == s['rep']);
        final tPeak = (r['t_peak'] as num).toDouble() - t0;
        final v = live.where((v) => v.scored && (v.tPeakS - tPeak).abs() < 0.4).toList();
        if (v.isEmpty) {
          rows.add({'rep': s['rep'], 'offline': s['label'], 'live': null});
          continue;
        }
        matched++;
        if (v.first.label == s['label']) same++;
        final p = (s['probs'] as List).cast<num>();
        for (var k = 0; k < p.length; k++) {
          maxDp = math.max(maxDp, (v.first.probs[k] - p[k]).abs());
        }
        rows.add({'rep': s['rep'], 'offline': s['label'], 'live': v.first.label, 'buffer_frames': v.first.bufferFrames});
      }
      final dupes = live.length - {for (final v in live) (v.tPeakS * 10).round()}.length;
      report[name] = {
        'offline_scored': offline.length,
        'live_scored': live.where((v) => v.scored).length,
        'live_verdicts': live.length,
        'matched': matched,
        'same_label': same,
        'max_prob_diff_live_vs_offline': maxDp,
        'duplicates': dupes,
        'reps': rows,
      };
      File('build/shoulder_live_replay.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));
      expect(dupes, 0, reason: 'a rep was scored twice');
      expect(matched, offline.length, reason: 'every offline-scored rep gets a live verdict');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
