import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app/services/image_analysis.dart';

void main() {
  test('severity: all-green leaf has ~0% lesion area', () {
    final im = img.Image(width: 300, height: 300);
    img.fill(im, color: img.ColorRgb8(60, 140, 50));
    final r = estimateSeverity(im);
    expect(r.percent, lessThan(1));
    expect(r.category, 'Mild');
  });

  test('severity: brown patch is detected inside the leaf', () {
    final im = img.Image(width: 300, height: 300);
    img.fill(im, color: img.ColorRgb8(60, 140, 50));
    img.fillRect(im,
        x1: 100, y1: 100, x2: 200, y2: 200, color: img.ColorRgb8(150, 120, 40));
    final r = estimateSeverity(im);
    expect(r.percent, greaterThan(5));
  });

  test('quality: flat image is rejected as blurry', () {
    final im = img.Image(width: 200, height: 200);
    img.fill(im, color: img.ColorRgb8(120, 120, 120));
    expect(checkImageQuality(im).ok, isFalse);
  });

  test('laplacian variance of a constant image is zero', () {
    expect(laplacianVariance(Uint8List.fromList(List.filled(100, 7)), 10, 10), 0);
  });
}
