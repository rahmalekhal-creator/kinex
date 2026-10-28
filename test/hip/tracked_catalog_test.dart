// The tracked exercises of the app against e4_app_bundle/exercise_catalog.json (ids, regions, order), the region
// grouping of the screens and the e4 prescription field.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/core/tracked_exercises.dart';

void main() {
  final cat = jsonDecode(File('e4_app_bundle/exercise_catalog.json').readAsStringSync()) as Map<String, dynamic>;

  test('app catalogue = exercise_catalog.json (ids, regions, region order)', () {
    final exs = (cat['exercises'] as List).cast<Map<String, dynamic>>();
    expect(trackedExerciseIds, [for (final e in exs) e['id']]);
    for (final e in exs) {
      expect(regionOf(e['id'] as String), e['region'], reason: '${e['id']}');
    }
    final regions = (cat['regions'] as List).cast<Map<String, dynamic>>();
    expect([for (final r in bodyRegions) r.id], [for (final r in regions) r['id']]);
    expect([for (final r in bodyRegions) r.order], [for (final r in regions) r['order']]);
    expect(isLegExercise('e4'), isTrue);
    expect(['e1', 'e2', 'e3'].any(isLegExercise), isFalse);
  });

  test('the server seed reads the same catalogue (reed/data copy)', () {
    expect(
      File('reed/data/exercise_catalog.json').readAsStringSync(),
      File('e4_app_bundle/exercise_catalog.json').readAsStringSync(),
    );
  });

  group('grouping by body region', () {
    test('Shoulder (e1, e2, e3) then Hip (e4), catalogue order, untracked last', () {
      final items = ['e4', null, 'e2', 'e1', 'e3', 'e4'];
      final g = groupByRegion(items, (String? x) => x);
      expect([for (final (r, _) in g) r], ['shoulder', 'hip', null]);
      expect(g[0].$2, ['e1', 'e2', 'e3']);
      expect(g[1].$2, ['e4', 'e4']);
      expect(g[2].$2, [null]);
    });

    test('keeps the given order within one exercise (stable)', () {
      final items = [
        {'id': 1, 'ai': 'e2'},
        {'id': 2, 'ai': 'e4'},
        {'id': 3, 'ai': 'e2'},
        {'id': 4, 'ai': 'e1'},
        {'id': 5, 'ai': 'e2'},
      ];
      final g = groupByRegion(items, (Map<String, Object> m) => m['ai'] as String);
      expect([for (final m in g[0].$2) m['id']], [4, 1, 3, 5]);
      expect([for (final m in g[1].$2) m['id']], [2]);
    });

    test('no region without items', () {
      expect(groupByRegion(['e1'], (String x) => x).length, 1);
      expect(groupByRegion(<String>[], (String x) => x), isEmpty);
    });
  });

  group('e4 target angle field', () {
    test('empty = not set', () => expect(parseTargetDeg('  '), isNull));
    test('valid values', () {
      expect(parseTargetDeg('35'), 35);
      expect(parseTargetDeg('27,5'), 27.5);
      expect(parseTargetDeg('30.04'), 30.0);
    });
    test('invalid values', () {
      for (final v in ['abc', '2', '91', '-10', 'NaN']) {
        expect(parseTargetDeg(v)!.isNaN, isTrue, reason: v);
      }
    });
  });

  test('the physiotherapist name guess knows the hip abduction', () {
    expect(guessTrackedExercise('Hip Abduction'), 'e4');
    expect(guessTrackedExercise('Knee Flexion'), isNull);
    expect(guessTrackedExercise('Shoulder abduction'), 'e2');
  });
}
