import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nubira_local.db');
    return _database!;
  }

  static Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  static Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pending_scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bundle_no TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  static Future<void> insertScan(String bundleNo, String status) async {
    final db = await database;
    await db.insert('pending_scans', {
      'bundle_no': bundleNo,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingScans() async {
    final db = await database;
    return await db.query('pending_scans');
  }

  static Future<void> clearScans() async {
    final db = await database;
    await db.delete('pending_scans');
  }
}
