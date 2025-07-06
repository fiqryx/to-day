import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

typedef AlarmCallback = void Function(Map<String, dynamic> data);

class AlarmService {
  static AlarmService? _instance;
  static AudioPlayer? _audioPlayer;

  final List<int> _list = [];
  final String _port = 'alarm_isolate_port';

  ReceivePort? _receivePort;
  AlarmCallback? _onAlarmTriggered;

  AlarmService._();

  static const String _key = 'active_alarms';
  static const String _logsKey = 'alarm_logs';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Get static instance
  static AlarmService get instance => _instance ??= AlarmService._();

  /// Get list of alarm IDs
  List<int> get alarms => List.unmodifiable(_list);

  /// Check if specific alarm is active
  bool isActive(int alarmId) => _list.contains(alarmId);

  /// Initialize alarm service
  Future<void> initialize({AlarmCallback? onAlarmTriggered}) async {
    try {
      await AndroidAlarmManager.initialize();
      _audioPlayer = AudioPlayer();

      _onAlarmTriggered = onAlarmTriggered;
      await _setup();
      await _load();

      developer.log('initialized successfully', name: 'AlarmService');
    } catch (e) {
      developer.log('Failed to initialize: $e', name: 'AlarmService');
      rethrow;
    }
  }

  /// Schedule one-shot alarm
  Future<bool> scheduleOneShot({
    required Duration duration,
    int? alarmId,
    bool exact = true,
    bool wakeup = true,
    bool alarmClock = true,
    bool allowWhileIdle = true,
    Map<String, String?>? payload,
    String soundType = 'system_alarm',
    double volume = 1.0,
    bool vibrate = true,
    int soundDuration = 30,
    String? customSoundPath,
  }) async {
    try {
      alarmId ??= _generateId();

      final alarmData = {
        ...?payload,
        'soundType': soundType,
        'volume': volume.toString(),
        'vibrate': vibrate,
        'duration': soundDuration.toString(),
        'customSoundPath': customSoundPath,
      };

      await _storage.write(
          key: 'alarm_data_$alarmId', value: _toString(alarmData));

      final success = await AndroidAlarmManager.oneShot(
        duration,
        alarmId,
        _alarmCallback,
        exact: exact,
        wakeup: wakeup,
        alarmClock: alarmClock,
        allowWhileIdle: allowWhileIdle,
      );

      if (success) {
        _list.add(alarmId);
        await _save();

        developer.log('One-shot alarm $alarmId scheduled successfully',
            name: 'AlarmService');
      } else {
        developer.log('Failed to schedule one-shot alarm $alarmId',
            name: 'AlarmService');
      }

      return success;
    } catch (e) {
      developer.log('Error scheduling one-shot alarm: $e',
          name: 'AlarmService');
      return false;
    }
  }

  /// Schedule periodic alarm
  Future<bool> schedulePeriodic({
    required Duration period,
    int? alarmId,
    DateTime? startAt,
    bool exact = false,
    bool wakeup = true,
    bool allowWhileIdle = true,
    Map<String, dynamic>? payload,
    String soundType = 'system_alarm',
    double volume = 1.0,
    bool vibrate = true,
    int soundDuration = 30,
    String? customSoundPath,
  }) async {
    try {
      alarmId ??= _generateId();

      final alarmData = {
        ...?payload,
        'soundType': soundType,
        'volume': volume.toString(),
        'vibrate': vibrate,
        'duration': soundDuration.toString(),
        'customSoundPath': customSoundPath,
      };

      // Save alarm data
      await _storage.write(
          key: 'alarm_data_$alarmId', value: _toString(alarmData));

      final success = await AndroidAlarmManager.periodic(
        period,
        alarmId,
        _alarmCallback,
        startAt: startAt,
        exact: exact,
        wakeup: wakeup,
        allowWhileIdle: allowWhileIdle,
      );

      if (success) {
        _list.add(alarmId);
        await _save();
        developer.log('Periodic alarm $alarmId scheduled successfully',
            name: 'AlarmService');
      } else {
        developer.log('Failed to schedule periodic alarm $alarmId',
            name: 'AlarmService');
      }

      return success;
    } catch (e) {
      developer.log('Error scheduling periodic alarm: $e',
          name: 'AlarmService');
      return false;
    }
  }

