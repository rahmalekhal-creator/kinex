// On-device measurement of the live pipeline (no UI, nobody needs to stand in front of the phone).
//
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/live_perf_test.dart -d <device>
//
// Writes build/live_perf.json. Camera permission: grant it once (adb shell pm grant com.example.reeducation
// android.permission.CAMERA) or accept the prompt.
//
// 1. Camera + MediaPipe, ~12 s per configuration: old behaviour (every frame converted and submitted) vs the
//    latest-frame gate, CPU vs GPU, with / without the person mask. Per frame: camera->result age, MediaPipe time,
//    image conversion, mask packing, frames per second, frames dropped while busy.
// 2. The scoring pass (whole shoulder pipeline on the current segment, in the scoring isolate) for sets of 10-90 s of
//    synthetic arm-abduction movement (the cost depends on the length, not on who moves).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kinex_pose/kinex_pose.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reeducation/features/exercise_ai/core/pose_recording.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_module.dart';

Map<String, double> stats(List<double> v) {
  final x = v.where((e) => e.isFinite).toList()..sort();
  if (x.isEmpty) return {'n': 0};
  double q(double p) => x[math.min(x.length - 1, (p * (x.length - 1)).round())];
  return {'n': x.length.toDouble(), 'mean': x.reduce((a, b) => a + b) / x.length, 'p50': q(.5), 'p90': q(.9), 'max': x.last};
}

/// A standing person whose LEFT arm goes up to the side and back (abduction), one rep every 4 s.
PoseRecording syntheticSet(double seconds) {
  const fps = 30.0;
  final n = (seconds * fps).round();
  final t = Float64List(n), lm = Float32List(n * 165), world = Float32List(n * 99);
  for (var i = 0; i < n; i++) {
    final ts = i / fps;
    t[i] = 1000 * ts;
    final phase = (ts % 4.0) / 4.0; // 0..1: 1 s rest, 2 s up and down, 1 s rest
    final up = phase < 0.25 || phase > 0.75 ? 0.0 : math.sin((phase - 0.25) / 0.5 * math.pi);
    final ang = (10 + 90 * up) * math.pi / 180;
    final p = <int, List<double>>{
      0: [0.50, 0.25], 7: [0.53, 0.24], 8: [0.47, 0.24],
      11: [0.56, 0.35], 12: [0.44, 0.35], 23: [0.54, 0.60], 24: [0.46, 0.60],
      25: [0.54, 0.75], 26: [0.46, 0.75], 27: [0.54, 0.90], 28: [0.46, 0.90],
      14: [0.43, 0.47], 16: [0.43, 0.58],
    };
    // left arm (person's left = image right): shoulder -> elbow -> wrist at angle `ang` from the body
    p[13] = [0.56 + 0.12 * math.sin(ang), 0.35 + 0.12 * math.cos(ang)];
    p[15] = [0.56 + 0.23 * math.sin(ang), 0.35 + 0.23 * math.cos(ang)];
    for (var j = 0; j < 33; j++) {
      final xy = p[j] ?? [0.5, 0.3];
      final jitter = 0.0005 * math.sin(i * 1.7 + j); // a little noise, like real landmarks
      lm.setAll((i * 33 + j) * 5, [xy[0] + jitter, xy[1] - jitter, 0, 0.99, 0.99]);
      world.setAll((i * 33 + j) * 3, [(xy[0] - 0.5) * 1.6, (xy[1] - 0.6) * 1.6, 0.0]);
    }
  }
  return PoseRecording(tMs: t, lm: lm, world: world, width: 720, height: 1280);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final report = <String, dynamic>{};

  testWidgets('camera + MediaPipe, per configuration', (t) async {
    await t.runAsync(() async {
      await Permission.camera.request();
      final configs = [
        ('before: every frame submitted, CPU', false, false, false),
        ('after: latest frame only, CPU', true, false, false),
        ('after: latest frame only, CPU, with mask (e2)', true, false, true),
        ('after: latest frame only, GPU', true, true, false),
      ];
      for (final (name, gate, gpu, mask) in configs) {
        final age = <double>[], infer = <double>[], prep = <double>[], packMs = <double>[];
        var frames = 0, dropped = 0;
        String delegate = '?';
        final sub = KinexPose.frames().listen((f) {
          frames++;
          age.add(f.ageMs);
          infer.add(f.inferMs);
          prep.add(f.prepMs);
          packMs.add(f.maskMs);
          dropped += f.dropped;
          delegate = f.delegate;
        });
        await KinexPose.start(front: true, mask: mask, gpu: gpu, skipWhileBusy: gate);
        await Future<void>.delayed(const Duration(seconds: 3)); // warm-up
        frames = 0;
        dropped = 0;
        age.clear();
        infer.clear();
        prep.clear();
        packMs.clear();
        final sw = Stopwatch()..start();
        await Future<void>.delayed(const Duration(seconds: 12));
        final secs = sw.elapsedMilliseconds / 1000.0;
        await KinexPose.stop();
        await sub.cancel();
        report[name] = {
          'delegate': delegate,
          'fps': frames / secs,
          'dropped_per_s': dropped / secs,
          'camera_to_result_ms': stats(age),
          'mediapipe_ms': stats(infer),
          'conversion_ms': stats(prep),
          'mask_pack_ms': stats(packMs),
        };
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('scoring pass vs set length', (t) async {
    await t.runAsync(() async {
      final m = ShoulderModule();
      await m.load('e2', 'multitask');
      final out = <String, dynamic>{};
      for (final secs in [10.0, 30.0, 60.0, 90.0]) {
        final rec = syntheticSet(secs);
        final times = <double>[];
        var reps = 0;
        for (var k = 0; k < 4; k++) {
          final sw = Stopwatch()..start();
          final up = await m.score(rec, 'e2', 'left', const []);
          times.add(sw.elapsedMicroseconds / 1000.0);
          reps = up.repsFound;
        }
        out['${secs.round()} s'] = {'round_trip_ms': stats(times), 'reps_found': reps};
      }
      m.dispose();
      report['scoring pass (e2, synthetic set)'] = out;
    });
    binding.reportData = report;
  }, timeout: const Timeout(Duration(minutes: 5)));
}
