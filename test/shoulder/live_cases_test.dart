// The golden recordings cut the way the live app sees them (buffer ending 0.5 s after a rep; recording
// starting in the rest before a rep), against reference_predict on the same cut
// (tool/shoulder_ref/make_fixtures.py → fixtures/extra_cases.json). Needs ORT_LIB for the probabilities.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/pose_recording.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_config.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_model.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_pipeline.dart';

const bundle = 'shoulder_app_bundle';

Map<String, dynamic> cutInput(Map<String, dynamic> inp, double? from, double? to) {
  final t = (inp['t_ms'] as List).map((v) => (v as num).toDouble()).toList();
  final idx = [for (var i = 0; i < t.length; i++) if ((from == null || t[i] >= from) && (to == null || t[i] <= to)) i];
  return {
    ...inp,
    for (final k in const ['t_ms', 'lm', 'world', 'sil'])
      if (inp[k] != null) k: [for (final i in idx) (inp[k] as List)[i]],
  };
}

bool close(double a, Object? b) {
  final r = b == null ? double.nan : (b as num).toDouble();
  if (r.isNaN || a.isNaN) return r.isNaN && a.isNaN;
  final d = (a - r).abs();
  return d < 1e-3 || d < 1e-3 * r.abs();
}

void main() {
  final ortLib = Platform.environment['ORT_LIB'];
  final spec = jsonDecode(File('$bundle/app_spec.json').readAsStringSync()) as Map<String, dynamic>;
  final fb = FeedbackSpec.fromJson(spec);
  final cfg = ModelConfig.fromJson(jsonDecode(File('$bundle/models/mt_final.json').readAsStringSync()));
  final cases = (jsonDecode(File('test/shoulder/fixtures/extra_cases.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final inputs = <String, Map<String, dynamic>>{};
  final models = <String, ShoulderHeadModel>{};

  for (final c in cases) {
    test('${c['source']} ${c['name']}', () {
      final src = c['source'] as String;
      final inp = inputs[src] ??= (jsonDecode(File('$bundle/golden/$src').readAsStringSync())
          as Map<String, dynamic>)['input'] as Map<String, dynamic>;
      final ex = c['exercise'] as String, side = c['side'] as String;
      final head = cfg.heads[ex]!;
      final rec = PoseRecording.fromJson(cutInput(inp, (c['t_from_ms'] as num?)?.toDouble(), (c['t_to_ms'] as num?)?.toDouble()));
      final a = analyzeVideo(rec, ex, side, cfg.analyze, head)!;
      final e = c['expected'] as Map<String, dynamic>;
      expect(a.arm, e['arm']);
      final b = e['baseline'] as Map<String, dynamic>;
      expect([a.baseline.start, a.baseline.end, a.baseline.source], [b['start'], b['end'], b['source']]);
      final er = (e['reps'] as List).cast<Map<String, dynamic>>();
      expect(a.rows.length, er.length, reason: 'rep count');
      for (var k = 0; k < er.length; k++) {
        final s = a.rows[k].seg;
        for (final (app, key) in [(s.iStart, 'i_start'), (s.iPeak, 'i_peak'), (s.iEnd, 'i_end')]) {
          expect((app - (er[k][key] as int)).abs(), lessThanOrEqualTo(1), reason: 'rep ${k + 1} $key');
        }
        expect(s.partial, er[k]['partial'], reason: 'rep ${k + 1} partial');
        expect(a.rows[k].usable, er[k]['usable'], reason: 'rep ${k + 1} usable');
      }
      final samples = (e['samples'] as List).cast<Map<String, dynamic>>();
      expect([for (final i in a.use) a.rows[i].rep], [for (final s in samples) s['rep']]);
      for (var j = 0; j < samples.length; j++) {
        final ef = samples[j]['f'] as List;
        for (var k = 0; k < ef.length; k++) {
          expect(close(a.f[j][k], ef[k]), isTrue, reason: 'rep ${samples[j]['rep']} f ${head.features[k]}: ${a.f[j][k]} vs ${ef[k]}');
        }
        final ex2 = samples[j]['x'] as List?;
        if (ex2 != null) {
          for (var ch = 0; ch < ex2.length; ch++) {
            for (var t = 0; t < (ex2[ch] as List).length; t++) {
              expect(close(a.x[j][ch][t], (ex2[ch] as List)[t]), isTrue, reason: 'x ${head.inputChannels[ch]}[$t]');
            }
          }
        }
      }
      if (ortLib == null) fail('ORT_LIB not set: probabilities not checked');
      final model = models[ex] ??=
          ShoulderHeadModel(head, File('$bundle/models/${head.onnxFile}').readAsBytesSync(), libraryPath: ortLib);
      final probs = model.predict(a.x, a.f);
      for (var j = 0; j < samples.length; j++) {
        final ep = samples[j]['probs'] as List;
        var d = 0.0;
        for (var k = 0; k < ep.length; k++) {
          d = math.max(d, (probs[j][k] - (ep[k] as num)).abs());
        }
        expect(d, lessThan(1e-3), reason: 'rep ${samples[j]['rep']} probs');
        final v = verdict(fb, head, probs[j], side);
        expect(v.label, samples[j]['label']);
        expect(v.message, samples[j]['message']);
      }
    });
  }
}
