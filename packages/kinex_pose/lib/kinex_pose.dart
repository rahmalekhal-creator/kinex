/// Live pose capture (Android): camera + MediaPipe Tasks PoseLandmarker (pose_landmarker_full.task).
/// Frames are upright and not mirrored; only the on-screen preview of the front camera is mirrored.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One analysed camera frame.
class PoseFrame {
  /// Camera timestamp (ms).
  final double tMs;

  /// Size of the analysed upright frame (pixel = normalized x width / y height).
  final int width, height;

  /// 33 x 5 normalized landmarks (x, y, z, visibility, presence), null when nobody is found.
  final Float32List? lm;

  /// 33 x 3 world landmarks (metres), null when nobody is found.
  final Float32List? world;

  /// Person mask (> 0.5), 1 bit per pixel row-major, at maskWidth x maskHeight; null when off.
  final Uint8List? maskBits;
  final int maskWidth, maskHeight;

  /// MediaPipe time (submit -> result) and image conversion time, ms.
  final double inferMs, prepMs;

  /// Age of the frame (ms) when its result left the native side: camera -> MediaPipe -> posted.
  final double ageMs;

  /// Time to pack the person mask (ms, 0 without mask), camera frames dropped because MediaPipe was busy since the
  /// previous result, and the delegate in use ('cpu' / 'gpu').
  final double maskMs;
  final int dropped;
  final String delegate;

  const PoseFrame(this.tMs, this.width, this.height, this.lm, this.world, this.maskBits, this.maskWidth,
      this.maskHeight, this.inferMs, this.prepMs, this.ageMs, [this.maskMs = 0, this.dropped = 0, this.delegate = 'cpu']);

  factory PoseFrame._fromMap(Map m) => PoseFrame(
        (m['t'] as num).toDouble(),
        m['w'] as int,
        m['h'] as int,
        m['lm'] as Float32List?,
        m['world'] as Float32List?,
        m['mask'] as Uint8List?,
        m['mw'] as int? ?? 0,
        m['mh'] as int? ?? 0,
        (m['inferMs'] as num?)?.toDouble() ?? double.nan,
        (m['prepMs'] as num?)?.toDouble() ?? double.nan,
        (m['ageMs'] as num?)?.toDouble() ?? double.nan,
        (m['maskMs'] as num?)?.toDouble() ?? 0,
        m['dropped'] as int? ?? 0,
        m['delegate'] as String? ?? 'cpu',
      );
}

class KinexPose {
  static const _methods = MethodChannel('kinex_pose');
  static const _events = EventChannel('kinex_pose/frames');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The frame stream (listen before [start]).
  static Stream<PoseFrame> frames() => _events.receiveBroadcastStream().map((e) => PoseFrame._fromMap(e as Map));

  /// Starts the camera and the landmarker. [mask]: also compute the person mask (costs time).
  /// Returns whether the on-screen preview is mirrored.
  /// [gpu]: MediaPipe GPU delegate (falls back to CPU if it cannot start). [skipWhileBusy]: drop camera frames while
  /// MediaPipe is busy (latest-frame policy; false only to measure the old behaviour).
  /// [maxSide]: longest side of the analysed frames (16:9). MediaPipe shrinks the frame to 224 px (person detector)
  /// and the person's crop to 256 px (landmarks), so 640 gives practically the same landmarks as 1280 for much less
  /// work per frame; the person mask is at this size, so exercises that use it ask the training size (1280).
  static Future<bool> start({
    bool front = true,
    bool mask = false,
    bool gpu = false,
    bool skipWhileBusy = true,
    int maxSide = 1280,
  }) async {
    final r = await _methods.invokeMapMethod<String, dynamic>('start',
        {'front': front, 'mask': mask, 'gpu': gpu, 'skipWhileBusy': skipWhileBusy, 'maxSide': maxSide});
    lastDelegate = r?['delegate'] as String? ?? 'cpu';
    lastAnalysisSize = (r?['analysisWidth'] as int? ?? 0, r?['analysisHeight'] as int? ?? 0);
    return r?['previewMirrored'] == true;
  }

  /// Delegate actually used by the last [start] ('cpu' or 'gpu').
  static String lastDelegate = 'cpu';

  /// Camera resolution of the analysed frames chosen by the last [start] (before rotation; 0 x 0 if unknown).
  static (int, int) lastAnalysisSize = (0, 0);

  static Future<void> stop() => _methods.invokeMethod('stop');
}

/// The camera preview (fitted inside the widget, aspect ratio kept).
class PosePreview extends StatelessWidget {
  const PosePreview({super.key});

  @override
  Widget build(BuildContext context) => const AndroidView(
        viewType: 'kinex_pose/preview',
        creationParamsCodec: StandardMessageCodec(),
      );
}
