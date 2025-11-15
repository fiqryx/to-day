import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

class Logger {
  static void log(String message, {String name = ''}) {
    // write need here like store to storage or anything about logs
    if (kDebugMode) {
      var timestamp = DateTime.now().toIso8601String();
      dev.log('[$timestamp] $message', name: name);
    }
  }
}
