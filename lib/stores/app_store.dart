import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStore with ChangeNotifier {
  final String _themeKey = "theme";
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ThemeMode _theme = ThemeMode.system;

  ThemeMode get theme => _theme;

  Future<void> initialize() async {
    try {
      final theme = await _storage.read(key: _themeKey);
      _theme = theme == 'dark'
          ? ThemeMode.dark
          : theme == 'light'
              ? ThemeMode.light
              : ThemeMode.system;
      notifyListeners();
    } catch (e) {
      _theme = ThemeMode.system;
    }
  }

  Future<void> switchTheme() async {
    _theme = _theme == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _storage.write(
        key: _themeKey, value: _theme == ThemeMode.dark ? 'dark' : 'light');
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
