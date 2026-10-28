/// The ONNX head of one exercise: x (reps, C, T) + f (reps, F) raw -> probs (reps, K).
library;

import 'dart:typed_data';

import '../core/ort_ffi.dart';
import 'shoulder_config.dart';

class ShoulderHeadModel {
  final HeadConfig head;
  final OrtSession session;

  ShoulderHeadModel(
    this.head,
    Uint8List onnxBytes, {
    String? libraryPath,
    int threads = 1,
  }) : session = OrtSession.fromBytes(
         onnxBytes,
         libraryPath: libraryPath,
         intraOpThreads: threads,
       );

  /// x[rep][channel] = T values; f[rep] = F values (NaN allowed). Returns probs per rep.
  List<List<double>> predict(List<List<Float32List>> x, List<Float32List> f) {
    if (x.isEmpty) return const [];
    final reps = x.length,
        c = x[0].length,
        t = x[0][0].length,
        nf = head.features.length;
    final xd = Float32List(reps * c * t);
    for (var r = 0; r < reps; r++) {
      for (var k = 0; k < c; k++) {
        xd.setAll((r * c + k) * t, x[r][k]);
      }
    }
    final inputs = <String, OrtTensor>{
      'x': OrtTensor(xd, [reps, c, t]),
    };
    if (session.inputNames.contains('f')) {
      final fd = Float32List(reps * nf);
      for (var r = 0; r < reps; r++) {
        fd.setAll(r * nf, f[r]);
      }
      inputs['f'] = OrtTensor(fd, [reps, nf]);
    }
    final out = session.run(inputs)['probs']!;
    final k = out.shape[1];
    return [
      for (var r = 0; r < reps; r++)
        [for (var j = 0; j < k; j++) out.data[r * k + j].toDouble()],
    ];
  }

  void close() => session.close();
}
