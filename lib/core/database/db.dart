import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class DocVaultDatabase {
  DocVaultDatabase._();

  static final DocVaultDatabase instance = DocVaultDatabase._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final filePath = path.join(dbPath, 'docvault.db');
    return openDatabase(filePath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        folder_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_favorite INTEGER NOT NULL,
        page_count INTEGER NOT NULL,
        pdf_path TEXT,
        thumbnail_path TEXT,
        ocr_text TEXT,
        size_bytes INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pages (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        page_index INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        ocr_text TEXT,
        FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE document_tags (
        document_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY(document_id, tag_id),
        FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
        FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');
  }
}
