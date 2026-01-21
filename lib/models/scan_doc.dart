class ScanDoc {
  final String id;
  final String title;
  final DateTime createdAt;
  final int pageCount;
  final String pdfPath;
  final String thumbPath;

  const ScanDoc({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.pageCount,
    required this.pdfPath,
    required this.thumbPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'pageCount': pageCount,
    'pdfPath': pdfPath,
    'thumbPath': thumbPath,
  };

  static ScanDoc fromJson(Map<String, dynamic> json) {
    return ScanDoc(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Scan').toString(),
      createdAt:
      DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      pageCount: int.tryParse((json['pageCount'] ?? '0').toString()) ?? 0,
      pdfPath: (json['pdfPath'] ?? '').toString(),
      thumbPath: (json['thumbPath'] ?? '').toString(),
    );
  }

  ScanDoc copyWith({String? title}) => ScanDoc(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    pageCount: pageCount,
    pdfPath: pdfPath,
    thumbPath: thumbPath,
  );
}
