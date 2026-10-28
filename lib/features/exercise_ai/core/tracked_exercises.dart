/// The exercises the live camera assistant can follow. The physiotherapist picks one (and the arm or leg) when
/// assigning an exercise; the patient's "Start Exercise" then opens the assistant with exactly that.
/// Same ids, regions and order as e4_app_bundle/exercise_catalog.json (and the tracked_exercise table).
library;

class BodyRegion {
  final String id; // shoulder / hip; its label is translated (bodyRegionLabel)
  final int order;
  const BodyRegion(this.id, this.order);
}

const bodyRegions = [BodyRegion('shoulder', 1), BodyRegion('hip', 2)];

class TrackedExercise {
  final String
  id; // e1..e4 (the key of the model head); its label is translated (trackedExerciseLabel)
  final String region;
  final int order;

  /// The side asked is a leg (e4) rather than an arm.
  final bool leg;
  const TrackedExercise(this.id, this.region, this.order, {this.leg = false});
}

const trackedExercises = [
  TrackedExercise('e1', 'shoulder', 1),
  TrackedExercise('e2', 'shoulder', 2),
  TrackedExercise('e3', 'shoulder', 3),
  TrackedExercise('e4', 'hip', 4, leg: true),
];

const trackedExerciseIds = ['e1', 'e2', 'e3', 'e4'];

TrackedExercise? trackedExercise(String? id) {
  for (final t in trackedExercises) {
    if (t.id == id) return t;
  }
  return null;
}

/// The side of this exercise is a leg (the lifted leg), not an arm.
bool isLegExercise(String? id) => trackedExercise(id)?.leg ?? false;

/// Body region of a tracked exercise (null when it is not tracked).
String? regionOf(String? id) => trackedExercise(id)?.region;

/// [items] grouped under their body region, regions and items in catalogue order; items without a tracked
/// exercise come last under the null region.
List<(String?, List<T>)> groupByRegion<T>(
  Iterable<T> items,
  String? Function(T) trackedId,
) {
  final out = <(String?, List<T>)>[];
  final all = items.toList();
  for (final r in bodyRegions) {
    // by catalogue order, then in the given order (a stable sort: List.sort is not)
    final idx = [
      for (var i = 0; i < all.length; i++)
        if (regionOf(trackedId(all[i])) == r.id) i,
    ];
    int ord(int i) => trackedExercise(trackedId(all[i]))!.order;
    idx.sort((a, b) {
      final c = ord(a).compareTo(ord(b));
      return c != 0 ? c : a.compareTo(b);
    });
    if (idx.isNotEmpty) out.add((r.id, [for (final i in idx) all[i]]));
  }
  final rest = [
    for (final it in all)
      if (regionOf(trackedId(it)) == null) it,
  ];
  if (rest.isNotEmpty) out.add((null, rest));
  return out;
}

/// A first guess from the catalog name, so the physiotherapist usually only has to confirm it.
String? guessTrackedExercise(String name) {
  final n = name.toLowerCase();
  if (n.contains('hip') && n.contains('abduction')) return 'e4';
  if (n.contains('hip') || n.contains('knee') || n.contains('ankle')) {
    return null;
  }
  if (n.contains('rotation')) return 'e3';
  if (n.contains('abduction')) return 'e2';
  if (n.contains('flexion') ||
      n.contains('elevation') ||
      n.contains('aarom') ||
      n.contains('stick')) {
    return 'e1';
  }
  return null;
}

/// Allowed range of the e4 target lift angle (degrees), as the server checks it.
const e4TargetMinDeg = 5.0, e4TargetMaxDeg = 90.0;

/// The e4 target lift angle typed by the physiotherapist: null = empty (not set), NaN = invalid, else the
/// angle rounded to 0.1 deg (a decimal comma is accepted).
double? parseTargetDeg(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || !v.isFinite) return double.nan;
  final r = (v * 10).round() / 10;
  return r < e4TargetMinDeg || r > e4TargetMaxDeg ? double.nan : r;
}
