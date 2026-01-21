import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_doc.dart';

class LibraryStore {
  LibraryStore._();
  static final LibraryStore instance = LibraryStore._();

  static const _key = 'scan_library_v1';

  Future<List<ScanDoc>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];

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
    await prefs.setString(_key, encoded);
  }

  Future<void> add(ScanDoc doc) async {
    final docs = await load();
    final filtered = docs.where((d) => d.id != doc.id).toList();
    filtered.insert(0, doc);
    await saveAll(filtered);
  }

  Future<void> update(ScanDoc doc) async {
    final docs = await load();
    final idx = docs.indexWhere((d) => d.id == doc.id);
    if (idx == -1) return;
    docs[idx] = doc;
    await saveAll(docs);
  }

  Future<void> removeById(String id) async {
    final docs = await load();
    docs.removeWhere((d) => d.id == id);
    await saveAll(docs);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
