import 'package:image/image.dart' as img;

enum EnhancePreset { original, document, receipt, whiteboard, bw }

String presetName(EnhancePreset p) => switch (p) {
      EnhancePreset.original => 'Original',
      EnhancePreset.document => 'Document',
      EnhancePreset.receipt => 'Receipt',
      EnhancePreset.whiteboard => 'Whiteboard',
      EnhancePreset.bw => 'B/W',
    };

String presetKey(EnhancePreset p) => switch (p) {
      EnhancePreset.original => 'original',
      EnhancePreset.document => 'document',
      EnhancePreset.receipt => 'receipt',
      EnhancePreset.whiteboard => 'whiteboard',
      EnhancePreset.bw => 'bw',
    };

EnhancePreset presetFromKey(String key) => switch (key) {
      'document' => EnhancePreset.document,
      'receipt' => EnhancePreset.receipt,
      'whiteboard' => EnhancePreset.whiteboard,
      'bw' => EnhancePreset.bw,
      _ => EnhancePreset.original,
    };

img.Image _threshold(img.Image src, int threshold) {
  final out = img.Image.from(src);
  for (var y = 0; y < out.height; y++) {
    for (var x = 0; x < out.width; x++) {
      final p = out.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b).round();
      final v = lum >= threshold ? 255 : 0;
      out.setPixelRgba(x, y, v, v, v, p.a.toInt());
    }
  }
  return out;
}

/// Applies lightweight, offline enhancement presets.
/// Uses only stable `package:image` operations.
img.Image applyPreset(img.Image input, EnhancePreset preset) {
  if (preset == EnhancePreset.original) return input;

  var out = img.Image.from(input);

  switch (preset) {
    case EnhancePreset.document:
      out = img.adjustColor(out, contrast: 1.20, brightness: 0.02);
      // light blur can reduce grain
      out = img.gaussianBlur(out, radius: 1);
      return out;

    case EnhancePreset.receipt:
      out = img.grayscale(out);
      out = img.adjustColor(out, contrast: 1.35, brightness: 0.03);
      out = _threshold(out, 160);
      return out;

    case EnhancePreset.whiteboard:
      out = img.adjustColor(out, contrast: 1.25, brightness: 0.07);
      out = img.gaussianBlur(out, radius: 1);
      return out;

    case EnhancePreset.bw:
      out = img.grayscale(out);
      out = _threshold(out, 150);
      return out;

    case EnhancePreset.original:
      return input;
  }
}
