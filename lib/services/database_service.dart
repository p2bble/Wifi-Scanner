import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/scan_history.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _db;

  DatabaseService._();
  factory DatabaseService() => _instance ??= DatabaseService._();

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wifi_history.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE scan_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            measuredAt INTEGER NOT NULL,
            ssid TEXT NOT NULL,
            bssid TEXT NOT NULL,
            rssi INTEGER NOT NULL,
            band TEXT NOT NULL,
            channel INTEGER NOT NULL,
            wifiStandard TEXT NOT NULL,
            grade TEXT,
            avgMs INTEGER,
            jitterMs INTEGER,
            lossRate REAL,
            speedMbps REAL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_measuredAt ON scan_history(measuredAt DESC)');
      },
    );
  }

  Future<void> insert(ScanHistory h) async {
    if (kIsWeb) return;
    try {
      final db = await _database;
      await db.insert('scan_history', h.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<List<ScanHistory>> getRecent({int limit = 100}) async {
    if (kIsWeb) return [];
    try {
      final db = await _database;
      final rows = await db.query(
        'scan_history',
        orderBy: 'measuredAt DESC',
        limit: limit,
      );
      return rows.map(ScanHistory.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> delete(int id) async {
    if (kIsWeb) return;
    try {
      final db = await _database;
      await db.delete('scan_history', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    if (kIsWeb) return;
    try {
      final db = await _database;
      await db.delete('scan_history');
    } catch (_) {}
  }

  Future<int> count() async {
    if (kIsWeb) return 0;
    try {
      final db = await _database;
      final result =
          await db.rawQuery('SELECT COUNT(*) as c FROM scan_history');
      return (result.first['c'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
