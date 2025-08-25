import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'irondiary.db');
    return openDatabase(path,
        version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE exercises(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE workouts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY(exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');

    // insert default categories
    final catNames = ['胸', '肩', '背', '腿'];
    for (final name in catNames) {
      await db.insert('categories', {'name': name});
    }

    final categories = await db.query('categories');
    final catIds = {for (var c in categories) c['name'] as String: c['id'] as int};
    Future<void> addEx(String cat, String name) async {
      final catId = catIds[cat]!;
      await db.insert('exercises', {'category_id': catId, 'name': name});
    }

    await addEx('胸', '啞鈴胸推');
    await addEx('胸', '槓鈴胸推');
    await addEx('胸', '機械胸推');
    await addEx('胸', '啞鈴上胸');
    await addEx('胸', '槓鈴上胸');
    await addEx('肩', '啞鈴肩推');
    await addEx('肩', '槓鈴肩推');
    await addEx('背', '坐姿划船');
    await addEx('背', '硬舉');
    await addEx('背', '滑輪下拉');
    await addEx('背', '引體向上');
    await addEx('腿', '深蹲');
    await addEx('腿', '保加利亞分腿蹲');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE workouts ADD COLUMN weight REAL NOT NULL DEFAULT 0');
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.query('categories');
  }

  Future<List<Map<String, dynamic>>> getExercises(int categoryId) async {
    final db = await database;
    return db.query('exercises', where: 'category_id = ?', whereArgs: [categoryId]);
  }

  Future<void> insertCategory(String name) async {
    final db = await database;
    await db.insert('categories', {'name': name});
  }

  Future<void> updateCategory(int id, String name) async {
    final db = await database;
    await db.update('categories', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertExercise(int categoryId, String name) async {
    final db = await database;
    await db.insert('exercises', {'category_id': categoryId, 'name': name});
  }

  Future<void> updateExercise(int id, String name) async {
    final db = await database;
    await db.update('exercises', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExercise(int id) async {
    final db = await database;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> logWorkout(int exerciseId, int reps, double weight) async {
    final db = await database;
    await db.insert('workouts', {
      'exercise_id': exerciseId,
      'reps': reps,
      'weight': weight,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getWorkouts(DateTime start, DateTime end) async {
    final db = await database;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    return db.rawQuery('''
      SELECT w.id, w.reps, w.weight, w.timestamp, e.name as exercise_name, c.name as category_name
      FROM workouts w
      JOIN exercises e ON w.exercise_id = e.id
      JOIN categories c ON e.category_id = c.id
      WHERE w.timestamp BETWEEN ? AND ?
      ORDER BY w.timestamp DESC
    ''', [startMs, endMs]);
  }
}
