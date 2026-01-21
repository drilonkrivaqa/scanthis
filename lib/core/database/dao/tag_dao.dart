import 'package:sqflite/sqflite.dart';

import '../db.dart';
import '../models.dart';

class TagDao {
  Future<void> insert(TagModel tag) async {
    final db = await DocVaultDatabase.instance.database;
    await db.insert('tags', tag.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TagModel>> list() async {
    final db = await DocVaultDatabase.instance.database;
    final result = await db.query('tags', orderBy: 'name ASC');
    return result.map(TagModel.fromMap).toList();
  }

  Future<void> linkTag(String documentId, String tagId) async {
    final db = await DocVaultDatabase.instance.database;
    await db.insert('document_tags',
        {'document_id': documentId, 'tag_id': tagId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> unlinkTag(String documentId, String tagId) async {
    final db = await DocVaultDatabase.instance.database;
    await db.delete('document_tags',
        where: 'document_id = ? AND tag_id = ?',
        whereArgs: [documentId, tagId]);
  }

  Future<List<TagModel>> listForDocument(String documentId) async {
    final db = await DocVaultDatabase.instance.database;
    final result = await db.rawQuery('''
      SELECT tags.id, tags.name
      FROM tags
      INNER JOIN document_tags ON tags.id = document_tags.tag_id
      WHERE document_tags.document_id = ?
      ORDER BY tags.name ASC
    ''', [documentId]);
    return result.map(TagModel.fromMap).toList();
  }
}
