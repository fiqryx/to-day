import 'dart:math';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:today/helpers/logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

@pragma('vm:entry-point')
class ANotification {
  static ReceivePort? port;
  static ReceivedAction? action;
  static final _instance = AwesomeNotifications();

  static String get _portName => 'notification_action_port';

  static Future<bool> get _allowed => _instance.isNotificationAllowed();

  static List<NotificationChannel> get _channels => [
        NotificationChannel(
          playSound: true,
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'This channel is used for basic notifications',
          importance: NotificationImportance.Max,
        ),
      ];

  static List<String> get _titles => [
        "💡 Knowledge Boost",
        "⏰ Study Time!",
        "🧠 Brain Workout",
        "🚀 Learning Journey",
        "✨ Quick Practice?",
        "🎯 Focus Time Ahead",
        "🌟 Learning Breakthrough",
      ];

  /// list of notification messages
  static List<String> get _messages => [
        "Consistency is key! Keep up the great work 🌈",
        "Your brain is eager for a workout! Let's go 🧠",
        "Don't let your streak break! Quick flip session? 🔥",
        "Knowledge waits for no one! Let's flip some cards 📚",
        "Your cards are waiting for you! Time to practice ✨",
        "Don't miss out on today's learning adventure 🌟",
        "Your learning journey continues... Join us! 🚀",
        "Missing you! Come back and flip some cards 🃏",
        "Your flashcards are just a tap away. Let's make progress 📈",
        "Ready for a brain workout? Your flashcards miss you 🧠",
        "Ready to conquer new knowledge? Your cards are waiting 🎯",
      ];

  static Future<void> initialize() async {
    try {
      var localTz = await FlutterTimezone.getLocalTimezone();

      tz.initializeTimeZones();
      tz.setLocalLocation(
        tz.getLocation(localTz.identifier),
      );

      await _instance.initialize('resource://drawable/notification', _channels);

      port = ReceivePort("Notification action port")
        ..listen((data) => _onClick(data));

      action = await _instance.getInitialNotificationAction(
        removeFromActionEvents: false,
      );

      // register port
      IsolateNameServer.registerPortWithName(port!.sendPort, _portName);

      // start event listener
      await _instance.setListeners(
        onActionReceivedMethod: _onReceived,
        // onNotificationDisplayedMethod: onPopup,
      );
    } catch (e) {
      _log('Initialize error: $e');
    }
  }

  static Future<void> create({
    required NotificationContent content,
    List<NotificationActionButton>? actions,
  }) async {
    if (!(await _allowed)) return;
    await _instance.createNotification(
      content: content,
      actionButtons: actions,
    );
  }

  static Future<void> createSchedule({
    required NotificationContent content,
    required NotificationSchedule schedule,
    List<NotificationActionButton>? actions,
  }) async {
    if (!(await _allowed)) return;
    await _instance.createNotification(
      schedule: schedule,
      actionButtons: actions,
      content: content,
    );
  }

  static Future<void> scheduleDaily(List<TimeOfDay> times) async {
    try {
      for (var time in times) {
        final id = times.indexOf(time) + 1;

        // server-side fetch for customize content remotely here...

        await cancel(id);
        await createSchedule(
          schedule: NotificationAndroidCrontab.daily(
            allowWhileIdle: true,
            referenceDateTime: DateTime(0, 0, 0, time.hour, time.minute),
          ),
          content: NotificationContent(
            id: id,
            channelKey: 'basic_channel',
            category: NotificationCategory.Workout,
            title: _titles[Random().nextInt(_titles.length)],
            body: _messages[Random().nextInt(_messages.length)],
            payload: {
              'type': 'daily_reminder',
              'timestamp': '${DateTime.now().millisecondsSinceEpoch}',
            },
          ),
        );
      }
    } catch (e) {
      _log('Failed to schedule daily notifications: $e');
    }
  }

  static Future<void> resetCounter() async {
    await _instance.resetGlobalBadge();
  }

  static Future<void> cancel(int id) async {
    await _instance.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _instance.cancelAll();
  }

  @pragma('vm:entry-point')
  static Future<void> _onReceived(ReceivedAction action) async {
    try {
      if (action.actionType == ActionType.SilentAction ||
          action.actionType == ActionType.SilentBackgroundAction) {
        // execute background/silient notification
      } else {
        _log('receive port: $port');

        if (port == null) {
          SendPort? sendPort = IsolateNameServer.lookupPortByName(_portName);
          if (sendPort != null) {
            sendPort.send(action);
            return;
          }
        }
      }

      return await _onClick(action);
    } catch (e) {
      _log('received error: $e');
    }
  }

  static Future<void> _onClick(ReceivedAction action) async {
    try {
      _log('action: ${action.buttonKeyPressed}');
      _log('payload: ${action.payload.toString()}');
    } catch (e) {
      _log('click error: $e');
    }
  }

  static void _log(String message) {
    Logger.log(message, name: 'ANotification');
  }
}
