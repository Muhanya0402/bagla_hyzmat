import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'is_dark_mode';

  ThemeProvider._();

  /// Синхронная фабрика — вызывается в main() после await SharedPreferences.
  /// ThemeProvider создаётся с уже известным значением ДО runApp(),
  /// что предотвращает "белую вспышку" при тёмной теме на холодном старте.
  factory ThemeProvider.fromPrefs(SharedPreferences prefs) {
    final p = ThemeProvider._();
    p._isDark = prefs.getBool(_key) ?? false;
    p._prefs  = prefs;
    return p;
  }

  late final SharedPreferences _prefs;
  bool _isDark = false;

  bool      get isDark    => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggle() => _set(!_isDark);

  Future<void> setDark(bool value) => _set(value);

  Future<void> _set(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    await _prefs.setBool(_key, value);
  }
}
