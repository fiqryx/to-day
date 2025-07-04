import 'package:intl/intl.dart';

class Utils {
  static final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormatter = DateFormat('dd/MM/yyyy');
  static final DateFormat _fullDateFormatter = DateFormat('EEEE, d MMMM yyyy');

  static String formatForDatabase(DateTime date) {
    return _dateFormatter.format(date);
  }

  static String formatForDisplay(DateTime date) {
    return _displayDateFormatter.format(date);
  }

  static String formatFullDate(DateTime date) {
    return _fullDateFormatter.format(date);
  }

  static DateTime parseFromDatabase(String dateString) {
    return _dateFormatter.parse(dateString);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  static bool isPast(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(now) && !isSameDay(date, now);
  }

  static bool isFuture(DateTime date) {
    final now = DateTime.now();
    return date.isAfter(now) && !isSameDay(date, now);
  }

  static String getRelativeDateString(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (isSameDay(date, now)) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 1 && difference <= 7) {
      return '$difference more days';
    } else if (difference < -1 && difference >= -7) {
      return '${difference.abs()} days ago';
    } else {
      return formatForDisplay(date);
    }
  }

  static String getActivityNotificationTitle(String priority, title) {
    switch (priority) {
      case "high":
        return "⏰ URGENT: $title!";
      case "medium":
        return "📌 Don't forget: $title";
      default:
        return "🔔 Reminder: $title";
    }
  }
}
