import 'dart:ui';
import 'dart:isolate';
import 'dart:developer' as dev;

import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:today/helpers/utils.dart';
import 'package:today/services/alarm_service.dart';

@pragma('vm:entry-point')
class NotificationService {
  static ReceivedAction? initialAction;
  static ReceivePort? receivePort;

  static Future<void> initializeLocalNotifications() async {
    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: "silent_channel",
        channelName: "Silent Notifications",
        channelDescription: "Notifications without sound or vibration",
        playSound: false,
        soundSource: null,
        enableVibration: false,
        importance: NotificationImportance.High,
        defaultColor: Colors.primaries.first,
      ),
    ]);

    initialAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: false);
  }

  static Future<void> initializeIsolateReceivePort() async {
    receivePort = ReceivePort("Notification action port")
      ..listen((data) => onActionClick(data));

    IsolateNameServer.registerPortWithName(
        receivePort!.sendPort, 'notification_action_port');
  }

  static Future<void> startListeningEvents() async {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceived,
      // onNotificationDisplayedMethod: onPopup,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceived(ReceivedAction action) async {
    if (action.actionType == ActionType.SilentAction ||
        action.actionType == ActionType.SilentBackgroundAction) {
      await executeLongTaskInBackground();
    } else {
      dev.log('receive port: $receivePort', name: "notification");
      if (receivePort == null) {
        SendPort? sendPort =
            IsolateNameServer.lookupPortByName('notification_action_port');

        if (sendPort != null) {
          sendPort.send(action);
          return;
        }
      }
    }

    return onActionClick(action);
  }

  static Future<void> onPopup(ReceivedNotification action) async {
    final id = action.payload!["id"].hashCode.abs() % 2147483647;
    final type = action.payload?["type"] ?? "default";

    dev.log(type, name: "Notification");

    switch (type) {
      case "alarm":
        final dateStr = action.payload!["date"];
        if (dateStr == null) return;
        final datetime = DateTime.parse(dateStr);
        final duration = datetime.difference(DateTime.now());

        if (AlarmService.instance.isActive(id)) {
          await AlarmService.instance.cancel(id);
        }

        await AlarmService.instance.scheduleOneShot(
          duration: duration,
          alarmId: id,
        );
        break;
    }
  }

  static Future<void> onActionClick(ReceivedAction action) async {
    final id = action.payload!["id"].hashCode.abs() % 2147483647;

    dev.log("action: ${action.buttonKeyPressed}", name: "Notification");
    dev.log("payload: ${action.payload.toString()}", name: "Notification");

    switch (action.buttonKeyPressed) {
      case "stopAlarm":
        await AlarmService.instance.cancel(id);
        await cancel(id);
        break;
      case "snoozeAlarm":
        try {
          final dateStr = action.payload!["date"];
          if (dateStr == null) return;

          final originalAlarmTime = DateTime.parse(dateStr);
          final newAlarmTime = originalAlarmTime.add(Duration(minutes: 5));
          final delayDuration = newAlarmTime.difference(DateTime.now());

          if (delayDuration.isNegative) return;

          if (AlarmService.instance.isActive(id)) {
            await AlarmService.instance.cancel(id);
          }

          await AlarmService.instance.scheduleOneShot(
            duration: delayDuration,
            alarmId: id,
          );

          await cancel(id);
          await createScheduleNewNotification(
            date: newAlarmTime,
            content: NotificationContent(
              id: id,
              channelKey: "silent_channel",
              title: action.title,
              body: Utils.getNotificationBody(newAlarmTime),
              payload: action.payload,
            ),
            actions: [
              NotificationActionButton(
                key: "stopAlarm",
                label: "Stop",
                actionType: ActionType.SilentAction,
              ),
              NotificationActionButton(
                key: "snoozeAlarm",
                label: "Snooze",
                actionType: ActionType.SilentAction,
              ),
            ],
          );
        } catch (e) {
          dev.log("Error in snoozeAlarm: $e", name: "Notification");
        }
        break;
      default:
      // example:
      // MyApp.navigatorKey.currentState?.push(MaterialPageRoute(
      //     builder: (context) => ProductDetailPage(
      //         receivedAction.bigPicture ?? "",
      //         "Hoodies for unisex",
      //         receivedAction.body ?? "")));
    }
  }

  static Future<bool> requestPermission() async {
    bool? userChoice = await showDialog<bool>(
      context: context as BuildContext,
      builder: (context) {
        final theme = ShadTheme.of(context);
        return AlertDialog(
          title: Text(
            "Enable Notifications",
            style: theme.textTheme.h2,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                "Stay updated with important alerts and messages",
                style: theme.textTheme.large,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "We'll only send you relevant notifications",
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Maybe Later"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Allow Notifications"),
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceBetween,
        );
      },
    );

    if (userChoice == true) {
      return await AwesomeNotifications()
          .requestPermissionToSendNotifications();
    }

    return false;
  }

  static Future<void> executeLongTaskInBackground() async {
    //
  }

  static Future<void> createNewNotification({
    required NotificationContent content,
    List<NotificationActionButton>? actions,
  }) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) isAllowed = await requestPermission();
    if (!isAllowed) return;

    await AwesomeNotifications().createNotification(
      content: content,
      actionButtons: actions,
    );
  }

  static Future<void> createScheduleNewNotification({
    bool repeat = false,
    required DateTime date,
    required NotificationContent content,
    List<NotificationActionButton>? actions,
  }) async {
    var schedule = NotificationCalendar(
      year: date.year,
      month: date.month,
      day: date.day,
      hour: date.hour,
      minute: date.minute,
      second: date.second,
      repeats: repeat,
    );

    await AwesomeNotifications().createNotification(
      schedule: schedule,
      actionButtons: actions,
      content: content,
    );
  }

  static Future<void> resetCounter() async {
    await AwesomeNotifications().resetGlobalBadge();
  }

  static Future<void> cancel(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  static Future<void> cancelAll() async {
    await AwesomeNotifications().cancelAll();
  }
}
