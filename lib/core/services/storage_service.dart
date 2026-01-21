import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

class StorageService {
  Future<Directory> getAppDocumentsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory(path.join(dir.path, AppConstants.documentsDir));
  }

  Future<Directory> getThumbnailDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory(path.join(dir.path, AppConstants.thumbnailsDir));
  }

  Future<Directory> getCacheDir() async {
    final dir = await getTemporaryDirectory();
    return Directory(path.join(dir.path, AppConstants.cacheDir));
  }

  Future<Directory> ensureDir(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> ensureDocumentDir(String documentId) async {
    final base = await ensureDir(await getAppDocumentsDir());
    final docDir = Directory(path.join(base.path, documentId));
    return ensureDir(docDir);
  }

  Future<File> buildPagePath(String documentId, int index) async {
    final docDir = await ensureDocumentDir(documentId);
    final fileName = 'page_${index.toString().padLeft(3, '0')}.jpg';
    return File(path.join(docDir.path, 'pages', fileName));
  }

  Future<Directory> ensurePagesDir(String documentId) async {
    final docDir = await ensureDocumentDir(documentId);
    final pagesDir = Directory(path.join(docDir.path, 'pages'));
    return ensureDir(pagesDir);
  }

  Future<File> buildPdfPath(String documentId, String title) async {
    final docDir = await ensureDocumentDir(documentId);
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File(path.join(docDir.path, '$safeTitle.pdf'));
  }

  Future<File> buildThumbnailPath(String documentId) async {
    final thumbDir = await ensureDir(await getThumbnailDir());
    return File(path.join(thumbDir.path, '$documentId.jpg'));
  }

  Future<int> getStorageSize() async {
    final base = await getAppDocumentsDir();
    if (!await base.exists()) return 0;
    var total = 0;
    final entities = base.list(recursive: true, followLinks: false);
    await for (final entity in entities) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> clearCache() async {
    final cacheDir = await getCacheDir();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
    await cacheDir.create(recursive: true);
  }
}
