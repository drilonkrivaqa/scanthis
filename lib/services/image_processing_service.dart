import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/document_models.dart';

class ImageProcessingService {
  ImageProcessingService._();
  static final ImageProcessingService instance = ImageProcessingService._();

  PageEdits presetFor(String preset) {
    switch (preset) {
      case 'Document':
        return const PageEdits(
          preset: 'Document',
          brightness: 0.05,
          contrast: 1.2,
          gamma: 1.05,
          sharpen: 0.6,
          grayscale: false,
          threshold: false,
          rotation: 0,
          deskewAngle: 0,
        );
      case 'Receipt':
        return const PageEdits(
          preset: 'Receipt',
          brightness: 0.1,
          contrast: 1.35,
          gamma: 1.1,
          sharpen: 0.4,
          grayscale: true,
          threshold: true,
          rotation: 0,
          deskewAngle: 0,
        );
      case 'Whiteboard':
        return const PageEdits(
          preset: 'Whiteboard',
          brightness: 0.2,
          contrast: 1.1,
          gamma: 1.0,
          sharpen: 0.3,
          grayscale: false,
          threshold: false,
          rotation: 0,
          deskewAngle: 0,
        );
      case 'B/W':
        return const PageEdits(
          preset: 'B/W',
          brightness: 0.1,
          contrast: 1.4,
          gamma: 1.0,
          sharpen: 0.6,
          grayscale: true,
          threshold: true,
          rotation: 0,
          deskewAngle: 0,
        );
      default:
        return PageEdits.empty();
    }
  }

