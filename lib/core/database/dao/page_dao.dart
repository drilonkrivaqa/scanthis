import 'package:sqflite/sqflite.dart';

import '../db.dart';
import '../models.dart';

class PageDao {
  Future<void> insert(PageModel page) async {
    final db = await DocVaultDatabase.instance.database;
    await db.insert('pages', page.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertAll(List<PageModel> pages) async {
    final db = await DocVaultDatabase.instance.database;
    final batch = db.batch();
    for (final page in pages) {
      batch.insert('pages', page.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(PageModel page) async {
    final db = await DocVaultDatabase.instance.database;
    await db.update('pages', page.toMap(),
        where: 'id = ?', whereArgs: [page.id]);
  }

  Future<void> delete(String id) async {
    final db = await DocVaultDatabase.instance.database;
    await db.delete('pages', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PageModel>> listForDocument(String documentId) async {
    final db = await DocVaultDatabase.instance.database;
    final result = await db.query('pages',
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'page_index ASC');
    return result.map(PageModel.fromMap).toList();
  }

  Future<void> replacePages(String documentId, List<PageModel> pages) async {
    final db = await DocVaultDatabase.instance.database;
    final batch = db.batch();
    batch.delete('pages', where: 'document_id = ?', whereArgs: [documentId]);
    for (final page in pages) {
      batch.insert('pages', page.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
