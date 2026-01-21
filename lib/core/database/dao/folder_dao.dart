import 'package:sqflite/sqflite.dart';

import '../db.dart';
import '../models.dart';

class FolderDao {
  Future<void> insert(FolderModel folder) async {
    final db = await DocVaultDatabase.instance.database;
    await db.insert('folders', folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(FolderModel folder) async {
    final db = await DocVaultDatabase.instance.database;
    await db.update('folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> delete(String id) async {
    final db = await DocVaultDatabase.instance.database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FolderModel>> list() async {
    final db = await DocVaultDatabase.instance.database;
    final result = await db.query('folders', orderBy: 'created_at DESC');
    return result.map(FolderModel.fromMap).toList();
  }
}
