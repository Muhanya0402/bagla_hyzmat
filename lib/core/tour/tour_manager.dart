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
  // Текущий пользователь — нужен для account-scoped ключей.
  // Пустая строка → legacy глобальный режим (до логина).
  String _userId = '';

  /// Должен быть вызван до любого чтения состояния.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    debugPrint('🗺️  TourManager инициализирован');
  }

  /// Установить активного пользователя. Все последующие чтения/записи
  /// будут идти в namespace `tour_passed_<userId>_<screen>`. Вызывается
  /// из AuthProvider.setUserData и loadUserData.
  void setUserId(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    debugPrint('🗺️  TourManager.userId → "${userId.isEmpty ? "<empty>" : userId}"');
  }

  /// true — тур на этом экране уже был показан/пропущен для текущего user'а.
  bool isSeen(String screenKey) {
    final seen =
        _prefs?.getBool(TourKeys.prefsKey(screenKey, userId: _userId)) ?? false;
    debugPrint('🗺️  isSeen[$screenKey | uid=$_userId] = $seen');
    return seen;
  }

  /// Вызывается при завершении или пропуске тура.
  Future<void> markSeen(String screenKey) async {
    await _prefs?.setBool(
      TourKeys.prefsKey(screenKey, userId: _userId),
      true,
    );
    debugPrint('🗺️  markSeen[$screenKey | uid=$_userId] → сохранено');
  }

  /// Сброс одного экрана (кнопка «Повторить гид» в настройках).
  Future<void> resetScreen(String screenKey) async {
    await _prefs?.remove(TourKeys.prefsKey(screenKey, userId: _userId));
    debugPrint('🗺️  resetScreen[$screenKey | uid=$_userId] → сброшено');
  }

  /// Полный сброс туров **только для текущего пользователя**.
  /// Туры других аккаунтов на устройстве не трогаем.
  Future<void> resetAllForCurrentUser() async {
    final keys = _prefs?.getKeys() ?? {};
    final namespace = _userId.isEmpty
        ? TourKeys.prefsPrefix
        : '${TourKeys.prefsPrefix}${_userId}_';
    final tourKeys = keys.where((k) => k.startsWith(namespace)).toList();
    for (final k in tourKeys) {
      await _prefs?.remove(k);
    }
    debugPrint(
      '🗺️  resetAllForCurrentUser[uid=$_userId] → сброшено ${tourKeys.length} туров',
    );
  }

  /// Все tour-ключи всех пользователей. Используется в AuthProvider/Repo
  /// для backup перед `prefs.clear()` в logout — чтобы сохранить чужие
  /// состояния.
  Map<String, bool> snapshotAllTourKeys() {
    final p = _prefs;
    if (p == null) return const {};
    final keys = p.getKeys().where((k) => k.startsWith(TourKeys.prefsPrefix));
    return {for (final k in keys) k: p.getBool(k) ?? false};
  }

  /// Восстановить snapshot после `prefs.clear()`.
  Future<void> restoreSnapshot(Map<String, bool> snapshot) async {
    final p = _prefs;
    if (p == null) return;
    for (final entry in snapshot.entries) {
      await p.setBool(entry.key, entry.value);
    }
    debugPrint('🗺️  restoreSnapshot → восстановлено ${snapshot.length} ключей');
  }

  /// Legacy API. Удалит ВСЕ туры всех пользователей. Использовать с осторожностью.
  Future<void> resetAll() async => resetAllForCurrentUser();
}
