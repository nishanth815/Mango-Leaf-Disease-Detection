import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Pure-Dart ports of `image_quality_check.py` / `severity_estimation.py`
/// from the Python backend (OpenCV replaced by plain loops), so the app
/// needs no native image library and no network.

// ---------------------------------------------------------------------------
// IMAGE QUALITY
// ---------------------------------------------------------------------------

class QualityResult {
  final bool ok;
  final String message;
  const QualityResult(this.ok, this.message);
}

/// Thresholds copied from the backend (`check_image_quality`).
const double kBlurThreshold = 30;
const double kTooDark = 50;
const double kTooBright = 220;

/// The Laplacian variance depends on resolution, so very large photos are
/// scaled down first to keep this fast on phones. Raise it if you want the
/// blur test to behave more like the original full-resolution backend.
const int kQualityMaxSide = 1280;

QualityResult checkImageQuality(img.Image image) {
  var im = image;
  final longest = im.width > im.height ? im.width : im.height;
  if (longest > kQualityMaxSide) {
    final f = kQualityMaxSide / longest;
    im = img.copyResize(
      im,
      width: (im.width * f).round(),
      height: (im.height * f).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  final w = im.width, h = im.height;
  final gray = Uint8List(w * h);
  var sum = 0.0;
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      final g =
          (0.299 * p.r.toDouble() + 0.587 * p.g.toDouble() + 0.114 * p.b.toDouble())
              .round()
              .clamp(0, 255)
              .toInt();
      gray[i++] = g;
      sum += g;
    }
  }

  final blur = laplacianVariance(gray, w, h);
  final brightness = sum / (w * h);

  if (blur < kBlurThreshold) {
    return const QualityResult(false, 'Image is too blurry');
  }
  if (brightness < kTooDark) {
    return const QualityResult(false, 'Image is too dark');
  }
  if (brightness > kTooBright) {
    return const QualityResult(false, 'Image is overexposed');
  }
  return const QualityResult(true, 'Image quality is acceptable');
}

int _reflect101(int i, int n) {
  if (n == 1) return 0;
  if (i < 0) return -i;
  if (i >= n) return 2 * n - i - 2;
  return i;
}

/// Variance of the 4-neighbour Laplacian (same as
/// `cv2.Laplacian(gray, CV_64F).var()`).
double laplacianVariance(Uint8List gray, int w, int h) {
  var sum = 0.0, sumSq = 0.0;
  for (var y = 0; y < h; y++) {
    final up = _reflect101(y - 1, h) * w;
    final dn = _reflect101(y + 1, h) * w;
    final row = y * w;
    for (var x = 0; x < w; x++) {
      final l = _reflect101(x - 1, w);
      final r = _reflect101(x + 1, w);
      final v = (gray[up + x] +
              gray[dn + x] +
              gray[row + l] +
              gray[row + r] -
              4 * gray[row + x])
          .toDouble();
      sum += v;
      sumSq += v * v;
    }
  }
  final n = (w * h).toDouble();
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

// ---------------------------------------------------------------------------
// SEVERITY
// ---------------------------------------------------------------------------

class SeverityResult {
  final double percent;
  final String category;
  const SeverityResult(this.percent, this.category);
}

const int kSeveritySize = 224;

/// HSV colour-threshold estimate of the lesion area as a percentage of the
/// leaf area. Ported 1:1 from `estimate_severity` (OpenCV HSV scale:
/// H 0-179, S/V 0-255).
SeverityResult estimateSeverity(img.Image source) {
  // cv2.resize default = bilinear without anti-aliasing.
  final im = img.copyResize(
    source,
    width: kSeveritySize,
    height: kSeveritySize,
    interpolation: img.Interpolation.linear,
  );
  const w = kSeveritySize, h = kSeveritySize;

  final leaf = Uint8List(w * h);
  final lesion = Uint8List(w * h);

  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      final hsv = _rgbToHsvCv(p.r.toInt(), p.g.toInt(), p.b.toInt());
      final hh = hsv[0], ss = hsv[1], vv = hsv[2];
      if (hh >= 20 && hh <= 100 && ss >= 25 && vv >= 20 && vv <= 245) {
        leaf[i] = 255;
      }
      if (hh >= 5 && hh <= 30 && ss >= 40 && vv >= 20 && vv <= 180) {
        lesion[i] = 255;
      }
      i++;
    }
  }

  // leaf_mask = close(open(leaf_mask))
  var leafMask = _dilate(_erode(leaf, w, h), w, h); // open
  leafMask = _erode(_dilate(leafMask, w, h), w, h); // close

  // lesion_mask = open(lesion_mask AND leaf_mask)
  for (var k = 0; k < lesion.length; k++) {
    lesion[k] = (lesion[k] != 0 && leafMask[k] != 0) ? 255 : 0;
  }
  final lesionMask = _dilate(_erode(lesion, w, h), w, h);

  var leafArea = 0, lesionArea = 0;
  for (var k = 0; k < leafMask.length; k++) {
    if (leafMask[k] != 0) leafArea++;
    if (lesionMask[k] != 0) lesionArea++;
  }

  if (leafArea == 0) return const SeverityResult(0, 'Unknown');

  final severity = (lesionArea / leafArea * 100).clamp(0.0, 100.0).toDouble();
  final category = severity < 10
      ? 'Mild'
      : severity < 30
          ? 'Moderate'
          : 'Severe';
  return SeverityResult(severity, category);
}

/// RGB -> HSV using OpenCV's 8-bit convention.
List<int> _rgbToHsvCv(int r, int g, int b) {
  final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final delta = mx - mn;

  final v = mx;
  final s = mx == 0 ? 0 : (255.0 * delta / mx).round();

  double hue;
  if (delta == 0) {
    hue = 0;
  } else if (mx == r) {
    hue = 60.0 * (g - b) / delta;
  } else if (mx == g) {
    hue = 120.0 + 60.0 * (b - r) / delta;
  } else {
    hue = 240.0 + 60.0 * (r - g) / delta;
  }
  if (hue < 0) hue += 360;
  return [(hue / 2).round() % 180, s, v];
}

// 5x5 rectangular structuring element, border pixels ignored
// (equivalent to OpenCV's default morphology border handling).
Uint8List _erode(Uint8List src, int w, int h) => _morph(src, w, h, true);
Uint8List _dilate(Uint8List src, int w, int h) => _morph(src, w, h, false);

Uint8List _morph(Uint8List src, int w, int h, bool erode) {
  const r = 2;
  final tmp = Uint8List(w * h);
  final out = Uint8List(w * h);

  // horizontal pass
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var v = erode ? 255 : 0;
      final x0 = x - r < 0 ? 0 : x - r;
      final x1 = x + r >= w ? w - 1 : x + r;
      for (var xx = x0; xx <= x1; xx++) {
        final s = src[y * w + xx];
        if (erode ? s < v : s > v) v = s;
      }
      tmp[y * w + x] = v;
    }
  }
  // vertical pass
  for (var y = 0; y < h; y++) {
    final y0 = y - r < 0 ? 0 : y - r;
    final y1 = y + r >= h ? h - 1 : y + r;
    for (var x = 0; x < w; x++) {
      var v = erode ? 255 : 0;
      for (var yy = y0; yy <= y1; yy++) {
        final s = tmp[yy * w + x];
        if (erode ? s < v : s > v) v = s;
      }
      out[y * w + x] = v;
    }
  }
  return out;
}
