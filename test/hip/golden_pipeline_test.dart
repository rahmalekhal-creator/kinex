// Golden tests of the e4 (standing hip abduction) pipeline port: every e4_app_bundle/golden/e4__*.json, stage by
// stage, against the Python reference (reference_predict_e4.py). The ONNX stage needs the ONNX Runtime shared library:
// set ORT_LIB to its path (see SHOULDER_PARITY.md). A table of the differences is written to build/hip_parity.json.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/pose_recording.dart';
import 'package:reeducation/features/exercise_ai/hip/hip_pipeline.dart';
import 'package:reeducation/features/exercise_ai/hip/leg_ds.dart';
import 'package:reeducation/features/exercise_ai/shoulder/shoulder_model.dart';

const bundle = 'e4_app_bundle';
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
  final spec = HipSpec.fromJson(jsonDecode(File('$bundle/app_spec_e4.json').readAsStringSync()) as Map<String, dynamic>);
  final cfg = hipModelConfig(jsonDecode(File('$bundle/models/e4_head.json').readAsStringSync()) as Map<String, dynamic>);
  final head = cfg.heads[e4]!;
  final files = Directory('$bundle/golden').listSync().whereType<File>().map((f) => f.path).where((p) => p.contains('e4__')).toList()
    ..sort();
  final report = <String, dynamic>{};

  test('stored channel order = lds.channel_names()', () {
    expect(legChannelNames(), head.storedChannels);
  });

  test('settings come from e4_head.json', () {
    expect(cfg.analyze.fs, 30.0);
    expect(cfg.analyze.tLen, 64);
    expect(cfg.analyze.seg[e4]!.prominence, 0.35);
    expect(head.classes, ['good', 'knee', 'leanin', 'leanout']);
    expect(head.needsSilhouette, isFalse);
  });

  test('golden files found', () => expect(files, hasLength(5)));

  for (final path in files) {
    final name = path.split(RegExp(r'[\\/]')).last.replaceAll('.json', '');
    test(name, () {
      final g = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final side = g['side'] as String;
      final exp = g['expected'] as Map<String, dynamic>;
      final rec = PoseRecording.fromJson(g['input'] as Map<String, dynamic>);
      final sw = Stopwatch()..start();
      final a = analyzeVideoE4(rec, side, cfg.analyze, head, keepFrames: true)!;
      final row = <String, dynamic>{'frames_30hz': a.r.n, 'pipeline_ms': sw.elapsedMilliseconds};
      final problems = <String>[];

      // leg, side conflict, baseline
      if (a.leg != exp['leg']) problems.add('leg app ${a.leg} ref ${exp['leg']}');
      if (a.sideConflict != exp['side_conflict']) problems.add('side_conflict app ${a.sideConflict}');
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

      // per-frame channels (before windowing)
      final stored = legChannelNames();
      final fc = exp['frame_channels'] as Map<String, dynamic>;
      final fnames = (fc['names'] as List).cast<String>();
      final fvals = fc['values'] as List;
      final fd = Diff();
      if (fvals.length != a.r.n) problems.add('frame_channels length ${fvals.length} vs ${a.r.n}');
      for (var c = 0; c < fnames.length; c++) {
        final col = a.frames!.m[stored.indexOf(fnames[c])];
        for (var i = 0; i < math.min(fvals.length, col.length); i++) {
          fd.add(col[i], _d((fvals[i] as List)[c]), '${fnames[c]}[$i]');
        }
      }
      row['frame_channels'] = fd.maxAbs;
      if (fd.bad > 0) problems.add('frame_channels: ${fd.bad} bad, first ${fd.firstBad}');

      // per scored rep: x, f, peak_deg
      final samples = (exp['samples'] as List).cast<Map<String, dynamic>>();
      final scoredRef = [for (final s in samples) s['rep'] as int];
      final scoredApp = [for (final i in a.use) a.rows[i].rep];
      if (scoredRef.join(',') != scoredApp.join(',')) problems.add('scored reps app $scoredApp ref $scoredRef');
      final xd = Diff(), fdd = Diff(), pk = Diff();
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
        pk.add(a.peakDeg[j], _d(samples[j]['peak_deg']), 'rep ${samples[j]['rep']} peak_deg', t: 0.01, relative: false);
      }
      row['x'] = xd.maxAbs;
      row['f'] = fdd.maxAbs;
      row['peak_deg'] = pk.maxAbs;
      if (xd.bad > 0) problems.add('x: ${xd.bad} bad, first ${xd.firstBad}');
      if (fdd.bad > 0) problems.add('f: ${fdd.bad} bad, first ${fdd.firstBad}');
      if (pk.bad > 0) problems.add('peak_deg: ${pk.firstBad}');

      // ONNX: probs, then label / status / message with the file's default range target
      final rt = exp['range_target'] as Map<String, dynamic>;
      final target = rangeTarget(spec);
      if ((target.deg - (rt['deg'] as num)).abs() > 1e-9) problems.add('range target ${target.deg} vs ${rt['deg']}');
      if (ortLib == null) {
        problems.add('ORT_LIB not set: ONNX stage not run');
      } else {
        final model = ShoulderHeadModel(head, File('$bundle/models/${head.onnxFile}').readAsBytesSync(), libraryPath: ortLib);
        final probs = model.predict(a.x, a.f);
        model.close();
        final pd = Diff();
        var labels = 0, statuses = 0, messages = 0;
        final statusCount = <String, int>{};
        for (var j = 0; j < math.min(probs.length, samples.length); j++) {
          final ep = samples[j]['probs'] as List;
          for (var k = 0; k < ep.length; k++) {
            pd.add(probs[j][k], _d(ep[k]), 'rep ${samples[j]['rep']} p[$k]', relative: false);
          }
          final v = verdictE4(spec, head, probs[j], side, a.peakDeg[j], target);
          statusCount[v.status] = (statusCount[v.status] ?? 0) + 1;
          if (v.label == samples[j]['label']) labels++;
          if (v.status == samples[j]['status']) statuses++;
          if (v.message == samples[j]['message']) messages++;
        }
        row['probs'] = pd.maxAbs;
        row['labels'] = '$labels/${samples.length}';
        row['statuses'] = '$statuses/${samples.length}';
        row['messages'] = '$messages/${samples.length}';
        row['by_status'] = statusCount;
        if (pd.bad > 0) problems.add('probs: ${pd.firstBad}');
        if (labels != samples.length) problems.add('labels $labels/${samples.length}');
        if (statuses != samples.length) problems.add('statuses $statuses/${samples.length}');
        if (messages != samples.length) problems.add('messages $messages/${samples.length}');
        if (name.contains('shallow') && (statusCount['below_target'] ?? 0) == 0) {
          problems.add('shallow recording: no below_target rep');
        }
      }
      row['problems'] = problems;
      report[name] = row;
      final out = File('build/hip_parity.json')..createSync(recursive: true);
      out.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
