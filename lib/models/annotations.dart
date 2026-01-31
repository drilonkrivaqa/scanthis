import 'dart:ui';

/// Normalized rect (0..1) in image coordinates.
class RedactionRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const RedactionRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  Rect toRect(Size size) => Rect.fromLTRB(
        left * size.width,
        top * size.height,
        right * size.width,
        bottom * size.height,
      );

  Map<String, dynamic> toJson() => {
        'l': left,
        't': top,
        'r': right,
        'b': bottom,
      };

  static RedactionRect fromJson(Map<String, dynamic> json) => RedactionRect(
        left: (json['l'] as num?)?.toDouble() ?? 0,
        top: (json['t'] as num?)?.toDouble() ?? 0,
        right: (json['r'] as num?)?.toDouble() ?? 0,
        bottom: (json['b'] as num?)?.toDouble() ?? 0,
      );
}

class Stamp {
  final String text;
  final double x; // normalized center x
  final double y; // normalized center y
  final double scale; // relative scale

  const Stamp({
    required this.text,
    required this.x,
    required this.y,
    this.scale = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'x': x,
        'y': y,
        'scale': scale,
      };

  static Stamp fromJson(Map<String, dynamic> json) => Stamp(
        text: (json['text'] ?? '').toString(),
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        y: (json['y'] as num?)?.toDouble() ?? 0.5,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      );
}

class SignatureOverlay {
  /// path to a PNG stored under the doc folder (e.g. signatures/sig_001.png)
  final String filePath;
  final double x;
  final double y;
  final double scale;

  const SignatureOverlay({
    required this.filePath,
    required this.x,
    required this.y,
    this.scale = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'x': x,
        'y': y,
        'scale': scale,
      };

  static SignatureOverlay fromJson(Map<String, dynamic> json) => SignatureOverlay(
        filePath: (json['filePath'] ?? '').toString(),
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        y: (json['y'] as num?)?.toDouble() ?? 0.5,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      );
}

/// Per-page annotation set.
class PageAnnotations {
  final List<RedactionRect> redactions;
  final List<Stamp> stamps;
  final List<SignatureOverlay> signatures;

  const PageAnnotations({
    this.redactions = const [],
    this.stamps = const [],
    this.signatures = const [],
  });

  Map<String, dynamic> toJson() => {
        'redactions': redactions.map((e) => e.toJson()).toList(),
        'stamps': stamps.map((e) => e.toJson()).toList(),
        'signatures': signatures.map((e) => e.toJson()).toList(),
      };

  static PageAnnotations fromJson(Map<String, dynamic> json) {
    List<T> _list<T>(String key, T Function(Map<String, dynamic>) f) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => f(e.cast<String, dynamic>()))
            .toList();
      }
      return <T>[];
    }

    return PageAnnotations(
      redactions: _list('redactions', RedactionRect.fromJson),
      stamps: _list('stamps', Stamp.fromJson),
      signatures: _list('signatures', SignatureOverlay.fromJson),
    );
  }

  PageAnnotations copyWith({
    List<RedactionRect>? redactions,
    List<Stamp>? stamps,
    List<SignatureOverlay>? signatures,
  }) =>
      PageAnnotations(
        redactions: redactions ?? this.redactions,
        stamps: stamps ?? this.stamps,
        signatures: signatures ?? this.signatures,
      );
}
