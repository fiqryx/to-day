import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Global variable to track the main isolate's send port
SendPort? mainSendPort;

// Secure storage instance
const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
);

@pragma('vm:entry-point')
void alarmCallback() async {
  developer.log('=== ALARM CALLBACK STARTED ===', name: 'ALARM');

  try {
    // Update secure storage
    final countStr = await _secureStorage.read(key: 'count');
    final current = int.tryParse(countStr ?? '0') ?? 0;
    final newCount = current + 1;
    await _secureStorage.write(key: 'count', value: newCount.toString());

    developer.log('Updated count from $current to $newCount', name: 'ALARM');

    // Try to communicate with main isolate
    final sendPort = IsolateNameServer.lookupPortByName('alarm_isolate_port');
    if (sendPort != null) {
      sendPort.send({
        'type': 'alarm_triggered',
        'count': newCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      developer.log('Sent message to main isolate', name: 'ALARM');
    } else {
      developer.log('SendPort not found in isolate registry', name: 'ALARM');
    }

    // Alternative: Try to trigger a notification or other visible action
    developer.log('=== ALARM CALLBACK COMPLETED ===', name: 'ALARM');
  } catch (e, stackTrace) {
    developer.log('Alarm callback error: $e',
        error: e, stackTrace: stackTrace, name: 'ALARM');
  }
}

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize alarm manager
  await AndroidAlarmManager.initialize();

  runApp(const AlarmApp());
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AlarmScreen(),
    );
  }
}

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with WidgetsBindingObserver {
  int _counter = 0;
  bool _permissionsGranted = false;
  late ReceivePort _receivePort;
  List<String> _logs = [];
  int? _lastAlarmId;

  // Secure storage instance
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupIsolateComm();
    _checkPermissions();
    _loadCounter();
    _loadLogs();

    // Periodically check for updates (fallback method)
    _startPeriodicCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receivePort.close();
    IsolateNameServer.removePortNameMapping('alarm_isolate_port');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, check for updates
      _loadCounter();
    }
  }

  void _setupIsolateComm() {
    _receivePort = ReceivePort();

    // Register the port
    bool registered = IsolateNameServer.registerPortWithName(
        _receivePort.sendPort, 'alarm_isolate_port');

    _addLog('Port registration: ${registered ? 'SUCCESS' : 'FAILED'}');

    // Listen for messages
    _receivePort.listen((dynamic data) {
      _addLog('Received isolate message: $data');

      if (data is Map && data['type'] == 'alarm_triggered') {
        setState(() {
          _counter = data['count'] ?? 0;
        });
        _addLog('UI updated with count: ${data['count']}');
      }
    });
  }

  void _startPeriodicCheck() {
    // Check every 2 seconds for updates (fallback method)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _loadCounter();
        _startPeriodicCheck();
      }
    });
  }

  Future<void> _checkPermissions() async {
    try {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      final notificationStatus = await Permission.notification.status;

      setState(() {
        _permissionsGranted =
            alarmStatus.isGranted && notificationStatus.isGranted;
      });

      _addLog('Alarm permission: ${alarmStatus.name}');
      _addLog('Notification permission: ${notificationStatus.name}');
    } catch (e) {
      _addLog('Permission check error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final alarmStatus = await Permission.scheduleExactAlarm.request();
      final notificationStatus = await Permission.notification.request();

      setState(() {
        _permissionsGranted =
            alarmStatus.isGranted && notificationStatus.isGranted;
      });

      _addLog(
          'Permissions requested - Alarm: ${alarmStatus.name}, Notification: ${notificationStatus.name}');
    } catch (e) {
      _addLog('Permission request error: $e');
    }
  }

  Future<void> _loadCounter() async {
    try {
      final countStr = await _secureStorage.read(key: 'count');
      final savedCount = int.tryParse(countStr ?? '0') ?? 0;

      if (_counter != savedCount) {
        setState(() {
          _counter = savedCount;
        });
        _addLog('Counter loaded from secure storage: $savedCount');
      }
    } catch (e) {
      _addLog('Load counter error: $e');
    }
  }

  Future<void> _scheduleAlarm() async {
    try {
      _lastAlarmId = Random().nextInt(100000);

      _addLog('Scheduling alarm ID: $_lastAlarmId');

      final success = await AndroidAlarmManager.oneShot(
        const Duration(seconds: 10),
        _lastAlarmId!,
        alarmCallback,
        exact: true,
        wakeup: true,
        alarmClock: true,
        allowWhileIdle: true,
      );

      _addLog('Alarm scheduled: ${success ? 'SUCCESS' : 'FAILED'}');

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alarm $_lastAlarmId scheduled for 10 seconds'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _addLog('Schedule alarm error: $e');
    }
  }

  Future<void> _cancelAlarm() async {
    if (_lastAlarmId != null) {
      try {
        await AndroidAlarmManager.cancel(_lastAlarmId!);
        _addLog('Cancelled alarm ID: $_lastAlarmId');
      } catch (e) {
        _addLog('Cancel alarm error: $e');
      }
    }
  }

  Future<void> _resetCounter() async {
    try {
      await _secureStorage.write(key: 'count', value: '0');
      setState(() {
        _counter = 0;
      });
      _addLog('Counter reset to 0 in secure storage');
    } catch (e) {
      _addLog('Reset counter error: $e');
    }
  }

  Future<void> _clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
      setState(() {
        _counter = 0;
      });
      _addLog('All secure storage data cleared');
    } catch (e) {
      _addLog('Clear secure storage error: $e');
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 20) {
        _logs = _logs.take(20).toList();
      }
    });
    developer.log(message, name: 'UI');
  }

  Future<void> _saveLogs() async {
    try {
      // Convert logs list to a simple string format (using ||| as separator)
      final logsString = _logs.join('|||');
      await _secureStorage.write(key: 'logs', value: logsString);
      developer.log('Saved ${_logs.length} logs to secure storage', name: 'UI');
    } catch (e) {
      developer.log('Save logs error: $e', name: 'UI');
    }

    try {
      final countStr = await _secureStorage.read(key: 'count');
      final savedCount = int.tryParse(countStr ?? '0') ?? 0;

      if (_counter != savedCount) {
        setState(() {
          _counter = savedCount;
        });
        _addLog('Counter loaded from secure storage: $savedCount');
      }
    } catch (e) {
      _addLog('Load counter error: $e');
    }
  }

  Future<void> _loadLogs() async {
    try {
      final logsJson = await _secureStorage.read(key: 'logs');
      if (logsJson != null && logsJson.isNotEmpty) {
        // Parse the JSON string back to List<String>
        final List<dynamic> logsList =
            (logsJson.split('|||')).where((log) => log.isNotEmpty).toList();
        setState(() {
          _logs = logsList.cast<String>();
        });
        developer.log('Loaded ${_logs.length} logs from secure storage',
            name: 'UI');
      }
    } catch (e) {
      developer.log('Load logs error: $e', name: 'UI');
      // If there's an error loading logs, start with empty list
      setState(() {
        _logs = [];
      });
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });

    _saveLogs();
    developer.log('Logs cleared and saved to secure storage', name: 'UI');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Manager Test - Secure Storage'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Counter Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('Alarms Triggered',
                        style: TextStyle(fontSize: 18)),
                    Text(
                      '$_counter',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Stored securely',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Controls
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_permissionsGranted) ...[
                  ElevatedButton(
                    onPressed: _scheduleAlarm,
                    child: const Text('Schedule Alarm (10s)'),
                  ),
                  ElevatedButton(
                    onPressed: _cancelAlarm,
                    child: const Text('Cancel Alarm'),
                  ),
                ] else
                  ElevatedButton(
                    onPressed: _requestPermissions,
                    child: const Text('Grant Permissions'),
                  ),
                ElevatedButton(
                  onPressed: _loadCounter,
                  child: const Text('Refresh Counter'),
                ),
                ElevatedButton(
                  onPressed: _resetCounter,
                  child: const Text('Reset Counter'),
                ),
                ElevatedButton(
                  onPressed: _clearAllSecureData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear All Data'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status
            Column(
              children: [
                Text(
                  'Permissions: ${_permissionsGranted ? 'GRANTED' : 'MISSING'}',
                  style: TextStyle(
                    color: _permissionsGranted ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Storage: Flutter Secure Storage (Encrypted)',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Logs
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Logs',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: _clearLogs,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 2.0),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                  fontSize: 12, fontFamily: 'monospace'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