  Future<Uint8List> applyEdits({
    required Uint8List bytes,
    required PageEdits edits,
    String quality = 'high',
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    img.Image image = img.bakeOrientation(decoded);

    if (edits.rotation != 0 || edits.deskewAngle != 0) {
      final angle = edits.rotation + edits.deskewAngle;
      image = img.copyRotate(image, angle: angle * 180 / pi);
    }

    if (edits.grayscale) {
      image = img.grayscale(image);
    }

    if (edits.brightness != 0 || edits.contrast != 1) {
      image = img.adjustColor(
        image,
        brightness: (edits.brightness * 100).round(),
        contrast: (edits.contrast * 100).round(),
      );
    }

    if (edits.gamma != 1) {
      image = img.gamma(image, gamma: edits.gamma);
    }

    if (edits.sharpen > 0) {
      final strength = (edits.sharpen * 10).clamp(0, 10).round();
      image = img.convolution(
        image,
        filter: [
          0, -1, 0,
          -1, 4 + strength, -1,
          0, -1, 0,
        ],
        div: 1,
        offset: 0,
      );
    }

    if (edits.threshold) {
      image = img.threshold(image, threshold: 140);
    }

    final qualityValue = switch (quality) {
      'small' => 55,
      'medium' => 75,
      _ => 95,
    };

    return Uint8List.fromList(img.encodeJpg(image, quality: qualityValue));
  }

  Future<Uint8List> applyAnnotations({
    required Uint8List bytes,
    required List<AnnotationItem> annotations,
    WatermarkSettings? watermark,
    PageNumberSettings? pageNumbers,
    int pageIndex = 1,
    int totalPages = 1,
    String quality = 'high',
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    img.Image image = decoded;

    for (final annotation in annotations) {
      switch (annotation.type) {
        case AnnotationType.rectRedaction:
          _drawRedaction(image, annotation);
          break;
        case AnnotationType.signaturePath:
          _drawSignature(image, annotation);
          break;
        case AnnotationType.stampText:
          _drawStamp(image, annotation);
          break;
        case AnnotationType.watermarkText:
          _drawStamp(image, annotation);
          break;
      }
    }

    if (watermark != null && watermark.enabled) {
      _drawWatermark(image, watermark);
    }

    if (pageNumbers != null && pageNumbers.enabled) {
      _drawPageNumber(image, pageNumbers, pageIndex, totalPages);
    }

    final qualityValue = switch (quality) {
      'small' => 55,
      'medium' => 75,
      _ => 95,
    };

    return Uint8List.fromList(img.encodeJpg(image, quality: qualityValue));
  }

  void _drawRedaction(img.Image image, AnnotationItem annotation) {
    final rect = _annotationRect(image, annotation);
    img.fillRect(
      image,
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
      color: img.ColorRgb8(0, 0, 0),
    );
  }

  void _drawSignature(img.Image image, AnnotationItem annotation) {
    if (annotation.points.length < 2) return;
    final rect = _annotationRect(image, annotation);
    for (var i = 0; i < annotation.points.length - 1; i++) {
      final p1 = annotation.points[i];
      final p2 = annotation.points[i + 1];
      final x1 = rect.left + (p1.dx * rect.width).round();
      final y1 = rect.top + (p1.dy * rect.height).round();
      final x2 = rect.left + (p2.dx * rect.width).round();
      final y2 = rect.top + (p2.dy * rect.height).round();
      img.drawLine(
        image,
        x1,
        y1,
        x2,
        y2,
        color: img.ColorRgb8(20, 20, 20),
        thickness: 2,
      );
    }
  }

  void _drawStamp(img.Image image, AnnotationItem annotation) {
    final rect = _annotationRect(image, annotation);
    final stampText = annotation.text ?? '';
    if (stampText.trim().isEmpty) return;

    final colorValue = annotation.color ?? 0xFFE11D48;
    final rgb = _colorToRgb(colorValue, annotation.opacity);

    img.drawRect(
      image,
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
      color: img.ColorRgb8(rgb.r, rgb.g, rgb.b),
      thickness: 2,
    );
    img.drawString(
      image,
      stampText.toUpperCase(),
      font: img.arial_24,
      x: rect.left + 8,
      y: rect.top + 8,
      color: img.ColorRgb8(rgb.r, rgb.g, rgb.b),
    );
  }

  void _drawWatermark(img.Image image, WatermarkSettings watermark) {
    final text = watermark.text.trim();
    if (text.isEmpty) return;

    final overlay = img.Image(width: image.width, height: image.height);
    final color = _colorToRgb(0xFF94A3B8, watermark.opacity);

    img.drawString(
      overlay,
      text,
      font: img.arial_48,
      x: (image.width * 0.15).round(),
      y: (image.height * 0.45).round(),
      color: img.ColorRgb8(color.r, color.g, color.b),
    );

    final rotated = watermark.angle == 0
        ? overlay
        : img.copyRotate(overlay, angle: watermark.angle * 180 / pi);

    img.compositeImage(image, rotated);
  }

  void _drawPageNumber(
    img.Image image,
    PageNumberSettings settings,
    int index,
    int total,
  ) {
    final label = settings.format
        .replaceAll('{n}', index.toString())
        .replaceAll('{total}', total.toString());
    img.drawString(
      image,
      label,
      font: img.arial_24,
      x: (image.width * 0.75).round(),
      y: (image.height * 0.93).round(),
      color: img.ColorRgb8(55, 65, 81),
    );
  }

  _Rgb _colorToRgb(int color, double opacity) {
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    final alpha = opacity.clamp(0.0, 1.0);
    return _Rgb(
      r: (r * alpha + 255 * (1 - alpha)).round(),
      g: (g * alpha + 255 * (1 - alpha)).round(),
      b: (b * alpha + 255 * (1 - alpha)).round(),
    );
  }

  _Rect _annotationRect(img.Image image, AnnotationItem annotation) {
    final left = (annotation.x * image.width).round();
    final top = (annotation.y * image.height).round();
    final width = (annotation.width * image.width).round();
    final height = (annotation.height * image.height).round();
    return _Rect(
      left: left,
      top: top,
      right: left + width,
      bottom: top + height,
      width: width,
      height: height,
    );
  }

  double estimateDeskewAngle(Uint8List bytes) {
    // TODO: Add lightweight skew estimation when available.
    // Hook method kept for future deskew improvements.
    return 0;
  }
}

class _Rgb {
  final int r;
  final int g;
  final int b;

  const _Rgb({required this.r, required this.g, required this.b});
}

class _Rect {
  final int left;
  final int top;
  final int right;
  final int bottom;
  final int width;
  final int height;

  const _Rect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.width,
    required this.height,
  });
}
