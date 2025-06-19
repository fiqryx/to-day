import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get db async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path =
        join(await getDatabasesPath(), dotenv.env['DB_NAME'] ?? 'to_day.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'medium',
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_activities_date ON activities(date)');
    await db.execute(
        'CREATE INDEX idx_activities_priority ON activities(priority)');
    await db.execute(
        'CREATE INDEX idx_activities_completed ON activities(completed)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Assuming version 2 introduces UUIDs
      await db.execute('ALTER TABLE activities ADD COLUMN new_id TEXT');

      // Generate UUIDs for existing records
      final activities = await db.query('activities');
      for (var activity in activities) {
        await db.update(
          'activities',
          {'id': const Uuid().v4()},
          where: 'id = ?',
          whereArgs: [activity['id']],
        );
      }

      await db.execute('DROP TABLE activities');
      await _onCreate(db, newVersion);
    }
  }

  Future<void> close() async => (await db).close();
}
