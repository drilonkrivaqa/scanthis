import 'dart:ui';

class DocumentModel {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderId;
  final List<String> tags;
  final List<PageModel> pages;
  final Map<String, dynamic> metadata;
  final WatermarkSettings watermark;
  final PageNumberSettings pageNumbers;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.folderId,
    required this.tags,
    required this.pages,
    required this.metadata,
    required this.watermark,
    required this.pageNumbers,
  });

  DocumentModel copyWith({
    String? title,
    DateTime? updatedAt,
    String? folderId,
    List<String>? tags,
    List<PageModel>? pages,
    Map<String, dynamic>? metadata,
    WatermarkSettings? watermark,
    PageNumberSettings? pageNumbers,
  }) {
    return DocumentModel(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
      pages: pages ?? this.pages,
      metadata: metadata ?? this.metadata,
      watermark: watermark ?? this.watermark,
      pageNumbers: pageNumbers ?? this.pageNumbers,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'folderId': folderId,
    'tags': tags,
    'pages': pages.map((p) => p.toJson()).toList(),
    'metadata': metadata,
    'watermark': watermark.toJson(),
    'pageNumbers': pageNumbers.toJson(),
  };

  static DocumentModel fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Document').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
      folderId: json['folderId']?.toString(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      pages: (json['pages'] as List?)
          ?.map((e) => PageModel.fromJson((e as Map).cast<String, dynamic>()))
          .toList() ??
          [],
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      watermark: WatermarkSettings.fromJson(
        (json['watermark'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      pageNumbers: PageNumberSettings.fromJson(
        (json['pageNumbers'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }
}

class PageModel {
  final String id;
  final String documentId;
  final String originalImagePath;
  final String? editedImagePath;
  final PageEdits edits;
  final int orderIndex;
  final List<AnnotationItem> annotations;

  const PageModel({
    required this.id,
    required this.documentId,
    required this.originalImagePath,
    required this.editedImagePath,
    required this.edits,
    required this.orderIndex,
    required this.annotations,
  });

  PageModel copyWith({
    String? id,
    String? documentId,
    String? originalImagePath,
    String? editedImagePath,
    PageEdits? edits,
    int? orderIndex,
    List<AnnotationItem>? annotations,
  }) {
    return PageModel(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      editedImagePath: editedImagePath ?? this.editedImagePath,
      edits: edits ?? this.edits,
      orderIndex: orderIndex ?? this.orderIndex,
      annotations: annotations ?? this.annotations,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'originalImagePath': originalImagePath,
    'editedImagePath': editedImagePath,
    'edits': edits.toJson(),
    'orderIndex': orderIndex,
    'annotations': annotations.map((a) => a.toJson()).toList(),
  };

  static PageModel fromJson(Map<String, dynamic> json) {
    return PageModel(
      id: (json['id'] ?? '').toString(),
      documentId: (json['documentId'] ?? '').toString(),
      originalImagePath: (json['originalImagePath'] ?? '').toString(),
      editedImagePath: json['editedImagePath']?.toString(),
      edits: PageEdits.fromJson((json['edits'] as Map?)?.cast<String, dynamic>() ?? {}),
      orderIndex: int.tryParse((json['orderIndex'] ?? '0').toString()) ?? 0,
      annotations: (json['annotations'] as List?)
          ?.map((e) => AnnotationItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList() ??
          [],
    );
  }
}

class FolderModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final int? color;

  const FolderModel({
    required this.id,
    required this.name,
    required this.createdAt,
    this.color,
  });

  FolderModel copyWith({String? name, int? color}) {
    return FolderModel(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'color': color,
  };

  static FolderModel fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Folder').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      color: int.tryParse((json['color'] ?? '').toString()),
    );
  }
}

class PageEdits {
  final String preset;
  final double brightness;
  final double contrast;
  final double gamma;
  final double sharpen;
  final bool grayscale;
  final bool threshold;
  final double rotation;
  final double deskewAngle;

  const PageEdits({
    required this.preset,
    required this.brightness,
    required this.contrast,
    required this.gamma,
    required this.sharpen,
    required this.grayscale,
    required this.threshold,
    required this.rotation,
    required this.deskewAngle,
  });

  factory PageEdits.empty() {
    return const PageEdits(
      preset: 'Original',
      brightness: 0,
      contrast: 1,
      gamma: 1,
      sharpen: 0,
      grayscale: false,
      threshold: false,
      rotation: 0,
      deskewAngle: 0,
    );
  }

  PageEdits copyWith({
    String? preset,
    double? brightness,
    double? contrast,
    double? gamma,
    double? sharpen,
    bool? grayscale,
    bool? threshold,
    double? rotation,
    double? deskewAngle,
  }) {
    return PageEdits(
      preset: preset ?? this.preset,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      gamma: gamma ?? this.gamma,
      sharpen: sharpen ?? this.sharpen,
      grayscale: grayscale ?? this.grayscale,
      threshold: threshold ?? this.threshold,
      rotation: rotation ?? this.rotation,
      deskewAngle: deskewAngle ?? this.deskewAngle,
    );
  }

  Map<String, dynamic> toJson() => {
    'preset': preset,
    'brightness': brightness,
    'contrast': contrast,
    'gamma': gamma,
    'sharpen': sharpen,
    'grayscale': grayscale,
    'threshold': threshold,
    'rotation': rotation,
    'deskewAngle': deskewAngle,
  };

  static PageEdits fromJson(Map<String, dynamic> json) {
    return PageEdits(
      preset: (json['preset'] ?? 'Original').toString(),
      brightness: double.tryParse((json['brightness'] ?? '0').toString()) ?? 0,
      contrast: double.tryParse((json['contrast'] ?? '1').toString()) ?? 1,
      gamma: double.tryParse((json['gamma'] ?? '1').toString()) ?? 1,
      sharpen: double.tryParse((json['sharpen'] ?? '0').toString()) ?? 0,
      grayscale: json['grayscale'] == true,
      threshold: json['threshold'] == true,
      rotation: double.tryParse((json['rotation'] ?? '0').toString()) ?? 0,
      deskewAngle: double.tryParse((json['deskewAngle'] ?? '0').toString()) ?? 0,
    );
  }
}

enum AnnotationType {
  signaturePath,
  stampText,
  rectRedaction,
  watermarkText,
}

class AnnotationItem {
  final String id;
  final AnnotationType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double opacity;
  final double scale;
  final String? text;
  final int? color;
  final List<Offset> points;

  const AnnotationItem({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.opacity,
    required this.scale,
    required this.text,
    required this.color,
    required this.points,
  });

  AnnotationItem copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    double? scale,
    String? text,
    int? color,
    List<Offset>? points,
  }) {
    return AnnotationItem(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
      text: text ?? this.text,
      color: color ?? this.color,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'opacity': opacity,
    'scale': scale,
    'text': text,
    'color': color,
    'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
  };

  static AnnotationItem fromJson(Map<String, dynamic> json) {
    return AnnotationItem(
      id: (json['id'] ?? '').toString(),
      type: AnnotationType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'signaturePath').toString(),
        orElse: () => AnnotationType.signaturePath,
      ),
      x: double.tryParse((json['x'] ?? '0.1').toString()) ?? 0.1,
      y: double.tryParse((json['y'] ?? '0.1').toString()) ?? 0.1,
      width: double.tryParse((json['width'] ?? '0.4').toString()) ?? 0.4,
      height: double.tryParse((json['height'] ?? '0.2').toString()) ?? 0.2,
      rotation: double.tryParse((json['rotation'] ?? '0').toString()) ?? 0,
      opacity: double.tryParse((json['opacity'] ?? '1').toString()) ?? 1,
      scale: double.tryParse((json['scale'] ?? '1').toString()) ?? 1,
      text: json['text']?.toString(),
      color: int.tryParse((json['color'] ?? '').toString()),
      points: (json['points'] as List?)
          ?.map((p) => Offset(
        double.tryParse((p['dx'] ?? '0').toString()) ?? 0,
        double.tryParse((p['dy'] ?? '0').toString()) ?? 0,
      ))
          .toList() ??
          [],
    );
  }
}

class WatermarkSettings {
  final bool enabled;
  final String text;
  final double opacity;
  final double angle;

  const WatermarkSettings({
    required this.enabled,
    required this.text,
    required this.opacity,
    required this.angle,
  });

  factory WatermarkSettings.defaults() {
    return const WatermarkSettings(
      enabled: false,
      text: 'CONFIDENTIAL',
      opacity: 0.2,
      angle: -0.5,
    );
  }

  WatermarkSettings copyWith({
    bool? enabled,
    String? text,
    double? opacity,
    double? angle,
  }) {
    return WatermarkSettings(
      enabled: enabled ?? this.enabled,
      text: text ?? this.text,
      opacity: opacity ?? this.opacity,
      angle: angle ?? this.angle,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'text': text,
    'opacity': opacity,
    'angle': angle,
  };

  static WatermarkSettings fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return WatermarkSettings.defaults();
    }
    return WatermarkSettings(
      enabled: json['enabled'] == true,
      text: (json['text'] ?? 'CONFIDENTIAL').toString(),
      opacity: double.tryParse((json['opacity'] ?? '0.2').toString()) ?? 0.2,
      angle: double.tryParse((json['angle'] ?? '-0.5').toString()) ?? -0.5,
    );
  }
}

class PageNumberSettings {
  final bool enabled;
  final String format;

  const PageNumberSettings({
    required this.enabled,
    required this.format,
  });

  factory PageNumberSettings.defaults() {
    return const PageNumberSettings(
      enabled: false,
      format: 'Page {n} / {total}',
    );
  }

  PageNumberSettings copyWith({bool? enabled, String? format}) {
    return PageNumberSettings(
      enabled: enabled ?? this.enabled,
      format: format ?? this.format,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'format': format,
  };

  static PageNumberSettings fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return PageNumberSettings.defaults();
    }
    return PageNumberSettings(
      enabled: json['enabled'] == true,
      format: (json['format'] ?? 'Page {n} / {total}').toString(),
    );
  }
}

class ExportSettings {
  final String quality;

  const ExportSettings({required this.quality});

  factory ExportSettings.defaults() => const ExportSettings(quality: 'high');

  Map<String, dynamic> toJson() => {
    'quality': quality,
  };

  static ExportSettings fromJson(Map<String, dynamic> json) {
    return ExportSettings(quality: (json['quality'] ?? 'high').toString());
  }
}

Color? parseColor(int? value) {
  if (value == null) return null;
  return Color(value);
}
