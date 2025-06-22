import 'package:today/models/activity.dart';
import 'package:today/repository/activity_repository.dart';

class ActivityService {
  final ActivityRepository activityRepo;

  ActivityService({required this.activityRepo});

  Future<List<Activity>> getAll() async {
    return await activityRepo.getAll();
  }

  Future<List<Activity>> getByDate(DateTime date) async {
    final dateString = _formatDate(date);
    return await activityRepo.getByDate(dateString);
  }

  Future<Map<String, int>> getStats(DateTime date) async {
    final dateString = _formatDate(date);
    return await activityRepo.getStatsByDate(dateString);
  }

  Future<Activity> create({
    required String title,
    String? description,
    required DateTime date,
    required String time,
    required String priority,
  }) async {
    final activity = Activity(
      title: title,
      description: description,
      date: _formatDate(date),
      time: time,
      priority: priority,
    );

    return await activityRepo.insert(activity);
  }

  Future<void> createMany(List<Activity> activities) async {
    return activityRepo.createMany(activities);
  }

  Future<Activity> update(Activity activity) async {
    await activityRepo.update(activity);
    return activity;
  }

  Future<bool> toggleCompleted(String id) async {
    return await activityRepo.toggleCompleted(id);
  }

  Future<bool> delete(String id) async {
    return await activityRepo.delete(id);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
