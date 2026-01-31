class ScanDoc {
  final String id;
  final String title;
  final DateTime createdAt;
  final int pageCount;
  final String pdfPath;
  final String thumbPath;

  /// Optional folder id (null means "Unsorted").
  final String? folderId;

  /// User-defined tags for organization and filtering.
  final List<String> tags;

  const ScanDoc({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.pageCount,
    required this.pdfPath,
    required this.thumbPath,
    this.folderId,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'pageCount': pageCount,
        'pdfPath': pdfPath,
        'thumbPath': thumbPath,
        'folderId': folderId,
        'tags': tags,
      };

  static ScanDoc fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final parsedTags = <String>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        final s = (t ?? '').toString().trim();
        if (s.isNotEmpty) parsedTags.add(s);
      }
    }
    return ScanDoc(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Scan').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      pageCount: int.tryParse((json['pageCount'] ?? '0').toString()) ?? 0,
      pdfPath: (json['pdfPath'] ?? '').toString(),
      thumbPath: (json['thumbPath'] ?? '').toString(),
      folderId: (json['folderId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['folderId'] ?? '').toString(),
      tags: parsedTags,
    );
  }

  ScanDoc copyWith({
    String? title,
    String? folderId,
    List<String>? tags,
  }) =>
      ScanDoc(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        pageCount: pageCount,
        pdfPath: pdfPath,
        thumbPath: thumbPath,
        folderId: folderId ?? this.folderId,
        tags: tags ?? this.tags,
      );
}
