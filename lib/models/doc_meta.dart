import 'annotations.dart';

/// Stored alongside scan files under each doc directory as `meta.json`.
class DocMeta {
  final String preset; // 'original','document','receipt','whiteboard','bw'
  final Map<String, PageAnnotations> pageAnnotationsByName; // key: page filename (page_001.jpg)

  const DocMeta({
    this.preset = 'original',
    this.pageAnnotationsByName = const {},
  });

  Map<String, dynamic> toJson() => {
        'preset': preset,
        'pageAnnotations': pageAnnotationsByName.map((k, v) => MapEntry(k, v.toJson())),
      };

  static DocMeta fromJson(Map<String, dynamic> json) {
    final preset = (json['preset'] ?? 'original').toString();
    final raw = json['pageAnnotations'];
    final map = <String, PageAnnotations>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is Map) {
          map[k] = PageAnnotations.fromJson(v.cast<String, dynamic>());
        }
      });
    }
    return DocMeta(preset: preset, pageAnnotationsByName: map);
  }

  PageAnnotations forPageName(String pageName) =>
      pageAnnotationsByName[pageName] ?? const PageAnnotations();

  DocMeta setAnnotationsForPage(String pageName, PageAnnotations ann) {
    final next = Map<String, PageAnnotations>.from(pageAnnotationsByName);
    next[pageName] = ann;
    return DocMeta(preset: preset, pageAnnotationsByName: next);
  }

  DocMeta copyWith({String? preset, Map<String, PageAnnotations>? pageAnnotationsByName}) => DocMeta(
        preset: preset ?? this.preset,
        pageAnnotationsByName: pageAnnotationsByName ?? this.pageAnnotationsByName,
      );
}
