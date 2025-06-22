import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_manager/flutter_ringtone_manager.dart';
import 'package:flutter_ringtone_manager/ios_system_sounds.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterRingtoneManager = FlutterRingtoneManager();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  OutlinedButton(
                      onPressed: () {
                        _flutterRingtoneManager.playRingtone();
                      },
                      child: const Text("Play Ringtone")),
                  OutlinedButton(
                      onPressed: () => {_flutterRingtoneManager.playAlarm()},
                      child: const Text('Play Alarm')),
                  OutlinedButton(
                      onPressed: () {
                        _flutterRingtoneManager.playNotification();
                      },
                      child: const Text("Play Notification")),
                  ElevatedButton(
                      onPressed: () {
                        _flutterRingtoneManager
                            .playAudioAsset("audio/test.mp3");
                      },
                      child: const Text("Play custom Asset")),
                  if (Platform.isIOS)
                    OutlinedButton(
                        onPressed: () {
                          _flutterRingtoneManager
                              .playIosSystemSoundByID(SystemSoundID.mailSent);
                        },
                        child: const Text("Play Notification")),
                  ElevatedButton(
                      onPressed: () => _flutterRingtoneManager.stop(),
                      style: ButtonStyle(
                          foregroundColor:
                              WidgetStateProperty.all(Colors.white),
                          backgroundColor:
                              WidgetStateProperty.all<Color>(Colors.red)),
                      child: const Text("Stop"))
                ],
              ))),
    );
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }
}
