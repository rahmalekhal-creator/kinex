/// A recorded set: what the pose capture keeps for every camera frame, in the format of a golden file's
/// `input` (and of `reference_predict.py --pose x.json`).
library;

import 'dart:typed_data';

const int kLandmarks = 33;

class PoseRecording {
  /// Frame times (ms).
  final Float64List tMs;

  /// Normalized landmarks, T x 33 x 5 (x, y, z, visibility, presence) as float32; NaN = nobody found.
  final Float32List lm;

  /// World landmarks, T x 33 x 3 (metres) as float32.
  final Float32List world;

  /// Silhouette numbers, T x 2 x K (person's left, right) or null when the mask was off.
  final Float32List? sil;
  final List<String>? silNames;

  /// Size of the analysed (upright) frame: pixel = normalized x width / y height.
  final double width, height;

  PoseRecording({
    required this.tMs,
    required this.lm,
    required this.world,
    required this.width,
    required this.height,
    this.sil,
    this.silNames,
  });

  int get length => tMs.length;
  int get silK => silNames?.length ?? 9;

  /// Reads the JSON layout of reference_predict.load_pose (null = NaN, a null frame = all NaN).
  factory PoseRecording.fromJson(Map<String, dynamic> j) {
    final t = (j['t_ms'] as List).map((v) => (v as num).toDouble()).toList();
    final n = t.length;
    Float32List frames(List src, int perFrame, int inner) {
      final out = Float32List(n * perFrame)
        ..fillRange(0, n * perFrame, double.nan);
      for (var i = 0; i < n; i++) {
        final fr = src[i];
        if (fr == null) continue;
        var k = i * perFrame;
        for (final row in fr as List) {
          if (row == null) {
            k += inner;
            continue;
          }
          for (final v in row as List) {
            out[k++] = v == null ? double.nan : (v as num).toDouble();
          }
        }
      }
      return out;
    }

    final silNames = (j['sil_names'] as List?)?.cast<String>();
    final k = silNames?.length ?? 9;
    return PoseRecording(
      tMs: Float64List.fromList(t),
      lm: frames(j['lm'] as List, kLandmarks * 5, 5),
      world: frames(j['world'] as List, kLandmarks * 3, 3),
      sil: j['sil'] == null ? null : frames(j['sil'] as List, 2 * k, k),
      silNames: silNames,
      width: (j['width'] as num).toDouble(),
      height: (j['height'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    double? v(double x) => x.isNaN ? null : x;
    List frames(Float32List a, int rows, int cols) => [
      for (var i = 0; i < length; i++)
        a[i * rows * cols].isNaN && rows == kLandmarks
            ? null
            : [
                for (var r = 0; r < rows; r++)
                  [
                    for (var c = 0; c < cols; c++)
                      v(a[(i * rows + r) * cols + c]),
                  ],
              ],
    ];
    return {
      't_ms': tMs.toList(),
      'lm': frames(lm, kLandmarks, 5),
      'world': frames(world, kLandmarks, 3),
      'sil': sil == null ? null : frames(sil!, 2, silK),
      if (silNames != null) 'sil_names': silNames,
      'width': width,
      'height': height,
    };
  }
}
