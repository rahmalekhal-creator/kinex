// numpy / scipy primitives against values computed by numpy / scipy (tool/shoulder_ref/make_fixtures.py).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/np_port.dart';

List<double> _l(Object? v) => [for (final x in v as List) x == null ? double.nan : (x as num).toDouble()];

void expectClose(List<double> app, List<double> ref, String what, {double tol = 1e-7}) {
  expect(app.length, ref.length, reason: '$what length');
  for (var i = 0; i < ref.length; i++) {
    if (ref[i].isNaN) {
      expect(app[i].isNaN, isTrue, reason: '$what[$i] should be NaN');
    } else {
      expect((app[i] - ref[i]).abs(), lessThan(tol * (1 + ref[i].abs())), reason: '$what[$i] app ${app[i]} ref ${ref[i]}');
    }
  }
}

void main() {
  final fx = jsonDecode(File('test/shoulder/fixtures/np_cases.json').readAsStringSync()) as Map<String, dynamic>;

  test('round half to even', () {
    final r = fx['rounding'] as Map<String, dynamic>;
    final xs = _l(r['x']);
    expect([for (final x in xs) pyRound(x)], (r['round'] as List).cast<int>());
  });

  test('find_peaks on plateaus', () {
    final p = fx['plateau'] as Map<String, dynamic>;
    final pk = findPeaks(_l(p['x']), prominence: 0.5, distance: 1);
    expect(pk.peaks, (p['peaks'] as List).cast<int>());
    expectClose(pk.prominences, _l(p['prominences']), 'prominences');
  });

  final cases = (fx['cases'] as List).cast<Map<String, dynamic>>();
  for (var k = 0; k < cases.length; k++) {
    final c = cases[k];
    test('case $k (n=${(c['x'] as List).length})', () {
      final x = _l(c['x']);
      final filled = fillNan(x)!;
      expectClose(filled, _l(c['filled']), 'fill_nan');
      final pk = findPeaks(filled, prominence: (c['prominence'] as num).toDouble(), distance: (c['distance'] as num).toDouble());
      expect(pk.peaks, (c['peaks'] as List).cast<int>(), reason: 'find_peaks');
      expectClose(pk.prominences, _l(c['prominences']), 'prominences');
      expectClose(savgol2(filled, c['window'] as int), _l(c['savgol']), 'savgol');
      expectClose(smoothNan(x, 30.0, 0.25), _l(c['smooth']), 'smooth_nan');
      final q = _l(c['q']);
      expectClose([for (final v in q) nanpercentile(x, v)], _l(c['nanpercentile']), 'nanpercentile');
      expectClose([nanmedian(x)], [(c['nanmedian'] as num).toDouble()], 'nanmedian');
      expectClose(interp(_l(c['xq']), _l(c['xp']), _l(c['fp'])), _l(c['interp']), 'interp');
    });
  }
}
