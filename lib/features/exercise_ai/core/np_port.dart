/// Ports of the numpy / scipy routines used by the exercise pipelines, with numpy's semantics:
/// NaN handling, linear percentiles, round half to even, first index on ties, pairwise sums,
/// `np.interp` clamping, `savgol_filter(mode="interp")` and `find_peaks(prominence, distance)`.
/// Everything is computed in doubles (numpy's float64); [f32] rounds where numpy stores float32.
library;

import 'dart:math' as math;
import 'dart:typed_data';

final Float32List _f32 = Float32List(1);

/// Rounds a double to the nearest float32 (as numpy storing a value in a float32 array).
double f32(double x) {
  _f32[0] = x;
  return _f32[0];
}

const double kRad2Deg = 180.0 / math.pi;

/// np.degrees
double degrees(double x) => x * kRad2Deg;

/// np.clip for one value (NaN stays NaN).
double clip(double x, double lo, double hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}

/// Python round() / np.rint: half to even.
int pyRound(double x) {
  final f = x.floorToDouble();
  final d = x - f;
  final fi = f.toInt();
  if (d > 0.5) return fi + 1;
  if (d < 0.5) return fi;
  return fi.isEven ? fi : fi + 1;
}

/// np.sign: -1, 0, 1 or NaN.
double sign(double x) =>
    x.isNaN ? double.nan : (x > 0 ? 1.0 : (x < 0 ? -1.0 : 0.0));

// ----------------------------------------------------------------------------- sums and means
double _pairwise(List<double> a, int start, int n) {
  if (n < 8) {
    var res = -0.0;
    for (var i = 0; i < n; i++) {
      res += a[start + i];
    }
    return res;
  } else if (n <= 128) {
    final r = List<double>.generate(8, (j) => a[start + j]);
    var i = 8;
    for (; i < n - (n % 8); i += 8) {
      for (var j = 0; j < 8; j++) {
        r[j] += a[start + i + j];
      }
    }
    var res = ((r[0] + r[1]) + (r[2] + r[3])) + ((r[4] + r[5]) + (r[6] + r[7]));
    for (; i < n; i++) {
      res += a[start + i];
    }
    return res;
  }
  var n2 = n ~/ 2;
  n2 -= n2 % 8;
  return _pairwise(a, start, n2) + _pairwise(a, start + n2, n - n2);
}

/// np.sum of a 1-D float64 array (pairwise summation).
double npSum(List<double> a) => _pairwise(a, 0, a.length);

/// np.mean (NaN propagates; empty -> NaN).
double npMean(List<double> a) => a.isEmpty ? double.nan : npSum(a) / a.length;

/// np.nanmean (all NaN -> NaN).
double nanmean(List<double> a) {
  var cnt = 0;
  final z = Float64List(a.length);
  for (var i = 0; i < a.length; i++) {
    final v = a[i];
    if (v.isNaN) {
      z[i] = 0.0;
    } else {
      z[i] = v;
      cnt++;
    }
  }
  return cnt == 0 ? double.nan : npSum(z) / cnt;
}

/// np.nanmin / np.nanmax (all NaN -> NaN, as the sds._nanmin/_nanmax wrappers).
double nanmin(List<double> a) {
  var m = double.nan;
  for (final v in a) {
    if (!v.isNaN && (m.isNaN || v < m)) m = v;
  }
  return m;
}

double nanmax(List<double> a) {
  var m = double.nan;
  for (final v in a) {
    if (!v.isNaN && (m.isNaN || v > m)) m = v;
  }
  return m;
}

/// np.min / np.max of values known to be finite (as `_seg(..., np.max)` after dropping NaN).
double npMin(List<double> a) => a.reduce((x, y) => y < x ? y : x);
double npMax(List<double> a) => a.reduce((x, y) => y > x ? y : x);

/// np.ptp of finite values.
double ptp(List<double> a) => npMax(a) - npMin(a);

bool anyFinite(List<double> a) {
  for (final v in a) {
    if (v.isFinite) return true;
  }
  return false;
}

List<double> finiteOnly(List<double> a) => [
  for (final v in a)
    if (v.isFinite) v,
];

