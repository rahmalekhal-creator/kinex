// Golden tests of the shoulder pipeline port: every shoulder_app_bundle/golden/<ex>__*.json, stage by stage.
// The ONNX stage needs the ONNX Runtime shared library: set ORT_LIB to its path
// (e.g. onnxruntime-win-x64-1.31.0/lib/onnxruntime.dll). A table of the differences is written to
// build/shoulder_parity.json.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/pose_recording.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_config.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_ds.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_model.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_pipeline.dart';

const bundle = 'shoulder_app_bundle';
const tol = 1e-3;

double? _d(Object? v) => v == null ? null : (v as num).toDouble();

/// |Δ| for the table, and whether it is within tolerance (absolute 1e-3, or relative 1e-3 for large values).
class Diff {
  double maxAbs = 0;
  int bad = 0;
  String? firstBad;

  void add(double app, double? ref, String where, {double t = tol, bool relative = true}) {
    final rn = ref == null || ref.isNaN;
    if (rn || app.isNaN) {
      if (rn != app.isNaN) {
        bad++;
        firstBad ??= '$where: app $app ref $ref';
        maxAbs = double.infinity;
      }
      return;
    }
    final d = (app - ref).abs();
    maxAbs = math.max(maxAbs, d);
    if (!(d < t || (relative && d < t * ref.abs()))) {
      bad++;
      firstBad ??= '$where: app $app ref $ref';
    }
  }
}

