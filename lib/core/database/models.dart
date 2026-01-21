class DocumentModel {
  DocumentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.isFavorite,
    required this.pageCount,
    this.folderId,
    this.pdfPath,
    this.thumbnailPath,
    this.ocrText,
    this.sizeBytes,
  });

  final String id;
  final String title;
  final String description;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final int pageCount;
  final String? pdfPath;
  final String? thumbnailPath;
  final String? ocrText;
  final int? sizeBytes;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'folder_id': folderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
      'page_count': pageCount,
      'pdf_path': pdfPath,
      'thumbnail_path': thumbnailPath,
      'ocr_text': ocrText,
      'size_bytes': sizeBytes,
    };
  }

  factory DocumentModel.fromMap(Map<String, Object?> map) {
    return DocumentModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      folderId: map['folder_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      pageCount: map['page_count'] as int? ?? 0,
      pdfPath: map['pdf_path'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      ocrText: map['ocr_text'] as String?,
      sizeBytes: map['size_bytes'] as int?,
    );
  }
}

class FolderModel {
  FolderModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FolderModel.fromMap(Map<String, Object?> map) {
    return FolderModel(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class PageModel {
  PageModel({
    required this.id,
    required this.documentId,
    required this.index,
    required this.imagePath,
    this.ocrText,
  });

  final String id;
  final String documentId;
  final int index;
  final String imagePath;
  final String? ocrText;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page_index': index,
      'image_path': imagePath,
      'ocr_text': ocrText,
    };
  }

  factory PageModel.fromMap(Map<String, Object?> map) {
    return PageModel(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      index: map['page_index'] as int? ?? 0,
      imagePath: map['image_path'] as String,
      ocrText: map['ocr_text'] as String?,
    );
  }
}

class TagModel {
  TagModel({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toMap() {
    return {'id': id, 'name': name};
  }

  factory TagModel.fromMap(Map<String, Object?> map) {
    return TagModel(id: map['id'] as String, name: map['name'] as String);
  }
}
