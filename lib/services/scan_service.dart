import 'dart:io';

import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../models/document_models.dart';
import '../utils/ids.dart';

class ScanService {
  ScanService._();
  static final ScanService instance = ScanService._();

  /// Starts the native document scanner UI flow (auto edge detect, crop, filters),
  /// returns a saved DocumentModel or null if canceled.
  Future<DocumentModel?> scanToDocument({int pageLimit = 50}) async {
    final options = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.full,
      pageLimit: pageLimit,
      isGalleryImport: true,
    );

    final scanner = DocumentScanner(options: options);

    try {
      final result = await scanner.scanDocument();
      final images = result.images;

      if (images.isEmpty) return null;

      final id = newId();
      final baseDir = await _scanDir(id);
      await baseDir.create(recursive: true);

      final List<String> pagePaths = [];
      for (var i = 0; i < images.length; i++) {
        final srcPath = images[i];
        final src = File(srcPath);

        final dst = File('${baseDir.path}/page_${(i + 1).toString().padLeft(3, '0')}.jpg');
        await src.copy(dst.path);
        pagePaths.add(dst.path);
      }

      final pages = <PageModel>[];
      for (var i = 0; i < pagePaths.length; i++) {
        pages.add(
          PageModel(
            id: newId(),
            documentId: id,
            originalImagePath: pagePaths[i],
            editedImagePath: null,
            edits: PageEdits.empty(),
            orderIndex: i,
            annotations: const [],
          ),
        );
      }

      return DocumentModel(
        id: id,
        title: 'Scan ${DateTime.now().toLocal().toIso8601String().substring(0, 10)}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        folderId: 'unsorted',
        tags: const [],
        pages: pages,
        metadata: const {},
        watermark: WatermarkSettings.defaults(),
        pageNumbers: PageNumberSettings.defaults(),
      );
    } finally {
      await scanner.close();
    }
  }

  Future<void> deleteDocFiles(String id) async {
    final dir = await _scanDir(id);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<Directory> ensureScanDir(String id) async {
    final dir = await _scanDir(id);
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _scanDir(String id) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/scans/$id');
  }
}