  /// Cancel specifict alarm by id
  Future<bool> cancel(int alarmId) async {
    try {
      await AndroidAlarmManager.cancel(alarmId);

      await _stopSound();
      _list.remove(alarmId);
      await _save();

      await _storage.delete(key: 'alarm_data_$alarmId');
      developer.log('Alarm $alarmId cancelled', name: 'AlarmService');

      return true;
    } catch (e) {
      developer.log('Error cancelling alarm $alarmId: $e',
          name: 'AlarmService');
      return false;
    }
  }

  /// Cancel all alarm
  Future<void> cancelAll() async {
    try {
      await _stopSound();

      for (int alarmId in List.from(_list)) {
        await cancel(alarmId);
      }

      developer.log('All alarms cancelled', name: 'AlarmService');
    } catch (e) {
      developer.log('Error cancelling all alarms: $e', name: 'AlarmService');
    }
  }

  void dispose() {
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping(_port);
    developer.log('AlarmManagerService disposed', name: 'AlarmService');
  }

  /// Add log entry
  Future<void> log(String message) async {
    try {
      final timestamp = DateTime.now().toString().substring(11, 19);
      final logEntry = '[$timestamp] $message';

      final existing = await logs();
      existing.insert(0, logEntry);

      // Keep only last 50 logs
      if (existing.length > 50) {
        existing.removeRange(50, existing.length);
      }

      await _storage.write(key: _logsKey, value: existing.join('|||'));
      developer.log(message, name: 'AlarmService');
    } catch (e) {
      developer.log('Error adding log: $e', name: 'AlarmService');
    }
  }

