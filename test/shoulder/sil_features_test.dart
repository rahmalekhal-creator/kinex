// pose_worker.sil_features port against shoulder_app_bundle/golden/sil_tests.json (|Δ| < 1e-4),
// and the float16 rounding of the stored silhouette numbers against numpy.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reeducation/features/exercise_ai/shoulder/sil_features.dart';

/// Minimal PNG decoder: 8-bit greyscale, not interlaced (the format of the test masks).
(int, int, Uint8List) decodeGreyPng(Uint8List b) {
  final bd = ByteData.sublistView(b);
  var i = 8, w = 0, h = 0;
  final idat = BytesBuilder();
  while (i < b.length) {
    final n = bd.getUint32(i);
    final type = String.fromCharCodes(b.sublist(i + 4, i + 8));
    if (type == 'IHDR') {
      w = bd.getUint32(i + 8);
      h = bd.getUint32(i + 12);
      if (b[i + 16] != 8 || b[i + 17] != 0 || b[i + 20] != 0) throw UnsupportedError('PNG must be 8-bit grey');
    } else if (type == 'IDAT') {
      idat.add(b.sublist(i + 8, i + 8 + n));
    }
    i += 12 + n;
  }
  final raw = ZLibCodec().decode(idat.toBytes());
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final f = raw[y * (w + 1)];
    for (var x = 0; x < w; x++) {
      final cur = raw[y * (w + 1) + 1 + x];
      final a = x > 0 ? out[y * w + x - 1] : 0, up = y > 0 ? out[(y - 1) * w + x] : 0;
      final c = x > 0 && y > 0 ? out[(y - 1) * w + x - 1] : 0;
      int pred;
      switch (f) {
        case 0:
          pred = 0;
        case 1:
          pred = a;
        case 2:
          pred = up;
        case 3:
          pred = (a + up) >> 1;
        default:
          final p = a + up - c, pa = (p - a).abs(), pb = (p - up).abs(), pc = (p - c).abs();
          pred = pa <= pb && pa <= pc ? a : (pb <= pc ? up : c);
      }
      out[y * w + x] = (cur + pred) & 0xff;
    }
  }
  return (w, h, out);
}

void main() {
  final g = jsonDecode(File('shoulder_app_bundle/golden/sil_tests.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = (g['cases'] as List).cast<Map<String, dynamic>>();
  var maxDiff = 0.0;

  for (var k = 0; k < cases.length; k++) {
    final c = cases[k];
    test('sil case $k (${c['source']} frame ${c['frame']})', () {
      final (w, h, px) = decodeGreyPng(base64Decode(c['mask_png_base64'] as String));
      expect([w, h], [c['width'], c['height']]);
      final mask = PersonMask.fromValues(w, h, px, scale: 255.0);
      final lm = [
        for (final row in c['lm'] as List)
          for (final v in row as List) v == null ? double.nan : (v as num).toDouble()
      ];
      final out = silFeatures(mask, lm);
      final exp = c['expected'] as List;
      for (var s = 0; s < 2; s++) {
        for (var j = 0; j < 9; j++) {
          final e = (exp[s] as List)[j];
          final a = out[s * 9 + j];
          if (e == null) {
            expect(a.isNaN, isTrue, reason: 'side $s ${silNames[j]} should be NaN, got $a');
          } else {
            final d = (a - (e as num)).abs();
            if (d > maxDiff) maxDiff = d;
            expect(d, lessThan(1e-4), reason: 'side $s ${silNames[j]}: $a vs $e');
          }
        }
      }
    });
  }

  test('float16 rounding = numpy', () {
    final fx = (jsonDecode(File('test/shoulder/fixtures/np_cases.json').readAsStringSync()) as Map<String, dynamic>)['f16']
        as Map<String, dynamic>;
    final xs = (fx['x'] as List).cast<num>(), ys = (fx['f16'] as List).cast<num>();
    for (var i = 0; i < xs.length; i++) {
      final y = ys[i].toDouble();
      expect((f16(xs[i].toDouble()) - y).abs(), lessThanOrEqualTo(1e-8 * y.abs()), reason: '${xs[i]}');
    }
  });

  tearDownAll(() => stdout.writeln('sil_features max |Δ| = $maxDiff'));
}
