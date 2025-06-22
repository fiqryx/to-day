import 'dart:ui';
import 'dart:isolate';

import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class Notif {
  static ReceivedAction? initialAction;
  static ReceivePort? receivePort;

  static Future<void> initializeLocalNotifications() async {
    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: "basic_channel",
        channelName: "Basic",
        channelDescription: "Basic notification",
        playSound: true,
        onlyAlertOnce: true,
        groupAlertBehavior: GroupAlertBehavior.Children,
        importance: NotificationImportance.High,
        defaultPrivacy: NotificationPrivacy.Private,
        defaultColor: Colors.primaries.first,
        ledColor: Colors.primaries.first,
      )
    ]);

    initialAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: false);
  }

  static Future<void> initializeIsolateReceivePort() async {
    receivePort = ReceivePort("Notification action port")
      ..listen(
        (data) => onActionReceivedImplementationMethod(data),
      );

    IsolateNameServer.registerPortWithName(
        receivePort!.sendPort, 'notification_action_port');
  }

  static Future<void> startListeningNotificationEvents() async {
    AwesomeNotifications()
        .setListeners(onActionReceivedMethod: onActionReceivedMethod);
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction action) async {
    if (action.actionType == ActionType.SilentAction ||
        action.actionType == ActionType.SilentBackgroundAction) {
      await executeLongTaskInBackground();
    } else {
      if (receivePort == null) {
        SendPort? sendPort =
            IsolateNameServer.lookupPortByName('notification_action_port');

        if (sendPort != null) {
          sendPort.send(action);
          return;
        }
      }

      return onActionReceivedImplementationMethod(action);
    }
  }

  static Future<void> onActionReceivedImplementationMethod(
      ReceivedAction action) async {
    // redirect route implementation
  }

  /// request notification permission
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
