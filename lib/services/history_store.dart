import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_entry.dart';

class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  static const _key = 'scan_history_v1';

  Future<List<ScanEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final items = list.map(ScanEntry.fromJson).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<ScanEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  Future<void> add(ScanEntry entry) async {
    final items = await load();

    // de-dupe by value (keep newest)
    final filtered = items.where((e) => e.value != entry.value).toList();
    filtered.insert(0, entry);

    // keep last 200
    if (filtered.length > 200) {
      filtered.removeRange(200, filtered.length);
    }

    await saveAll(filtered);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> removeAt(DateTime createdAt) async {
    final items = await load();
    items.removeWhere((e) => e.createdAt == createdAt);
    await saveAll(items);
  }
}