  /// Get all logs
  Future<List<String>> logs() async {
    try {
      final logsStr = await _storage.read(key: _logsKey);
      if (logsStr != null && logsStr.isNotEmpty) {
        return logsStr.split('|||').where((log) => log.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      developer.log('Error getting logs: $e', name: 'AlarmService');
      return [];
    }
  }

  /// Clear all logs
  Future<void> clear() async {
    try {
      await _stopSound();
      await _storage.delete(key: _logsKey);
      developer.log('All logs cleared', name: 'AlarmService');
    } catch (e) {
      developer.log('Error clearing logs: $e', name: 'AlarmService');
    }
  }

  /// Clear all data from storage
  Future<void> reset() async {
    try {
      await _stopSound();
      await _storage.deleteAll();
      _list.clear();
      developer.log('All secure storage data cleared', name: 'AlarmService');
    } catch (e) {
      developer.log('Error clearing all data: $e', name: 'AlarmService');
    }
  }

  /// Setup isolate communication
  Future<void> _setup() async {
    _receivePort = ReceivePort();
    bool registered =
        IsolateNameServer.registerPortWithName(_receivePort!.sendPort, _port);

    if (!registered) {
      IsolateNameServer.removePortNameMapping(_port);
      registered =
          IsolateNameServer.registerPortWithName(_receivePort!.sendPort, _port);
    }

    developer.log(
        'Isolate port registration: ${registered ? 'SUCCESS' : 'FAILED'}',
        name: 'AlarmService');

    _receivePort!.listen((dynamic data) {
      developer.log('Received isolate message: $data', name: 'AlarmService');

      if (data is Map<String, dynamic> && data['type'] == 'alarm_triggered') {
        _playSound(data);

        // Clear alarm ID when one-shot
        if (data['isOneShot'] == true) {
          _list.remove(data['alarmId']);
          _save();
        }

        _onAlarmTriggered?.call(data);
      }
    });
  }

  // save alarm to storage
  Future<void> _save() async {
    try {
      await _storage.write(key: _key, value: _list.join(','));
    } catch (e) {
      developer.log('Error saving alarms: $e', name: 'AlarmService');
    }
  }

  // load alarms from storage
  Future<void> _load() async {
    try {
      final str = await _storage.read(key: _key);
      if (str != null && str.isNotEmpty) {
        _list.clear();

        final list = str
            .split(',')
            .map((id) => int.tryParse(id) ?? 0)
            .where((id) => id > 0);

        _list.addAll(list);
      }
    } catch (e) {
      developer.log('Error load alarms: $e', name: 'AlarmService');
    }
  }

  /// Play alarm sound and vibration
  Future<void> _playSound(Map<String, dynamic> data) async {
    try {
      final vibrate =
          await Vibration.hasVibrator() && (data['vibrate'] ?? true);
      final volume =
          double.tryParse(data['volume']?.toString() ?? '1.0') ?? 1.0;

      await _audioPlayer?.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer?.play(
        AssetSource('sounds/box.mp3'),
        volume: volume,
      );

      if (vibrate) {
        await _playVibration(60); // 60 sec vibrate
      }

      // Stop alarm action at:
      // Notif:onActionReceivedImplementationMethod

      Future.delayed(Duration(minutes: 1), () async {
        await _stopSound(); // 1 minute automatic stop
      });
    } catch (e) {
      developer.log('Error playing alarm sound: $e', name: 'AlarmService');
    }
  }

  /// Stop alarm sound and vibration
  Future<void> _stopSound() async {
    try {
      await _audioPlayer?.stop();
      if (await Vibration.hasVibrator()) {
        await Vibration.cancel();
      }
      developer.log('Alarm sound stopped', name: 'AlarmService');
    } catch (e) {
      developer.log('Error stopping alarm sound: $e', name: 'AlarmService');
    }
  }

  /// Play vibration
  Future<void> _playVibration(int seconds) async {
    try {
      if (await Vibration.hasVibrator()) {
        // Create vibration pattern: vibrate for 1000ms, pause for 500ms, repeat
        final pattern = <int>[];
        for (int i = 0; i < seconds; i += 2) {
          pattern.addAll([1000, 500]); // 1 second vibrate, 0.5 second pause
        }

        await Vibration.vibrate(pattern: pattern);
      }
    } catch (e) {
      developer.log('Error playing vibration: $e', name: 'AlarmService');
    }
  }

  // generate unique alarm ID
  int _generateId() {
    return DateTime.now().millisecondsSinceEpoch % 100000000 +
        Random().nextInt(1000);
  }

  String _toString(Map<String, dynamic> map) {
    return map.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  // ignore: unused_element
  Map<String, dynamic> _toMap(String str) {
    final map = <String, dynamic>{};
    for (String pair in str.split('|')) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }
}

// wrapper alarm callback
@pragma('vm:entry-point')
void _alarmCallback() async {
  try {
    developer.log('=== ALARM CALLBACK STARTED ===', name: 'AlarmCallback');

    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    final id = DateTime.now().millisecondsSinceEpoch % 100000000;
    final userDataStr = await storage.read(key: 'alarm_data_$id');

    Map<String, dynamic> userData = {};
    if (userDataStr != null) {
      for (String pair in userDataStr.split('|')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          userData[parts[0]] = parts[1];
        }
      }
    }

    final sendPort = IsolateNameServer.lookupPortByName('alarm_isolate_port');
    if (sendPort != null) {
      sendPort.send({
        'type': 'alarm_triggered',
        'alarmId': id,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isOneShot': true, // Assuming one-shot for this example
        'userData': userData,
      });
      developer.log('Sent message to main isolate', name: 'AlarmCallback');
    } else {
      developer.log('SendPort not found in isolate registry',
          name: 'AlarmCallback');
    }

    developer.log('=== ALARM CALLBACK COMPLETED ===', name: 'AlarmCallback');
  } catch (e, stackTrace) {
    developer.log('Alarm callback error: $e',
        error: e, stackTrace: stackTrace, name: 'AlarmCallback');
  }
}
