import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/planning_models.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'planning_ccas.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE plannings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        capture_date TEXT NOT NULL,
        image_path TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        label TEXT,
        total_shifts INTEGER DEFAULT 0,
        uncertain_shifts INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE shifts (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        start_hour INTEGER,
        start_minute INTEGER,
        end_hour INTEGER,
        end_minute INTEGER,
        type TEXT NOT NULL,
        raw_text TEXT,
        confidence_score REAL DEFAULT 1.0,
        needs_verification INTEGER DEFAULT 0,
        note TEXT,
        planning_id INTEGER,
        FOREIGN KEY (planning_id) REFERENCES plannings(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // === PLANNINGS ===

  Future<int> insertPlanning(PlanningRecord record) async {
    return await _db!.insert('plannings', record.toMap());
  }

  Future<void> updatePlanning(PlanningRecord record) async {
    await _db!.update(
      'plannings',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deletePlanning(int id) async {
    await _db!.delete('plannings', where: 'id = ?', whereArgs: [id]);
    await _db!.delete('shifts', where: 'planning_id = ?', whereArgs: [id]);
  }

  Future<List<PlanningRecord>> getAllPlannings() async {
    final maps = await _db!.query('plannings', orderBy: 'capture_date DESC');
    return maps.map((m) => PlanningRecord.fromMap(m)).toList();
  }

  Future<List<PlanningRecord>> getPlanningsByYear(int year) async {
    final maps = await _db!.query(
      'plannings',
      where: "strftime('%Y', capture_date) = ?",
      whereArgs: [year.toString()],
      orderBy: 'capture_date DESC',
    );
    return maps.map((m) => PlanningRecord.fromMap(m)).toList();
  }

  // === SHIFTS ===

  Future<void> insertShift(ShiftEntry shift) async {
    await _db!.insert('shifts', shift.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertShifts(List<ShiftEntry> shifts) async {
    final batch = _db!.batch();
    for (final shift in shifts) {
      batch.insert('shifts', shift.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<void> updateShift(ShiftEntry shift) async {
    await _db!.update('shifts', shift.toMap(), where: 'id = ?', whereArgs: [shift.id]);
  }

  Future<void> deleteShift(String id) async {
    await _db!.delete('shifts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ShiftEntry>> getShiftsByMonth(int year, int month) async {
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59).toIso8601String();
    final maps = await _db!.query(
      'shifts',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date ASC',
    );
    return maps.map((m) => ShiftEntry.fromMap(m)).toList();
  }

  Future<List<ShiftEntry>> getShiftsByDateRange(DateTime from, DateTime to) async {
    final maps = await _db!.query(
      'shifts',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date ASC',
    );
    return maps.map((m) => ShiftEntry.fromMap(m)).toList();
  }

  Future<List<ShiftEntry>> getUpcomingShifts({int limit = 10}) async {
    final now = DateTime.now();
    final maps = await _db!.query(
      'shifts',
      where: "date >= ? AND type = 'travail'",
      whereArgs: [now.toIso8601String()],
      orderBy: 'date ASC',
      limit: limit,
    );
    return maps.map((m) => ShiftEntry.fromMap(m)).toList();
  }

  Future<ShiftEntry?> getNextShift() async {
    final now = DateTime.now();
    final maps = await _db!.query(
      'shifts',
      where: "date >= ? AND type = 'travail'",
      whereArgs: [DateTime(now.year, now.month, now.day).toIso8601String()],
      orderBy: 'date ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ShiftEntry.fromMap(maps.first);
  }

  Future<List<ShiftEntry>> getShiftsForPlanning(int planningId) async {
    final maps = await _db!.query(
      'shifts',
      where: 'planning_id = ?',
      whereArgs: [planningId],
      orderBy: 'date ASC',
    );
    return maps.map((m) => ShiftEntry.fromMap(m)).toList();
  }

  Future<List<ShiftEntry>> getUncertainShifts() async {
    final maps = await _db!.query(
      'shifts',
      where: 'needs_verification = 1',
      orderBy: 'date ASC',
    );
    return maps.map((m) => ShiftEntry.fromMap(m)).toList();
  }

  // === SETTINGS ===

  Future<void> saveSetting(String key, String value) async {
    await _db!.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final maps = await _db!.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }
}