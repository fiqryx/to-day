import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/activity.dart';

class ActivityRepository {
  final Database db;
  static const _uuid = Uuid();

  ActivityRepository({required this.db});

  // CRUD Operations

  Future<List<Activity>> getByDate(String date) async {
    try {
      final maps = await db.query(
        'activities',
        where: 'date = ?',
        whereArgs: [date],
        orderBy: 'time ASC',
      );
      return maps.map((map) => Activity.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch activities by date: $e');
    }
  }

  Future<List<Activity>> getAll() async {
    try {
      final maps = await db.query(
        'activities',
        orderBy: 'date DESC, time ASC',
      );
      return maps.map((map) => Activity.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch all activities: $e');
    }
  }

  Future<Activity?> getById(String id) async {
    try {
      final maps = await db.query(
        'activities',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return maps.isNotEmpty ? Activity.fromMap(maps.first) : null;
    } catch (e) {
      throw DatabaseException('Failed to fetch activity by ID: $e');
    }
  }

  Future<Activity> insert(Activity activity) async {
    try {
      final values = activity.id!.isEmpty
          ? activity.copyWith(id: const Uuid().v4())
          : activity;

      await db.insert(
        'activities',
        values.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return values;
    } catch (e) {
      throw DatabaseException('Failed to insert activity: $e');
    }
  }

  Future<Activity> update(Activity activity) async {
    try {
      final rowsUpdated = await db.update(
        'activities',
        activity.toMap(),
        where: 'id = ?',
        whereArgs: [activity.id],
      );

      if (rowsUpdated == 0) {
        throw DatabaseException('No activity found with ID ${activity.id}');
      }

      return activity;
    } catch (e) {
      throw DatabaseException('Failed to update activity: $e');
    }
  }

  Future<bool> toggleCompleted(String id) async {
    try {
      final activity = await getById(id);
      if (activity == null) return false;

      await update(activity.copyWith(completed: !activity.completed));
      return true;
    } catch (e) {
      throw DatabaseException('Failed to toggle completion status: $e');
    }
  }

  Future<bool> delete(String id) async {
    try {
      final rowsDeleted = await db.delete(
        'activities',
        where: 'id = ?',
        whereArgs: [id],
      );
      return rowsDeleted > 0;
    } catch (e) {
      throw DatabaseException('Failed to delete activity: $e');
    }
  }

  // Query Operations

  Future<List<Activity>> getByDateRange(
      String startDate, String endDate) async {
    try {
      final maps = await db.query(
        'activities',
        where: 'date BETWEEN ? AND ?',
        whereArgs: [startDate, endDate],
        orderBy: 'date ASC, time ASC',
      );
      return maps.map((map) => Activity.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch activities by date range: $e');
    }
  }

  Future<Map<String, int>> getStatsByDate(String date) async {
    try {
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total,
          COALESCE(SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END), 0) as completed,
          COALESCE(SUM(CASE WHEN priority = 'high' THEN 1 ELSE 0 END), 0) as high_priority
        FROM activities 
        WHERE date = ?
      ''', [date]);

      return {
        'total': result.first['total'] as int? ?? 0,
        'completed': result.first['completed'] as int? ?? 0,
        'high_priority': result.first['high_priority'] as int? ?? 0,
      };
    } catch (e) {
      throw DatabaseException('Failed to fetch activity stats: $e');
    }
  }

  // Batch Operations

  Future<void> createMany(List<Activity> activities) async {
    final batch = db.batch();
    for (final activity in activities) {
      batch.insert(
        'activities',
        activity.id != null
            ? activity.copyWith(id: _uuid.v4()).toMap()
            : activity.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  Future<int> deleteCompleted() async {
    try {
      return await db.delete(
        'activities',
        where: 'completed = 1',
      );
    } catch (e) {
      throw DatabaseException('Failed to delete completed activities: $e');
    }
  }
}

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);

  @override
  String toString() => 'DatabaseException: $message';
}
