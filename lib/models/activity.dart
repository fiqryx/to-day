import 'package:uuid/uuid.dart';

class Activity {
  final String? id;
  final String title;
  final String? description;
  final String date; // Format: YYYY-MM-DD
  final String time; // Format: HH:MM
  final String priority; // 'low', 'medium', 'high'
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  Activity({
    String? id,
    required this.title,
    this.description,
    required this.date,
    required this.time,
    required this.priority,
    this.completed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'priority': priority,
      'completed': completed ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      priority: map['priority'] ?? 'medium',
      completed: (map['completed'] ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    String? date,
    String? time,
    String? priority,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
