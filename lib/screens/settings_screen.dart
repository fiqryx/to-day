import 'dart:convert';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:today/helpers/notification.dart';
import 'package:today/helpers/utils.dart';
import 'package:today/models/activity.dart';
import 'package:today/services/activity_service.dart';
import 'package:today/stores/app_store.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppStore _appStore;
  late ActivityService _activityService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appStore = Provider.of<AppStore>(context);
    _activityService = Provider.of<ActivityService>(context);
  }

  Future<void> _toggleNotification() async {
    var reminder = !_appStore.reminder;
    await _appStore.set(reminder: reminder);
    if (reminder) {
      _rescheduleNotification();
    } else {
      Notif.cancelAll();
    }
  }

  Future<void> _onBackup() async {
    try {
      final activities = await _activityService.getAll();

      if (activities.isEmpty) {
        Fluttertoast.showToast(msg: 'No data to export');
        return;
      }

      final List<Map<String, dynamic>> exportData = activities.map((activity) {
        return activity.toMap();
      }).toList();

      final String jsonString = const JsonEncoder.withIndent('  ').convert({
        'version': 1, // change the version if have diff format data
        'generatedAt': DateTime.now().toIso8601String(),
        'activities': exportData,
      });

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/today_app_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await tempFile.writeAsString(jsonString);

      await FileSaver.instance.saveAs(
        name: 'today_app_backup',
        bytes: await tempFile.readAsBytes(),
        ext: 'json',
        mimeType: MimeType.json,
      );

      Fluttertoast.showToast(msg: 'Export successfully');
      tempFile.delete();
    } catch (e) {
      Fluttertoast.showToast(msg: 'Export failed: $e');
    }
  }

  Future<void> _onRestore() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: ['json'],
      );

      if (result == null) return;

      // read file content
      File file = File(result.files.single.path!);
      String content = await file.readAsString();

      // parse json
      final Map<String, dynamic> jsonData = jsonDecode(content);
      if (jsonData['activities'] == null) {
        throw Exception('Invalid format: missing imported data');
      }

      // convert to activity
      final List<dynamic> activityList = jsonData['activities'];
      await _activityService.createMany(
        activityList.map((item) => Activity.fromMap(item)).toList(),
      );

      Fluttertoast.showToast(msg: 'Data imported successfully!');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Import failed: $e');
    }
  }

  Future<void> _rescheduleNotification() async {
    debugPrint("reschedule all notification");
    for (var value in await _activityService.getAll()) {
      var date = value.dateTime;
      if (date.isAfter(DateTime.now()) && _appStore.reminder == true) {
        await Notif.createScheduleNewNotification(
          date: date,
          content: NotificationContent(
            id: value.id.hashCode.abs() % 2147483647,
            channelKey: "basic_channel",
            title:
                Utils.getActivityNotificationTitle(value.priority, value.title),
            body:
                "You scheduled this for ${DateFormat('MMM d, h:mm a').format(date)}",
            payload: {
              'activityId': value.id,
              'type': 'reminder',
            },
          ),
        );
      }
    }
  }

  void _openUrl(String url) {
    debugPrint('Opening URL: $url');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // const SizedBox(height: 8),
          // Text('GENERAL', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          _buildGeneraleSection(),
          const SizedBox(height: 24),
          Text('DATA', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          _buildDataSection(),
          const SizedBox(height: 24),
          Text('ABOUT', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildGeneraleSection() {
    return ShadCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Notifications',
              style: ShadTheme.of(context).textTheme.small,
            ),
            subtitle: Text(
              'Show notifications at scheduled times',
              style: ShadTheme.of(context).textTheme.muted,
            ),
            trailing: Transform.scale(
              // Get notified at scheduled times
              scale: 0.8,
              child: Switch(
                value: _appStore.reminder,
                onChanged: (_) => _toggleNotification(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            onTap: _toggleNotification,
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    var theme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          ListTile(
            onTap: _onBackup,
            title: Text('Backup', style: theme.textTheme.small),
            subtitle: Text(
              "Save your data to device storage",
              style: theme.textTheme.muted,
            ),
            trailing: const Icon(size: 20, LucideIcons.download),
          ),
          const Divider(height: 1),
          ListTile(
            onTap: _onRestore,
            title: Text('Restore', style: theme.textTheme.small),
            subtitle: Text(
              "Recover your data from backup",
              style: theme.textTheme.muted,
            ),
            trailing: const Icon(size: 20, LucideIcons.history),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return ShadCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Version',
              style: ShadTheme.of(context).textTheme.small,
            ),
            trailing: Text(
              dotenv.get("APP_VERSION", fallback: "1.0.0"),
              style: ShadTheme.of(context).textTheme.muted,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              'Privacy Policy',
              style: ShadTheme.of(context).textTheme.small,
            ),
            trailing: Transform.scale(
              scale: 0.8,
              child: const Icon(LucideIcons.chevronRight),
            ),
            onTap: () => _openUrl('https://example.com/privacy'),
          ),
        ],
      ),
    );
  }
}