// ----------------------------------------------------------------------------- percentiles / median
double _lerp(double a, double b, double t) {
  final diff = b - a;
  return t >= 0.5 ? b - diff * (1 - t) : a + diff * t;
}

/// np.percentile(sorted, q) with the default 'linear' method, on an already sorted NaN-free list.
double _percentileSorted(List<double> s, double q) {
  final n = s.length;
  if (n == 0) return double.nan;
  final virt = (n - 1) * (q / 100.0);
  if (virt >= n - 1) return s[n - 1];
  if (virt <= 0) return s[0];
  final prev = virt.floorToDouble();
  final i = prev.toInt();
  return _lerp(s[i], s[i + 1], virt - prev);
}

/// np.percentile (any NaN -> NaN).
double percentile(List<double> a, double q) {
  for (final v in a) {
    if (v.isNaN) return double.nan;
  }
  final s = List<double>.of(a)..sort();
  return _percentileSorted(s, q);
}

/// np.nanpercentile (all NaN -> NaN).
double nanpercentile(List<double> a, double q) {
  final s = [
    for (final v in a)
      if (!v.isNaN) v,
  ]..sort();
  return _percentileSorted(s, q);
}

/// np.nanmedian (all NaN -> NaN): middle value, or the mean of the two middle values.
double nanmedian(List<double> a) {
  final s = [
    for (final v in a)
      if (!v.isNaN) v,
  ]..sort();
  final n = s.length;
  if (n == 0) return double.nan;
  if (n.isOdd) return s[n ~/ 2];
  return (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2.0;
}

/// np.argmin over finite values (first index on ties); NaN entries are skipped (np.nanargmin).
int nanargmin(List<double> a) {
  var k = -1;
  for (var i = 0; i < a.length; i++) {
    if (!a[i].isNaN && (k < 0 || a[i] < a[k])) k = i;
  }
  return k;
}

/// np.argmin of a NaN-free range a[lo..hi] (first index on ties), returned relative to lo.
int argminRange(List<double> a, int lo, int hi) {
  var k = lo;
  for (var i = lo + 1; i <= hi; i++) {
    if (a[i] < a[k]) k = i;
  }
  return k - lo;
}

// ----------------------------------------------------------------------------- interpolation
/// Index j with xp[j] <= x < xp[j+1]; -1 if x < xp[0]; len if x > xp[last]; len-1 if x == xp[last].
int _search(double x, List<double> xp) {
  final n = xp.length;
  if (x < xp[0]) return -1;
  if (x > xp[n - 1]) return n;
  var lo = 0, hi = n - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (xp[mid] <= x) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

/// np.interp(x, xp, fp): linear, clamped at the ends, numpy's NaN fallbacks.
Float64List interp(List<double> x, List<double> xp, List<double> fp) {
  final out = Float64List(x.length);
  final n = xp.length;
  final lval = fp[0], rval = fp[n - 1];
  for (var i = 0; i < x.length; i++) {
    final xv = x[i];
    if (xv.isNaN) {
      out[i] = xv;
      continue;
    }
    if (n == 1) {
      out[i] = xv < xp[0] ? lval : (xv > xp[0] ? rval : fp[0]);
      continue;
    }
    final j = _search(xv, xp);
    if (j == -1) {
      out[i] = lval;
    } else if (j == n) {
      out[i] = rval;
    } else if (j == n - 1) {
      out[i] = fp[j];
    } else if (xp[j] == xv) {
      out[i] = fp[j];
    } else {
      final slope = (fp[j + 1] - fp[j]) / (xp[j + 1] - xp[j]);
      var v = slope * (xv - xp[j]) + fp[j];
      if (v.isNaN) {
        v = slope * (xv - xp[j + 1]) + fp[j + 1];
        if (v.isNaN && fp[j] == fp[j + 1]) v = fp[j];
      }
      out[i] = v;
    }
  }
  return out;
}

/// np.searchsorted(a, v, side) for a sorted array.
int searchsorted(List<double> a, double v, {bool right = false}) {
  var lo = 0, hi = a.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (right ? a[mid] <= v : a[mid] < v) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// np.arange(start, stop, step) for floats (numpy fills start + i * (a[1] - a[0])).
Float64List arange(double start, double stop, double step) {
  final len = math.max(0, ((stop - start) / step).ceil());
  final out = Float64List(len);
  if (len == 0) return out;
  out[0] = start;
  if (len > 1) {
    final second = start + step;
    out[1] = second;
    final delta = second - start;
    for (var i = 2; i < len; i++) {
      out[i] = start + i * delta;
    }
  }
  return out;
}

/// np.linspace(start, stop, num) (endpoint included).
Float64List linspace(double start, double stop, int num) {
  final out = Float64List(num);
  if (num == 1) {
    out[0] = start;
    return out;
  }
  final div = num - 1;
  final delta = stop - start;
  final step = delta / div;
  for (var i = 0; i < num; i++) {
    out[i] = step == 0 ? (i / div) * delta + start : i * step + start;
  }
  out[num - 1] = stop;
  return out;
}

/// shoulder_lib.fill_nan: linear interpolation over NaNs (edges held); null if fewer than 2 valid samples.
Float64List? fillNan(List<double> x) {
  final xi = <double>[], xv = <double>[];
  for (var i = 0; i < x.length; i++) {
    if (x[i].isFinite) {
      xi.add(i.toDouble());
      xv.add(x[i]);
    }
  }
  if (xi.length < 2) return null;
  return interp([for (var i = 0; i < x.length; i++) i.toDouble()], xi, xv);
}

// ----------------------------------------------------------------------------- Savitzky-Golay
/// Least-squares polynomial (degree 2) through (0..n-1, y), evaluated at the given positions.
List<double> _polyfit2Eval(List<double> y, List<double> at) {
  final n = y.length;
  final tm = (n - 1) / 2.0;
  // normal equations in centred coordinates u = t - tm
  var s0 = 0.0, s2 = 0.0, s4 = 0.0, b0 = 0.0, b1 = 0.0, b2 = 0.0;
  for (var i = 0; i < n; i++) {
    final u = i - tm;
    final u2 = u * u;
    s0 += 1;
    s2 += u2;
    s4 += u2 * u2;
    b0 += y[i];
    b1 += u * y[i];
    b2 += u2 * y[i];
  }
  // odd moments vanish: [s0 0 s2; 0 s2 0; s2 0 s4] c = b
  final c1 = b1 / s2;
  final det = s0 * s4 - s2 * s2;
  final c0 = (b0 * s4 - s2 * b2) / det;
  final c2 = (s0 * b2 - s2 * b0) / det;
  return [for (final t in at) c0 + c1 * (t - tm) + c2 * (t - tm) * (t - tm)];
}

/// scipy.signal.savgol_coeffs(window, 2) (deriv 0): symmetric smoothing weights.
List<double> _savgolCoeffs2(int window) {
  final m = (window - 1) ~/ 2;
  final den = (2 * m - 1) * (2 * m + 1) * (2 * m + 3);
  return [
    for (var i = -m; i <= m; i++)
      (3 * (3 * m * m + 3 * m - 1) - 15 * i * i) / den,
  ];
}

/// scipy.signal.savgol_filter(x, window, 2) with the default mode='interp'.
Float64List savgol2(List<double> x, int window) {
  final n = x.length;
  final c = _savgolCoeffs2(window);
  final h = window ~/ 2;
  final y = Float64List(n);
  for (var i = 0; i < n; i++) {
    var tmp = c[h] * x[i];
    for (var j = 1; j <= h; j++) {
      final l = i - j, r = i + j;
      tmp += ((l >= 0 ? x[l] : 0.0) + (r < n ? x[r] : 0.0)) * c[h + j];
    }
    y[i] = tmp;
  }
  // edges: polynomial fitted to the first / last window, evaluated on the first / last h samples
  final left = _polyfit2Eval(x.sublist(0, window), [
    for (var t = 0; t < h; t++) t.toDouble(),
  ]);
  for (var t = 0; t < h; t++) {
    y[t] = left[t];
  }
  final right = _polyfit2Eval(x.sublist(n - window, n), [
    for (var t = window - h; t < window; t++) t.toDouble(),
  ]);
  for (var t = 0; t < h; t++) {
    y[n - h + t] = right[t];
  }
  return y;
}

/// shoulder_lib.smooth_nan: Savitzky-Golay smoothing that keeps NaN positions NaN.
Float64List smoothNan(List<double> x, double fs, [double winS = 0.25]) {
  final n = math.max(5, pyRound(winS * fs) | 1);
  var m = 0;
  for (final v in x) {
    if (v.isFinite) m++;
  }
  if (m <= n) return Float64List.fromList(x);
  final y = savgol2(fillNan(x)!, n);
  for (var i = 0; i < x.length; i++) {
    if (!x[i].isFinite) y[i] = double.nan;
  }
  return y;
}

// ----------------------------------------------------------------------------- linear fit
/// np.polyfit(x, y, 1)[0]: least-squares slope.
double polyfitSlope(List<double> x, List<double> y) {
  final mx = npMean(x), my = npMean(y);
  var sxy = 0.0, sxx = 0.0;
  for (var i = 0; i < x.length; i++) {
    final dx = x[i] - mx;
    sxy += dx * (y[i] - my);
    sxx += dx * dx;
  }
  return sxy / sxx;
}

// ----------------------------------------------------------------------------- find_peaks
class Peaks {
  final List<int> peaks;
  final List<double> prominences;
  const Peaks(this.peaks, this.prominences);
}

/// scipy.signal.find_peaks(x, prominence=pmin, distance=distance): local maxima (plateau middle),
/// then the distance rule (higher peaks first), then the prominence rule.
Peaks findPeaks(
  List<double> x, {
  required double prominence,
  required double distance,
}) {
  // _local_maxima_1d
  var peaks = <int>[];
  final iMax = x.length - 1;
  var i = 1;
  while (i < iMax) {
    if (x[i - 1] < x[i]) {
      var ahead = i + 1;
      while (ahead < iMax && x[ahead] == x[i]) {
        ahead++;
      }
      if (x[ahead] < x[i]) {
        peaks.add((i + ahead - 1) ~/ 2);
        i = ahead;
      }
    }
    i++;
  }
  // _select_by_peak_distance
  if (peaks.isNotEmpty) {
    final dist = distance.ceil();
    final keep = List<bool>.filled(peaks.length, true);
    final order = List<int>.generate(peaks.length, (k) => k);
    mergeSortBy(order, (a, b) => x[peaks[a]].compareTo(x[peaks[b]]));
    for (var p = peaks.length - 1; p >= 0; p--) {
      final j = order[p];
      if (!keep[j]) continue;
      var k = j - 1;
      while (k >= 0 && peaks[j] - peaks[k] < dist) {
        keep[k] = false;
        k--;
      }
      k = j + 1;
      while (k < peaks.length && peaks[k] - peaks[j] < dist) {
        keep[k] = false;
        k++;
      }
    }
    peaks = [
      for (var k = 0; k < peaks.length; k++)
        if (keep[k]) peaks[k],
    ];
  }
  // _peak_prominences (no window) + selection
  final outPeaks = <int>[];
  final outProm = <double>[];
  for (final p in peaks) {
    var leftMin = x[p];
    var k = p;
    while (k >= 0 && x[k] <= x[p]) {
      if (x[k] < leftMin) leftMin = x[k];
      k--;
    }
    var rightMin = x[p];
    k = p;
    while (k <= iMax && x[k] <= x[p]) {
      if (x[k] < rightMin) rightMin = x[k];
      k++;
    }
    final prom = x[p] - math.max(leftMin, rightMin);
    if (prominence <= prom) {
      outPeaks.add(p);
      outProm.add(prom);
    }
  }
  return Peaks(outPeaks, outProm);
}

/// Stable in-place sort of a list of ints.
void mergeSortBy(List<int> a, int Function(int, int) cmp) {
  if (a.length < 2) return;
  final mid = a.length ~/ 2;
  final l = a.sublist(0, mid), r = a.sublist(mid);
  mergeSortBy(l, cmp);
  mergeSortBy(r, cmp);
  var i = 0, j = 0, k = 0;
  while (i < l.length && j < r.length) {
    a[k++] = cmp(r[j], l[i]) < 0 ? r[j++] : l[i++];
  }
  while (i < l.length) {
    a[k++] = l[i++];
  }
  while (j < r.length) {
    a[k++] = r[j++];
  }
}
