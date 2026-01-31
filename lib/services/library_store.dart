import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_doc.dart';
import '../models/folder.dart';

class LibraryStore {
  LibraryStore._();
  static final LibraryStore instance = LibraryStore._();

  static const _docsKeyV2 = 'scan_library_v2';
  static const _docsKeyV1 = 'scan_library_v1';
  static const _foldersKey = 'scan_folders_v1';

  static const unsortedFolder = Folder(id: 'unsorted', name: 'Unsorted');

  Future<List<ScanDoc>> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Prefer v2. If missing, migrate from v1.
    final rawV2 = prefs.getString(_docsKeyV2);
    if (rawV2 != null && rawV2.trim().isNotEmpty) {
      return _decodeDocs(rawV2);
    }

    final rawV1 = prefs.getString(_docsKeyV1);
    if (rawV1 != null && rawV1.trim().isNotEmpty) {
      final v1docs = _decodeDocs(rawV1);
      // Save as v2 (same doc model now supports folder/tags, default null/[]).
      await saveAll(v1docs);
      return v1docs;
    }

    return [];
  }

  List<ScanDoc> _decodeDocs(String raw) {
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final docs = list.map(ScanDoc.fromJson).toList();
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<ScanDoc> docs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(docs.map((e) => e.toJson()).toList());
    await prefs.setString(_docsKeyV2, encoded);
  }

  Future<void> add(ScanDoc doc) async {
    final docs = await load();
    final filtered = docs.where((d) => d.id != doc.id).toList();
    filtered.insert(0, doc);
    await saveAll(filtered);
  }

  Future<void> update(ScanDoc doc) async {
    final docs = await load();
    final updated = docs.map((d) => d.id == doc.id ? doc : d).toList();
    await saveAll(updated);
  }

  Future<void> removeById(String id) async {
    final docs = await load();
    final updated = docs.where((d) => d.id != id).toList();
    await saveAll(updated);
  }

  // -------- folders ----------------------------------------------------------

  Future<List<Folder>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_foldersKey);
    if (raw == null || raw.trim().isEmpty) return [unsortedFolder];

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final folders = list.map(Folder.fromJson).toList();
      // Ensure unsorted exists
      final hasUnsorted = folders.any((f) => f.id == unsortedFolder.id);
      final out = <Folder>[
        if (!hasUnsorted) unsortedFolder,
        ...folders.where((f) => f.id != unsortedFolder.id),
      ];
      return out;
    } catch (_) {
      return [unsortedFolder];
    }
  }

  Future<void> saveFolders(List<Folder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = <Folder>[
      unsortedFolder,
      ...folders.where((f) => f.id != unsortedFolder.id),
    ];
    await prefs.setString(
      _foldersKey,
      jsonEncode(normalized.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addFolder(Folder folder) async {
    final folders = await loadFolders();
    final filtered = folders.where((f) => f.id != folder.id).toList();
    filtered.add(folder);
    await saveFolders(filtered);
  }

  Future<void> renameFolder(String folderId, String newName) async {
    final folders = await loadFolders();
    final updated = folders.map((f) {
      if (f.id == folderId) return f.copyWith(name: newName);
      return f;
    }).toList();
    await saveFolders(updated);
  }

  Future<void> deleteFolder(String folderId) async {
    if (folderId == unsortedFolder.id) return;

    // Move docs to unsorted
    final docs = await load();
    final migrated = docs.map((d) {
      if (d.folderId == folderId) return d.copyWith(folderId: null);
      return d;
    }).toList();
    await saveAll(migrated);

    final folders = await loadFolders();
    final updatedFolders = folders.where((f) => f.id != folderId).toList();
    await saveFolders(updatedFolders);
  }
}