void main() {
  final ortLib = Platform.environment['ORT_LIB'];
  final spec = jsonDecode(File('$bundle/app_spec.json').readAsStringSync()) as Map<String, dynamic>;
  final fb = FeedbackSpec.fromJson(spec);
  final cfg = ModelConfig.fromJson(jsonDecode(File('$bundle/models/mt_final.json').readAsStringSync()));
  final sepJson = jsonDecode(File('$bundle/models/separate.json').readAsStringSync()) as Map<String, dynamic>;
  final sep = ModelConfig.fromJson(sepJson, fallbackAnalyze: cfg.analyze);
  final files = Directory('$bundle/golden').listSync().whereType<File>().map((f) => f.path).where((p) => RegExp(r'e\d__').hasMatch(p)).toList()
    ..sort();
  final report = <String, dynamic>{};

  test('stored channel order = channel_names(ex)', () {
    for (final ex in const ['e1', 'e2', 'e3']) {
      expect(channelNames(ex), cfg.heads[ex]!.storedChannels, reason: ex);
    }
  });

  for (final path in files) {
    final name = path.split(RegExp(r'[\\/]')).last.replaceAll('.json', '');
    test(name, () {
      final g = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final ex = g['exercise'] as String, side = g['side'] as String;
      final exp = g['expected'] as Map<String, dynamic>;
      final head = cfg.heads[ex]!;
      final rec = PoseRecording.fromJson(g['input'] as Map<String, dynamic>);
      final sw = Stopwatch()..start();
      final a = analyzeVideo(rec, ex, side, cfg.analyze, head, keepFrames: true)!;
      final pipelineMs = sw.elapsedMilliseconds;
      final row = <String, dynamic>{'frames_30hz': a.r.n, 'pipeline_ms': pipelineMs};
      final problems = <String>[];

      // arm, baseline
      row['arm'] = a.arm == exp['arm'] ? 'ok' : 'app ${a.arm} ref ${exp['arm']}';
      if (a.arm != exp['arm']) problems.add('arm');
      final eb = exp['baseline'] as Map<String, dynamic>;
      final bOk = a.baseline.start == eb['start'] && a.baseline.end == eb['end'] && a.baseline.source == eb['source'];
      row['baseline'] = bOk ? 'ok' : 'app ${a.baseline.start}-${a.baseline.end} ${a.baseline.source} ref $eb';
      if (!bOk) problems.add('baseline');

      // reps (±1 frame), partial / usable identical
      final er = (exp['reps'] as List).cast<Map<String, dynamic>>();
      var maxDi = 0;
      var repsOk = a.rows.length == er.length;
      for (var k = 0; k < math.min(a.rows.length, er.length); k++) {
        final s = a.rows[k].seg;
        for (final (app, key) in [(s.iStart, 'i_start'), (s.iPeak, 'i_peak'), (s.iEnd, 'i_end')]) {
          maxDi = math.max(maxDi, (app - (er[k][key] as int)).abs());
        }
        if (s.partial != er[k]['partial'] || a.rows[k].usable != er[k]['usable']) repsOk = false;
      }
      repsOk = repsOk && maxDi <= 1;
      row['reps'] = '${a.rows.length}/${er.length} reps, max |Δ| $maxDi frame(s)${repsOk ? '' : ' MISMATCH'}';
      if (!repsOk) problems.add('reps');

      // count signal
      final cs = Diff();
      final ecs = exp['count_signal_smoothed'] as List;
      if (ecs.length != a.s!.length) problems.add('count_signal length ${a.s!.length} vs ${ecs.length}');
      for (var i = 0; i < math.min(ecs.length, a.s!.length); i++) {
        cs.add(a.s![i], _d(ecs[i]), 'count[$i]');
      }
      row['count_signal_smoothed'] = cs.maxAbs;
      if (cs.bad > 0) problems.add('count_signal: ${cs.firstBad}');

      // per-frame channels
      final fc = exp['frame_channels'] as Map<String, dynamic>;
      final fnames = (fc['names'] as List).cast<String>();
      final fvals = fc['values'] as List;
      final fd = Diff();
      for (var c = 0; c < fnames.length; c++) {
        final col = a.frames!.m[fnames[c]];
        if (col == null) {
          problems.add('missing channel ${fnames[c]}');
          continue;
        }
        for (var i = 0; i < math.min(fvals.length, col.length); i++) {
          fd.add(col[i], _d((fvals[i] as List)[c]), '${fnames[c]}[$i]');
        }
      }
      row['frame_channels'] = fd.maxAbs;
      if (fd.bad > 0) problems.add('frame_channels: ${fd.bad} bad, first ${fd.firstBad}');

      // per scored rep: x, f
      final samples = (exp['samples'] as List).cast<Map<String, dynamic>>();
      final scoredRef = [for (final s in samples) s['rep'] as int];
      final scoredApp = [for (final i in a.use) a.rows[i].rep];
      if (scoredRef.join(',') != scoredApp.join(',')) problems.add('scored reps app $scoredApp ref $scoredRef');
      final xd = Diff(), fdd = Diff();
      final inCh = head.inputChannels;
      for (var j = 0; j < math.min(samples.length, a.x.length); j++) {
        final ex2 = samples[j]['x'] as List, ef = samples[j]['f'] as List;
        for (var c = 0; c < ex2.length; c++) {
          for (var t = 0; t < (ex2[c] as List).length; t++) {
            xd.add(a.x[j][c][t], _d((ex2[c] as List)[t]), 'rep ${samples[j]['rep']} x ${inCh[c]}[$t]');
          }
        }
        for (var k = 0; k < ef.length; k++) {
          fdd.add(a.f[j][k], _d(ef[k]), 'rep ${samples[j]['rep']} f ${head.features[k]}');
        }
      }
      row['x'] = xd.maxAbs;
      row['f'] = fdd.maxAbs;
      if (xd.bad > 0) problems.add('x: ${xd.bad} bad, first ${xd.firstBad}');
      if (fdd.bad > 0) problems.add('f: ${fdd.bad} bad, first ${fdd.firstBad}');

      // ONNX: probs, label, message (multi-task), and the separate model's probs / labels
      if (ortLib == null) {
        problems.add('ORT_LIB not set: ONNX stage not run');
      } else {
        for (final (which, mc, expSamples) in [
          ('multitask', cfg, samples),
          ('separate', sep, ((g['expected_separate'] as Map<String, dynamic>)['samples'] as List).cast<Map<String, dynamic>>()),
        ]) {
          final h = mc.heads[ex]!;
          final model = ShoulderHeadModel(h, File('$bundle/models/${h.onnxFile}').readAsBytesSync(), libraryPath: ortLib);
          final sw2 = Stopwatch()..start();
          final probs = model.predict(a.x, a.f);
          final onnxMs = sw2.elapsedMicroseconds / 1000.0;
          model.close();
          final pd = Diff();
          var labels = 0, messages = 0;
          for (var j = 0; j < math.min(probs.length, expSamples.length); j++) {
            final ep = expSamples[j]['probs'] as List;
            for (var k = 0; k < ep.length; k++) {
              pd.add(probs[j][k], _d(ep[k]), 'rep ${expSamples[j]['rep']} p[$k]', relative: false);
            }
            final v = verdict(fb, h, probs[j], side);
            if (v.label == expSamples[j]['label']) labels++;
            if (v.message == expSamples[j]['message']) messages++;
          }
          final pre = which == 'multitask' ? '' : 'sep_';
          row['${pre}probs'] = pd.maxAbs;
          row['${pre}labels'] = '$labels/${expSamples.length}';
          row['${pre}messages'] = '$messages/${expSamples.length}';
          row['${pre}onnx_ms'] = onnxMs;
          if (pd.bad > 0) problems.add('$which probs: ${pd.firstBad}');
          if (labels != expSamples.length) problems.add('$which labels $labels/${expSamples.length}');
          if (messages != expSamples.length) problems.add('$which messages $messages/${expSamples.length}');
        }
      }
      row['problems'] = problems;
      report[name] = row;
      final out = File('build/shoulder_parity.json')..createSync(recursive: true);
      out.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
