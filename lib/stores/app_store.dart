import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStore with ChangeNotifier {
  final String _themeKey = "theme";
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _reminder = true;
  ThemeMode _theme = ThemeMode.system;

  ThemeMode get theme => _theme;
  bool get reminder => _reminder;

  Future<void> initialize() async {
    try {
      final reminder = await _storage.read(key: "reminder");
      final theme = await _storage.read(key: _themeKey);

      _reminder = reminder == "false" ? false : true; // default true
      _theme = theme == 'dark'
          ? ThemeMode.dark
          : theme == 'light'
              ? ThemeMode.light
              : ThemeMode.system;
    } catch (e) {
      _theme = ThemeMode.system;
    } finally {
      notifyListeners();
    }
  }

  Future<void> switchTheme() async {
    _theme = _theme == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _storage.write(
        key: _themeKey, value: _theme == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> set({bool? reminder}) async {
    await _store("reminder", reminder, (value) {
      _reminder = value;
      return value ? "true" : "false";
    });

    notifyListeners();
  }

  // ignore: unused_element
  Future<void> _store<T>(String key, T? value, String Function(T) cb) async {
    if (value != null) {
      await _storage.write(key: key, value: cb(value));
    }
  }

  // ignore: unused_element
  Future<void> _delete(String key) async {
    await _storage.delete(key: key);
  }
}
