/// Port of reference_python/pose_worker.py `sil_features(mask, lm)`: silhouette numbers of one frame from
/// MediaPipe's person mask (> 0.5 = person) and the normalized landmarks.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/np_port.dart';

const gapFracs = [0.40, 0.55, 0.70, 0.85];
const topFracs = [0.65, 0.80];
const silNames = [
  'gap40',
  'gap55',
  'gap70',
  'gap85',
  'shtop65',
  'shtop80',
  'neck65',
  'neck80',
  'mask_ok',
];
const _arms = [
  [11, 13, 7], // person's LEFT: shoulder, elbow, ear
  [12, 14, 8], // RIGHT
];

/// The person mask at the size of the analysed frame, thresholded (mask > 0.5), packed 1 bit per pixel
/// row-major (bit 7 of byte 0 = pixel (0, 0)), as the pose capture sends it.
class PersonMask {
  final int width, height;
  final Uint8List bits;

  PersonMask(this.width, this.height, this.bits);

  /// From mask values 0..1 (or 0..255 with [scale] 255).
  factory PersonMask.fromValues(
    int width,
    int height,
    List<num> values, {
    double scale = 1.0,
  }) {
    final bits = Uint8List((width * height + 7) >> 3);
    for (var i = 0; i < width * height; i++) {
      if (values[i] / scale > 0.5) bits[i >> 3] |= 0x80 >> (i & 7);
    }
    return PersonMask(width, height, bits);
  }

  bool person(int x, int y) {
    final i = y * width + x;
    return (bits[i >> 3] & (0x80 >> (i & 7))) != 0;
  }
}

/// pose_worker._march: mask values along p + t*d, t = 0..length pixels (nearest pixel, np.rint;
/// outside the image = background).
List<bool> _march(
  PersonMask m,
  double px,
  double py,
  double dx,
  double dy,
  double length,
) {
  final n = math.max(1.0, length).toInt() + 1;
  return List<bool>.generate(n, (t) {
    final x = pyRound(px + t * dx), y = pyRound(py + t * dy);
    return x >= 0 && x < m.width && y >= 0 && y < m.height && m.person(x, y);
  });
}

/// (2 x 9) silhouette measurements (row 0 = person's left, 1 = right; [silNames] order), NaN if impossible.
/// [lm]: 33 x 5 normalized landmarks (only x, y are used). Values are float32, as pose_worker returns them.
Float64List silFeatures(PersonMask? mask, List<double>? lm) {
  final out = Float64List(18)..fillRange(0, 18, double.nan);
  if (mask == null || lm == null) return out;
  for (final j in const [11, 12, 13, 14, 23, 24]) {
    if (!lm[j * 5].isFinite || !lm[j * 5 + 1].isFinite) return out;
  }
  final w = mask.width.toDouble(), h = mask.height.toDouble();
  double px(int j) => f32(lm[j * 5]) * w;
  double py(int j) => f32(lm[j * 5 + 1]) * h;
  final smx = 0.5 * (px(11) + px(12)), smy = 0.5 * (py(11) + py(12));
  final hmx = 0.5 * (px(23) + px(24)), hmy = 0.5 * (py(23) + py(24));
  var ux = smx - hmx, uy = smy - hmy;
  final n = math.sqrt(ux * ux + uy * uy);
  final swx = px(11) - px(12), swy = py(11) - py(12);
  final sw = math.sqrt(swx * swx + swy * swy);
  if (n < 1e-6 || sw < 4) return out;
  ux /= n;
  uy /= n;
  final lx = -uy, ly = ux;
  final cx = 0.5 * (smx + hmx), cy = 0.5 * (smy + hmy);
  final ok = _march(mask, cx, cy, ux, uy, 0)[0] ? 1.0 : 0.0;
  for (var s = 0; s < 2; s++) {
    final iSh = _arms[s][0], iEl = _arms[s][1], iEar = _arms[s][2];
    final sx = px(iSh), sy = py(iSh), ex = px(iEl), ey = py(iEl);
    final into = (smx - sx) * lx + (smy - sy) * ly > 0;
    final ix = into ? lx : -lx, iy = into ? ly : -ly;
    final l = 0.9 * sw;
    final vals = <double>[];
    for (final f in gapFracs) {
      // background between the upper arm and the body
      final v = _march(mask, sx + f * (ex - sx), sy + f * (ey - sy), ix, iy, l);
      final i0 = v.indexOf(false);
      if (i0 < 0) {
        vals.add(
          0.0,
        ); // never leaves the person: arm against the body (or clothes)
        continue;
      }
      final back = v.indexOf(true, i0);
      vals.add((back >= 0 ? back - i0 : v.length - i0) / sw);
    }
    final tops = <double>[], necks = <double>[];
    for (final k in topFracs) {
      // shoulder outline above the shoulder line
      final p0x = smx + k * (sx - smx), p0y = smy + k * (sy - smy);
      final v = _march(mask, p0x, p0y, ux, uy, 0.6 * sw);
      final hh = v.indexOf(false);
      if (hh < 0) {
        tops.add(double.nan);
        necks.add(double.nan);
        continue;
      }
      tops.add(hh / sw);
      final earX = px(iEar), earY = py(iEar);
      necks.add(
        earX.isFinite && earY.isFinite
            ? ((earX - (p0x + hh * ux)) * ux + (earY - (p0y + hh * uy)) * uy) /
                  sw
            : double.nan,
      );
    }
    final row = [...vals, ...tops, ...necks, ok];
    for (var k = 0; k < 9; k++) {
      out[s * 9 + k] = f32(row[k]);
    }
  }
  return out;
}

/// float32 -> float16 -> float32 (pose_worker stores the silhouette numbers as float16: the training data).
double f16(double x) {
  if (!x.isFinite || x == 0) return x;
  final a = x.abs();
  if (a >= 65520) return x.sign * double.infinity;
  // float16: 10 explicit mantissa bits; subnormals below 2^-14 have a fixed spacing of 2^-24
  final e = a < 6.103515625e-05 ? -14 : (math.log(a) / math.ln2).floor();
  var exp = e;
  if (math.pow(2.0, exp + 1) <= a) exp++;
  if (math.pow(2.0, exp) > a) exp--;
  final q = math.pow(2.0, math.max(exp, -14) - 10).toDouble();
  return x.sign * pyRound(a / q) * q;
}
