import 'dart:io';

import 'package:image/image.dart' as img;

class ImageProcessingService {
  Future<img.Image?> loadImage(File file) async {
    final bytes = await file.readAsBytes();
    return img.decodeImage(bytes);
  }

  Future<File> saveImage(img.Image image, File target,
      {int quality = 90}) async {
    final bytes = img.encodeJpg(image, quality: quality);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  img.Image applyRotate(img.Image image, int quarterTurns) {
    if (quarterTurns % 4 == 0) return image;
    return img.copyRotate(image, angle: 90 * quarterTurns);
  }

  img.Image applyBrightnessContrast(img.Image image,
      {double brightness = 0, double contrast = 1}) {
    final adjusted = img.adjustColor(image,
        brightness: brightness, contrast: contrast);
    return adjusted;
  }

  img.Image crop(img.Image image, int x, int y, int width, int height) {
    return img.copyCrop(image, x: x, y: y, width: width, height: height);
  }

  img.Image resize(img.Image image, {int width = 400}) {
    return img.copyResize(image, width: width);
  }

  img.Image toGrayscale(img.Image image) {
    return img.grayscale(image);
  }

  /// Naive auto-crop: detect non-white bounding box.
  img.Image autoCrop(img.Image image) {
    final width = image.width;
    final height = image.height;
    int left = width, right = 0, top = height, bottom = 0;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final isWhite = r > 240 && g > 240 && b > 240;
        if (!isWhite) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }

    if (left >= right || top >= bottom) {
      return image;
    }

    final cropWidth = right - left;
    final cropHeight = bottom - top;
    return img.copyCrop(image,
        x: left, y: top, width: cropWidth, height: cropHeight);
  }
}
