/// Wrong-arm check of one rep (e2 / e3): the arm that moves in the rep's window, with the rule of sds.choose_arm
/// (the other arm moves at least 1.5x more). A rep done with the wrong arm is not counted, however good it is.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/pose_recording.dart' show kLandmarks;
import 'shoulder_lib.dart';

/// Frames [i0]..[i1] (inclusive) of [r].
Resampled sliceResampled(Resampled r, int i0, int i1) {
  final a = math.max(0, i0), b = math.min(r.n - 1, i1) + 1;
  return Resampled(
    Float64List.sublistView(r.t, a, b),
    Float64List.sublistView(r.p, a * kLandmarks * 2, b * kLandmarks * 2),
    Float64List.sublistView(r.world, a * kLandmarks * 3, b * kLandmarks * 3),
    r.valid.sublist(a, b),
    r.w,
    r.h,
    r.fs,
  );
}

/// True when, between frames [i0] and [i1], the arm other than [side] clearly moves more.
bool wrongArmInWindow(Resampled r, int i0, int i1, String side) {
  final ev = sideEvidence(sliceResampled(r, i0, i1));
  final ml = ev['motion_left']!, mr = ev['motion_right']!;
  if (!ml.isFinite || !mr.isFinite) return false;
  final moving = ml >= mr ? 'left' : 'right';
  final clear = math.max(ml, mr) / math.max(math.min(ml, mr), 1e-6) >= 1.5;
  return clear && moving != side;
}
