import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kinex_pose/kinex_pose.dart';

const _bones = [
  [11, 12],
  [11, 13],
  [13, 15],
  [12, 14],
  [14, 16],
  [11, 23],
  [12, 24],
  [23, 24],
  [23, 25],
  [25, 27],
  [24, 26],
  [26, 28],
  [0, 7],
  [0, 8],
];
const _arm = {
  'left': [11, 13, 15],
  'right': [12, 14, 16],
};

/// The skeleton of the latest frame over the preview. The preview is fitted (aspect kept) in the widget, and
/// mirrored for the front camera, while the landmarks come from the unmirrored frame.
class SkeletonPainter extends CustomPainter {
  final ValueListenable<PoseFrame?> frames;
  final bool Function() mirrored;
  final String Function() highlightSide;

  /// Repaints whenever a new frame arrives, without rebuilding any widget.
  SkeletonPainter({
    required this.frames,
    required this.mirrored,
    required this.highlightSide,
  }) : super(repaint: frames);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frames.value;
    if (frame == null) return;
    final mirrored = this.mirrored();
    final lm = frame.lm;
    if (lm == null || frame.width == 0 || frame.height == 0) return;
    final scale = (size.width / frame.width) < (size.height / frame.height)
        ? size.width / frame.width
        : size.height / frame.height;
    final w = frame.width * scale, h = frame.height * scale;
    final ox = (size.width - w) / 2, oy = (size.height - h) / 2;
    Offset p(int j) {
      final x = lm[j * 5];
      return Offset(ox + (mirrored ? 1 - x : x) * w, oy + lm[j * 5 + 1] * h);
    }

    bool ok(int j) => lm[j * 5].isFinite && lm[j * 5 + 3] >= 0.3;
    final hot = _arm[highlightSide()] ?? const <int>[];
    final base = Paint()
      ..color = const Color(0xFF63E6FF)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final arm = Paint()
      ..color = const Color(0xFFF79009)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final b in _bones) {
      if (ok(b[0]) && ok(b[1])) {
        canvas.drawLine(
          p(b[0]),
          p(b[1]),
          hot.contains(b[0]) && hot.contains(b[1]) ? arm : base,
        );
      }
    }
    for (final j in {for (final b in _bones) ...b}) {
      if (ok(j)) {
        canvas.drawCircle(
          p(j),
          hot.contains(j) ? 7 : 5,
          hot.contains(j) ? arm : base,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) => false; // repaints through the frames notifier
}
