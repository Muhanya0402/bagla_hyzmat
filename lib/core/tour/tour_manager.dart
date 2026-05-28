import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tour_keys.dart';

/// Singleton-сервис управления состоянием туров.
///
/// Инициализируй один раз в main() до runApp:
/// ```dart
/// await TourManager.instance.init();
/// ```
class TourManager {
  TourManager._();
  static final TourManager instance = TourManager._();

  SharedPreferences? _prefs;

  /// Должен быть вызван до любого чтения состояния.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    debugPrint('🗺️  TourManager инициализирован');
  }

  /// true — тур на этом экране уже был показан/пропущен.
  bool isSeen(String screenKey) {
    final seen = _prefs?.getBool(TourKeys.prefsKey(screenKey)) ?? false;
    debugPrint('🗺️  isSeen[$screenKey] = $seen');
    return seen;
  }

  /// Вызывается при завершении или пропуске тура.
  Future<void> markSeen(String screenKey) async {
    await _prefs?.setBool(TourKeys.prefsKey(screenKey), true);
    debugPrint('🗺️  markSeen[$screenKey] → сохранено');
  }

  /// Сброс одного экрана (кнопка «Повторить гид» в настройках).
  Future<void> resetScreen(String screenKey) async {
    await _prefs?.remove(TourKeys.prefsKey(screenKey));
    debugPrint('🗺️  resetScreen[$screenKey] → сброшено');
  }

  /// Полный сброс всех туров (например, при смене аккаунта).
  Future<void> resetAll() async {
    final keys = _prefs?.getKeys() ?? {};
    final tourKeys = keys.where((k) => k.startsWith('tour_passed_')).toList();
    for (final k in tourKeys) {
      await _prefs?.remove(k);
    }
    debugPrint('🗺️  resetAll → сброшено ${tourKeys.length} туров: $tourKeys');
  }
}
