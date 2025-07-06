import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlarmApp());
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm Manager Service Demo',
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
  final AlarmManagerService _alarmService = AlarmManagerService.instance;

  int _alarmCount = 0;
  bool _permissionsGranted = false;
  List<String> _logs = [];
  List<int> _activeAlarms = [];
  String _status = 'Ready';

  // Controllers untuk input
  final TextEditingController _durationController =
      TextEditingController(text: '10');
  final TextEditingController _intervalController =
      TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alarmService.dispose();
    _durationController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize alarm service
      await _alarmService.initialize(
        onAlarmTriggered: _onAlarmTriggered,
      );

      // Check permissions
      await _checkPermissions();

      // Load initial data
      await _refreshData();

      // Add initial log
      await _alarmService.addLog('App initialized successfully');

      setState(() {
        _status = 'Service initialized';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      await _alarmService.addLog('Initialization error: $e');
    }
  }

  void _onAlarmTriggered(Map<String, dynamic> data) {
    // Callback ketika alarm triggered
    setState(() {
      _alarmCount = data['count'] ?? 0;
      _status = 'Alarm triggered! Count: ${data['count']}';
    });

    // Show alarm dialog
    _showAlarmDialog(data);

    // Show snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Alarm ${data['alarmId']} triggered! Count: ${data['count']}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Add log
    _alarmService.addLog('Alarm ${data['alarmId']} triggered');

    // Refresh data
    _refreshData();
  }

  void _showAlarmDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔔 Alarm!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alarm ID: ${data['alarmId']}'),
            Text('Count: ${data['count']}'),
            Text('Sound: ${data['soundType'] ?? 'system_alarm'}'),
            Text(
                'Time: ${DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch).toString()}'),
            if (data['userData'] != null) ...[
              const SizedBox(height: 8),
              Text('Message: ${data['userData']['message'] ?? 'N/A'}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _stopCurrentAlarm();
              Navigator.of(context).pop();
            },
            child: const Text('Stop Alarm'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissions() async {
    try {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      final notificationStatus = await Permission.notification.status;

      setState(() {
        _permissionsGranted =
            alarmStatus.isGranted && notificationStatus.isGranted;
      });

      await _alarmService.addLog(
          'Permissions - Alarm: ${alarmStatus.name}, Notification: ${notificationStatus.name}');
    } catch (e) {
      await _alarmService.addLog('Permission check error: $e');
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

      await _alarmService.addLog(
          'Permissions requested - Alarm: ${alarmStatus.name}, Notification: ${notificationStatus.name}');
    } catch (e) {
      await _alarmService.addLog('Permission request error: $e');
    }
  }

  Future<void> _refreshData() async {
    final count = await _alarmService.getAlarmCount();
    final logs = await _alarmService.getLogs();
    final activeAlarms = _alarmService.activeAlarms;

    setState(() {
      _alarmCount = count;
      _logs = logs;
      _activeAlarms = activeAlarms;
    });
  }

  // Basic alarm scheduling methods
  Future<void> _scheduleOneShot() async {
    final duration = int.tryParse(_durationController.text) ?? 10;

    final success = await _alarmService.scheduleOneShot(
      duration: Duration(seconds: duration),
      exact: true,
      wakeup: true,
      alarmClock: true,
      allowWhileIdle: true,
      userData: {
        'type': 'one_shot',
        'duration': duration.toString(),
        'scheduled_at': DateTime.now().toString(),
        'message': 'Basic one-shot alarm',
      },
    );

    if (success) {
      await _alarmService.addLog('One-shot alarm scheduled for ${duration}s');
      setState(() {
        _status = 'One-shot alarm scheduled (${duration}s)';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('One-shot alarm scheduled for ${duration} seconds')),
      );
    } else {
      await _alarmService.addLog('Failed to schedule one-shot alarm');
      setState(() {
        _status = 'Failed to schedule one-shot alarm';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to schedule alarm')),
      );
    }

    _refreshData();
  }

  Future<void> _schedulePeriodic() async {
    final interval = int.tryParse(_intervalController.text) ?? 30;

    final success = await _alarmService.schedulePeriodic(
      period: Duration(seconds: interval),
      exact: false,
      wakeup: true,
      allowWhileIdle: true,
      userData: {
        'type': 'periodic',
        'interval': interval.toString(),
        'scheduled_at': DateTime.now().toString(),
        'message': 'Basic periodic alarm',
      },
    );

    if (success) {
      await _alarmService.addLog('Periodic alarm scheduled every ${interval}s');
      setState(() {
        _status = 'Periodic alarm scheduled (${interval}s)';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Periodic alarm scheduled every ${interval} seconds')),
      );
    } else {
      await _alarmService.addLog('Failed to schedule periodic alarm');
      setState(() {
        _status = 'Failed to schedule periodic alarm';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to schedule periodic alarm')),
      );
    }

    _refreshData();
  }

  // Sound-specific alarm scheduling methods
  Future<void> _scheduleSystemAlarm() async {
    final success = await _alarmService.scheduleOneShot(
      duration: const Duration(seconds: 5),
      soundType: 'system_alarm',
      vibrate: true,
      soundDuration: 30,
      userData: {'message': 'System alarm test'},
    );

    setState(() {
      _status = success ? 'System alarm scheduled (5s)' : 'Failed to schedule';
    });

    if (success) {
      await _alarmService.addLog('System alarm scheduled for 5s');
    }
    _refreshData();
  }

  Future<void> _scheduleNotificationSound() async {
    final success = await _alarmService.scheduleOneShot(
      duration: const Duration(seconds: 3),
      soundType: 'system_notification',
      vibrate: false,
      soundDuration: 10,
      userData: {'message': 'Notification sound test'},
    );

    setState(() {
      _status =
          success ? 'Notification sound scheduled (3s)' : 'Failed to schedule';
    });

    if (success) {
      await _alarmService.addLog('Notification sound scheduled for 3s');
    }
    _refreshData();
  }

  Future<void> _scheduleCustomAssetSound() async {
    final success = await _alarmService.scheduleOneShot(
      duration: const Duration(seconds: 8),
      soundType: 'custom_asset',
      customSoundPath:
          'sounds/custom_alarm.mp3', // Put your sound file in assets/sounds/
      volume: 0.8,
      vibrate: true,
      soundDuration: 15,
      userData: {'message': 'Custom asset sound test'},
    );

    setState(() {
      _status =
          success ? 'Custom asset sound scheduled (8s)' : 'Failed to schedule';
    });

    if (success) {
      await _alarmService.addLog('Custom asset sound scheduled for 8s');
    }
    _refreshData();
  }

  Future<void> _schedulePeriodicWithSound() async {
    final success = await _alarmService.schedulePeriodic(
      period: const Duration(minutes: 1),
      soundType: 'system_ringtone',
      vibrate: true,
      soundDuration: 20,
      userData: {'message': 'Periodic alarm every minute'},
    );

    setState(() {
      _status =
          success ? 'Periodic alarm scheduled (1min)' : 'Failed to schedule';
    });

    if (success) {
      await _alarmService
          .addLog('Periodic alarm with sound scheduled for 1min intervals');
    }
    _refreshData();
  }

  Future<void> _cancelAllAlarms() async {
    await _alarmService.cancelAllAlarms();
    await _alarmService.addLog('All alarms cancelled');
    setState(() {
      _status = 'All alarms cancelled';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All alarms cancelled')),
    );
    _refreshData();
  }

  Future<void> _stopCurrentAlarm() async {
    await _alarmService.stopAlarmSound();
    setState(() {
      _status = 'Alarm sound stopped';
    });
    await _alarmService.addLog('Alarm sound stopped manually');
  }

  Future<void> _resetCounter() async {
    await _alarmService.resetAlarmCount();
    await _alarmService.addLog('Alarm counter reset');
    setState(() {
      _status = 'Counter reset';
    });
    _refreshData();
  }

  Future<void> _clearLogs() async {
    await _alarmService.clearLogs();
    setState(() {
      _status = 'Logs cleared';
    });
    _refreshData();
  }

  Future<void> _clearAllData() async {
    await _alarmService.clearAllData();
    await _alarmService.addLog('All data cleared');
    setState(() {
      _status = 'All data cleared';
    });
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Manager Service Demo'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status and Counter Display
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('Alarms Triggered',
                        style: TextStyle(fontSize: 18)),
                    Text(
                      '$_alarmCount',
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                    Text(
                      'Active Alarms: ${_activeAlarms.length}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Status: $_status',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Basic Alarm Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Basic Alarms',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // One-shot alarm controls
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _durationController,
                            decoration: const InputDecoration(
                              labelText: 'Duration (seconds)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed:
                              _permissionsGranted ? _scheduleOneShot : null,
                          child: const Text('One-Shot'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Periodic alarm controls
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _intervalController,
                            decoration: const InputDecoration(
                              labelText: 'Interval (seconds)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed:
                              _permissionsGranted ? _schedulePeriodic : null,
                          child: const Text('Periodic'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sound-Specific Alarms
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sound Alarms',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _permissionsGranted
                                ? _scheduleSystemAlarm
                                : null,
                            icon: const Icon(Icons.alarm),
                            label: const Text('System Alarm\n(5s)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _permissionsGranted
                                ? _scheduleNotificationSound
                                : null,
                            icon: const Icon(Icons.notifications),
                            label: const Text('Notification\n(3s)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _permissionsGranted
                                ? _scheduleCustomAssetSound
                                : null,
                            icon: const Icon(Icons.music_note),
                            label: const Text('Custom Sound\n(8s)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _permissionsGranted
                                ? _schedulePeriodicWithSound
                                : null,
                            icon: const Icon(Icons.repeat),
                            label: const Text('Periodic Sound\n(1min)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Control Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Controls',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!_permissionsGranted)
                          ElevatedButton.icon(
                            onPressed: _requestPermissions,
                            icon: const Icon(Icons.security),
                            label: const Text('Grant Permissions'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange),
                          ),
                        ElevatedButton.icon(
                          onPressed: _refreshData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _stopCurrentAlarm,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Sound'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _activeAlarms.isNotEmpty
                              ? _cancelAllAlarms
                              : null,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel All'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                        ),
                        ElevatedButton.icon(
                          onPressed: _resetCounter,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset Counter'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _clearAllData,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Clear All Data'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Status Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _permissionsGranted
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              _permissionsGranted ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Permissions: ${_permissionsGranted ? 'GRANTED' : 'MISSING'}',
                          style: TextStyle(
                            color:
                                _permissionsGranted ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.lock, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Storage: Flutter Secure Storage (Encrypted)',
                          style: TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_activeAlarms.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Active Alarm IDs: ${_activeAlarms.join(', ')}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logs Section
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Logs (${_logs.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _clearLogs,
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 200,
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No logs yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[_logs.length -
                                  1 -
                                  index]; // Show newest first
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 2.0),
                                child: Text(
                                  log,
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

            const SizedBox(height: 80), // Extra space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        tooltip: 'Refresh Data',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

typedef AlarmCallback = void Function(Map<String, dynamic> data);

class AlarmManagerService {
  static AlarmManagerService? _instance;
  static AlarmManagerService get instance =>
      _instance ??= AlarmManagerService._();

  AlarmManagerService._();

  // Audio player instance
  static AudioPlayer? _audioPlayer;

  // Secure storage instance
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  final String _portName = 'alarm_isolate_port';
  final List<int> _activeAlarms = [];

  ReceivePort? _receivePort;
  AlarmCallback? _onAlarmTriggered;

  // Storage keys
  static const String _countKey = 'alarm_count';
  static const String _logsKey = 'alarm_logs';
  static const String _activeAlarmsKey = 'active_alarms';

  /// Initialize AlarmManagerService
  Future<void> initialize({AlarmCallback? onAlarmTriggered}) async {
    try {
      // Initialize Android Alarm Manager
      await AndroidAlarmManager.initialize();

      // Initialize audio player
      _audioPlayer = AudioPlayer();

      // Set callback
      _onAlarmTriggered = onAlarmTriggered;

      // Setup isolate communication
      await _setupIsolateComm();

      // Load active alarms from storage
      await _loadActiveAlarms();

      developer.log('AlarmManagerService initialized successfully',
          name: 'AlarmService');
    } catch (e) {
      developer.log('Failed to initialize AlarmManagerService: $e',
          name: 'AlarmService');
      rethrow;
    }
  }

  /// Setup isolate communication
  Future<void> _setupIsolateComm() async {
    _receivePort = ReceivePort();

    // Register port with unique name
    bool registered = IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort, _portName);

    if (!registered) {
      // If registration failed, try to remove old one and register again
      IsolateNameServer.removePortNameMapping(_portName);
      registered = IsolateNameServer.registerPortWithName(
          _receivePort!.sendPort, _portName);
    }

    developer.log(
        'Isolate port registration: ${registered ? 'SUCCESS' : 'FAILED'}',
        name: 'AlarmService');

    // Listen for messages from alarm callback
    _receivePort!.listen((dynamic data) {
      developer.log('Received isolate message: $data', name: 'AlarmService');

      if (data is Map<String, dynamic> && data['type'] == 'alarm_triggered') {
        // Play alarm sound and vibration
        _playAlarmSound(data);

        // Remove alarm ID from active list if one-shot
        if (data['isOneShot'] == true) {
          _activeAlarms.remove(data['alarmId']);
          _saveActiveAlarms();
        }

        // Call callback if exists
        _onAlarmTriggered?.call(data);
      }
    });
  }

  /// Play alarm sound and vibration
  Future<void> _playAlarmSound(Map<String, dynamic> alarmData) async {
    try {
      developer.log('Playing alarm sound...', name: 'AlarmService');

      // Get sound configuration from alarm data
      final soundType = alarmData['soundType'] ?? 'default';
      final volume =
          double.tryParse(alarmData['volume']?.toString() ?? '1.0') ?? 1.0;
      final vibrate = alarmData['vibrate'] ?? true;
      final duration =
          int.tryParse(alarmData['duration']?.toString() ?? '30') ?? 30;

      // Set audio player volume
      await _audioPlayer?.setVolume(volume);

      // Play alarm sound based on type
      switch (soundType) {
        case 'system_alarm':
          await _playSystemAlarmSound();
          break;
        case 'system_notification':
          await _playSystemNotificationSound();
          break;
        case 'system_ringtone':
          await _playSystemRingtoneSound();
          break;
        case 'custom':
          final customSoundPath = alarmData['customSoundPath'];
          if (customSoundPath != null) {
            await _playCustomSound(customSoundPath);
          } else {
            await _playSystemAlarmSound(); // Fallback
          }
          break;
        default:
          await _playSystemAlarmSound();
      }

      // Add vibration if enabled
      if (vibrate) {
        await _playVibration(duration);
      }

      // Stop alarm after specified duration
      await Future.delayed(Duration(seconds: duration));
      await stopAlarmSound();
    } catch (e) {
      developer.log('Error playing alarm sound: $e', name: 'AlarmService');
    }
  }

  /// Play system alarm sound
  Future<void> _playSystemAlarmSound() async {
    try {
      // Use system alarm sound
      await _audioPlayer?.play(AssetSource('sounds/system_alarm.mp3'));

      // Alternative: Use platform channel to play system alarm sound
      await _playSystemSoundViaChannel('alarm');
    } catch (e) {
      developer.log('Error playing system alarm sound: $e',
          name: 'AlarmService');
    }
  }

  /// Play system notification sound
  Future<void> _playSystemNotificationSound() async {
    try {
      await _audioPlayer?.play(AssetSource('sounds/system_notification.mp3'));
      await _playSystemSoundViaChannel('notification');
    } catch (e) {
      developer.log('Error playing system notification sound: $e',
          name: 'AlarmService');
    }
  }

  /// Play system ringtone sound
  Future<void> _playSystemRingtoneSound() async {
    try {
      await _audioPlayer?.play(AssetSource('sounds/system_ringtone.mp3'));
      await _playSystemSoundViaChannel('ringtone');
    } catch (e) {
      developer.log('Error playing system ringtone sound: $e',
          name: 'AlarmService');
    }
  }

  /// Play custom sound file
  Future<void> _playCustomSound(String soundPath) async {
    try {
      if (soundPath.startsWith('assets/')) {
        await _audioPlayer
            ?.play(AssetSource(soundPath.replaceFirst('assets/', '')));
      } else {
        await _audioPlayer?.play(DeviceFileSource(soundPath));
      }
    } catch (e) {
      developer.log('Error playing custom sound: $e', name: 'AlarmService');
    }
  }

  /// Play system sound via platform channel
  Future<void> _playSystemSoundViaChannel(String soundType) async {
    try {
      const platform = MethodChannel('alarm_manager/sounds');
      await platform.invokeMethod('play', {'type': soundType});
    } catch (e) {
      developer.log('Error playing system sound via channel: $e',
          name: 'AlarmService');
    }
  }

  /// Play vibration pattern
  Future<void> _playVibration(int durationSeconds) async {
    try {
      if (await Vibration.hasVibrator()) {
        // Create vibration pattern: vibrate for 1000ms, pause for 500ms, repeat
        final pattern = <int>[];
        for (int i = 0; i < durationSeconds; i += 2) {
          pattern.addAll([1000, 500]); // 1 second vibrate, 0.5 second pause
        }

        await Vibration.vibrate(pattern: pattern);
      }
    } catch (e) {
      developer.log('Error playing vibration: $e', name: 'AlarmService');
    }
  }

  /// Stop alarm sound and vibration
  Future<void> stopAlarmSound() async {
    try {
      await _audioPlayer?.stop();
      await Vibration.cancel();
      developer.log('Alarm sound stopped', name: 'AlarmService');
    } catch (e) {
      developer.log('Error stopping alarm sound: $e', name: 'AlarmService');
    }
  }

  /// Schedule one-shot alarm with sound options
  Future<bool> scheduleOneShot({
    required Duration duration,
    int? alarmId,
    bool exact = true,
    bool wakeup = true,
    bool alarmClock = true,
    bool allowWhileIdle = true,
    Map<String, dynamic>? userData,
    String soundType = 'system_alarm',
    double volume = 1.0,
    bool vibrate = true,
    int soundDuration = 30,
    String? customSoundPath,
  }) async {
    try {
      // Generate alarm ID if not provided
      alarmId ??= _generateAlarmId();

      // Prepare alarm data with sound configuration
      final alarmData = {
        ...?userData,
        'soundType': soundType,
        'volume': volume.toString(),
        'vibrate': vibrate,
        'duration': soundDuration.toString(),
        'customSoundPath': customSoundPath,
      };

      // Save alarm data
      await _secureStorage.write(
          key: 'alarm_data_$alarmId', value: _mapToString(alarmData));

      // Schedule alarm
      final success = await AndroidAlarmManager.oneShot(
        duration,
        alarmId,
        _alarmCallbackWrapper,
        exact: exact,
        wakeup: wakeup,
        alarmClock: alarmClock,
        allowWhileIdle: allowWhileIdle,
      );

      if (success) {
        _activeAlarms.add(alarmId);
        await _saveActiveAlarms();
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

  /// Schedule periodic alarm with sound options
  Future<bool> schedulePeriodic({
    required Duration period,
    int? alarmId,
    bool exact = false,
    bool wakeup = true,
    bool allowWhileIdle = true,
    Map<String, dynamic>? userData,
    String soundType = 'system_alarm',
    double volume = 1.0,
    bool vibrate = true,
    int soundDuration = 30,
    String? customSoundPath,
  }) async {
    try {
      // Generate alarm ID if not provided
      alarmId ??= _generateAlarmId();

      // Prepare alarm data with sound configuration
      final alarmData = {
        ...?userData,
        'soundType': soundType,
        'volume': volume.toString(),
        'vibrate': vibrate,
        'duration': soundDuration.toString(),
        'customSoundPath': customSoundPath,
      };

      // Save alarm data
      await _secureStorage.write(
          key: 'alarm_data_$alarmId', value: _mapToString(alarmData));

      // Schedule periodic alarm
      final success = await AndroidAlarmManager.periodic(
        period,
        alarmId,
        _alarmCallbackWrapper,
        exact: exact,
        wakeup: wakeup,
        allowWhileIdle: allowWhileIdle,
      );

      if (success) {
        _activeAlarms.add(alarmId);
        await _saveActiveAlarms();
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

  /// Cancel specific alarm
  Future<bool> cancelAlarm(int alarmId) async {
    try {
      await AndroidAlarmManager.cancel(alarmId);
      _activeAlarms.remove(alarmId);
      await _saveActiveAlarms();

      // Delete alarm data
      await _secureStorage.delete(key: 'alarm_data_$alarmId');

      developer.log('Alarm $alarmId cancelled successfully',
          name: 'AlarmService');
      return true;
    } catch (e) {
      developer.log('Error cancelling alarm $alarmId: $e',
          name: 'AlarmService');
      return false;
    }
  }

  /// Cancel all alarms
  Future<void> cancelAllAlarms() async {
    try {
      // Cancel all active alarms
      for (int alarmId in List.from(_activeAlarms)) {
        await cancelAlarm(alarmId);
      }

      // Stop any currently playing alarm sound
      await stopAlarmSound();

      developer.log('All alarms cancelled successfully', name: 'AlarmService');
    } catch (e) {
      developer.log('Error cancelling all alarms: $e', name: 'AlarmService');
    }
  }

  /// Get list of active alarm IDs
  List<int> get activeAlarms => List.unmodifiable(_activeAlarms);

  /// Check if specific alarm is active
  bool isAlarmActive(int alarmId) => _activeAlarms.contains(alarmId);

  /// Get alarm count from secure storage
  Future<int> getAlarmCount() async {
    try {
      final countStr = await _secureStorage.read(key: _countKey);
      return int.tryParse(countStr ?? '0') ?? 0;
    } catch (e) {
      developer.log('Error getting alarm count: $e', name: 'AlarmService');
      return 0;
    }
  }

  /// Reset alarm count
  Future<void> resetAlarmCount() async {
    try {
      await _secureStorage.write(key: _countKey, value: '0');
      developer.log('Alarm count reset to 0', name: 'AlarmService');
    } catch (e) {
      developer.log('Error resetting alarm count: $e', name: 'AlarmService');
    }
  }

  /// Add log entry
  Future<void> addLog(String message) async {
    try {
      final timestamp = DateTime.now().toString().substring(11, 19);
      final logEntry = '[$timestamp] $message';

      final existingLogs = await getLogs();
      existingLogs.insert(0, logEntry);

      // Keep only last 50 logs
      if (existingLogs.length > 50) {
        existingLogs.removeRange(50, existingLogs.length);
      }

      await _secureStorage.write(
          key: _logsKey, value: existingLogs.join('|||'));
      developer.log(message, name: 'AlarmService');
    } catch (e) {
      developer.log('Error adding log: $e', name: 'AlarmService');
    }
  }

  /// Get logs from secure storage
  Future<List<String>> getLogs() async {
    try {
      final logsStr = await _secureStorage.read(key: _logsKey);
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
  Future<void> clearLogs() async {
    try {
      await _secureStorage.delete(key: _logsKey);
      developer.log('All logs cleared', name: 'AlarmService');
    } catch (e) {
      developer.log('Error clearing logs: $e', name: 'AlarmService');
    }
  }

  /// Clear all data from secure storage
  Future<void> clearAllData() async {
    try {
      await _secureStorage.deleteAll();
      _activeAlarms.clear();
      developer.log('All secure storage data cleared', name: 'AlarmService');
    } catch (e) {
      developer.log('Error clearing all data: $e', name: 'AlarmService');
    }
  }

  /// Save active alarms to storage
  Future<void> _saveActiveAlarms() async {
    try {
      final alarmsStr = _activeAlarms.join(',');
      await _secureStorage.write(key: _activeAlarmsKey, value: alarmsStr);
    } catch (e) {
      developer.log('Error saving active alarms: $e', name: 'AlarmService');
    }
  }

  /// Load active alarms from storage
  Future<void> _loadActiveAlarms() async {
    try {
      final alarmsStr = await _secureStorage.read(key: _activeAlarmsKey);
      if (alarmsStr != null && alarmsStr.isNotEmpty) {
        _activeAlarms.clear();
        _activeAlarms.addAll(alarmsStr
            .split(',')
            .map((id) => int.tryParse(id) ?? 0)
            .where((id) => id > 0));
      }
    } catch (e) {
      developer.log('Error loading active alarms: $e', name: 'AlarmService');
    }
  }

  /// Generate unique alarm ID
  int _generateAlarmId() {
    return DateTime.now().millisecondsSinceEpoch % 100000000 +
        Random().nextInt(1000);
  }

  /// Convert Map to String
  String _mapToString(Map<String, dynamic> map) {
    return map.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  /// Dispose resources
  void dispose() {
    _audioPlayer?.dispose();
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping(_portName);
    developer.log('AlarmManagerService disposed', name: 'AlarmService');
  }
}

/// Wrapper callback function
@pragma('vm:entry-point')
void _alarmCallbackWrapper() async {
  developer.log('=== ALARM CALLBACK STARTED ===', name: 'AlarmCallback');

  try {
    // Update counter
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    final countStr = await storage.read(key: 'alarm_count');
    final current = int.tryParse(countStr ?? '0') ?? 0;
    final newCount = current + 1;
    await storage.write(key: 'alarm_count', value: newCount.toString());

    developer.log('Updated alarm count from $current to $newCount',
        name: 'AlarmCallback');

    // Get current alarm ID (this is a simplified approach)
    final currentAlarmId = DateTime.now().millisecondsSinceEpoch % 100000000;

    // Try to get alarm data for this alarm
    final alarmDataStr = await storage.read(key: 'alarm_data_$currentAlarmId');
    Map<String, dynamic> alarmData = {};
    if (alarmDataStr != null) {
      // Parse alarm data
      for (String pair in alarmDataStr.split('|')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          alarmData[parts[0]] = parts[1];
        }
      }
    }

    // Send message to main isolate
    final sendPort = IsolateNameServer.lookupPortByName('alarm_isolate_port');
    if (sendPort != null) {
      sendPort.send({
        'type': 'alarm_triggered',
        'alarmId': currentAlarmId,
        'count': newCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isOneShot': true,
        ...alarmData, // Include sound configuration
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
