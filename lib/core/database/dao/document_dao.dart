import 'package:sqflite/sqflite.dart';

import '../db.dart';
import '../models.dart';

class DocumentDao {
  Future<void> insert(DocumentModel document) async {
    final db = await DocVaultDatabase.instance.database;
    await db.insert('documents', document.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(DocumentModel document) async {
    final db = await DocVaultDatabase.instance.database;
    await db.update('documents', document.toMap(),
        where: 'id = ?', whereArgs: [document.id]);
  }

  Future<void> delete(String id) async {
    final db = await DocVaultDatabase.instance.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DocumentModel>> list({
    String? searchQuery,
    String? folderId,
    String? tagId,
    String sort = 'updated_at DESC',
  }) async {
    final db = await DocVaultDatabase.instance.database;
    final where = <String>[];
    final args = <Object?>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(title LIKE ? OR description LIKE ? OR ocr_text LIKE ?)');
      final query = '%$searchQuery%';
      args.addAll([query, query, query]);
    }

    if (folderId != null && folderId.isNotEmpty) {
      where.add('folder_id = ?');
      args.add(folderId);
    }

    if (tagId != null && tagId.isNotEmpty) {
      where.add('id IN (SELECT document_id FROM document_tags WHERE tag_id = ?)');
      args.add(tagId);
    }

    final whereClause = where.isEmpty ? null : where.join(' AND ');
    final result = await db.query('documents',
        where: whereClause, whereArgs: args, orderBy: sort);
    return result.map(DocumentModel.fromMap).toList();
  }

  Future<DocumentModel?> getById(String id) async {
    final db = await DocVaultDatabase.instance.database;
    final result =
        await db.query('documents', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return DocumentModel.fromMap(result.first);
  }

  Future<int> countDocuments() async {
    final db = await DocVaultDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM documents');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
