import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_models.dart';
import '../models/scan_doc.dart';
import '../utils/ids.dart';

class DocumentStore {
  DocumentStore._();
  static final DocumentStore instance = DocumentStore._();

  static const _docsKey = 'document_library_v2';
  static const _foldersKey = 'document_folders_v1';
  static const _legacyKey = 'scan_library_v1';

  Future<List<DocumentModel>> loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_docsKey);
    if (raw == null || raw.trim().isEmpty) {
      final migrated = await _tryMigrateLegacy(prefs);
      if (migrated.isNotEmpty) {
        await saveAllDocuments(migrated);
      }
      return migrated;
    }

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final docs = list.map((json) {
        final doc = DocumentModel.fromJson(json);
        final sortedPages = List<PageModel>.from(doc.pages)
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        return doc.copyWith(pages: sortedPages);
      }).toList();
      docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return docs;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAllDocuments(List<DocumentModel> docs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(docs.map((e) => e.toJson()).toList());
    await prefs.setString(_docsKey, encoded);
  }

  Future<void> addDocument(DocumentModel doc) async {
    final docs = await loadDocuments();
    final filtered = docs.where((d) => d.id != doc.id).toList();
    filtered.insert(0, doc);
    await saveAllDocuments(filtered);
  }

  Future<void> updateDocument(DocumentModel doc) async {
    final docs = await loadDocuments();
    final idx = docs.indexWhere((d) => d.id == doc.id);
    if (idx == -1) return;
    docs[idx] = doc;
    await saveAllDocuments(docs);
  }

  Future<void> removeDocument(String id) async {
    final docs = await loadDocuments();
    docs.removeWhere((d) => d.id == id);
    await saveAllDocuments(docs);
  }

  Future<List<FolderModel>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_foldersKey);
    if (raw == null || raw.trim().isEmpty) {
      final defaultFolders = [
        FolderModel(
          id: 'unsorted',
          name: 'Unsorted',
          createdAt: DateTime.now(),
          color: 0xFF6B7280,
        ),
      ];
      await saveFolders(defaultFolders);
      return defaultFolders;
    }

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final folders = list.map(FolderModel.fromJson).toList();
      return folders;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFolders(List<FolderModel> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(folders.map((e) => e.toJson()).toList());
    await prefs.setString(_foldersKey, encoded);
  }

  Future<void> addFolder(FolderModel folder) async {
    final folders = await loadFolders();
    final filtered = folders.where((f) => f.id != folder.id).toList();
    filtered.add(folder);
    await saveFolders(filtered);
  }

  Future<void> updateFolder(FolderModel folder) async {
    final folders = await loadFolders();
    final idx = folders.indexWhere((f) => f.id == folder.id);
    if (idx == -1) return;
    folders[idx] = folder;
    await saveFolders(folders);
  }

  Future<void> deleteFolder(String id) async {
    if (id == 'unsorted') return;
    final folders = await loadFolders();
    folders.removeWhere((f) => f.id == id);
    await saveFolders(folders);

    final docs = await loadDocuments();
    final updated = docs
        .map((d) => d.folderId == id ? d.copyWith(folderId: 'unsorted') : d)
        .toList();
    await saveAllDocuments(updated);
  }

  Future<List<DocumentModel>> _tryMigrateLegacy(SharedPreferences prefs) async {
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final docs = list.map(ScanDoc.fromJson).toList();
      final folders = await loadFolders();
      final unsorted = folders.firstWhere(
        (f) => f.id == 'unsorted',
        orElse: () => FolderModel(
          id: 'unsorted',
          name: 'Unsorted',
          createdAt: DateTime.now(),
          color: 0xFF6B7280,
        ),
      );
      if (!folders.any((f) => f.id == unsorted.id)) {
        folders.add(unsorted);
        await saveFolders(folders);
      }

      final List<DocumentModel> migrated = [];
      for (final legacy in docs) {
        final pages = await _loadLegacyPages(legacy.id);
        final now = DateTime.now();
        migrated.add(
          DocumentModel(
            id: legacy.id,
            title: legacy.title,
            createdAt: legacy.createdAt,
            updatedAt: now,
            folderId: unsorted.id,
            tags: [],
            pages: pages,
            metadata: {
              'legacyPdfPath': legacy.pdfPath,
              'thumbPath': legacy.thumbPath,
            },
            watermark: WatermarkSettings.defaults(),
            pageNumbers: PageNumberSettings.defaults(),
          ),
        );
      }

      return migrated;
    } catch (_) {
      return [];
    }
  }

  Future<List<PageModel>> _loadLegacyPages(String docId) async {
    final dir = await _scanDir(docId);
    if (!await dir.exists()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));

    final pages = <PageModel>[];
    for (var i = 0; i < files.length; i++) {
      pages.add(
        PageModel(
          id: newId(),
          documentId: docId,
          originalImagePath: files[i].path,
          editedImagePath: null,
          edits: PageEdits.empty(),
          orderIndex: i,
          annotations: [],
        ),
      );
    }
    return pages;
  }

  Future<Directory> _scanDir(String id) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/scans/$id');
  }
}
