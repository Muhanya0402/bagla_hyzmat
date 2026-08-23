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
    if (kDebugMode) debugPrint('🗺️  TourManager инициализирован');
  }

  /// Установить активного пользователя. Все последующие чтения/записи
  /// будут идти в namespace `tour_passed_<userId>_<screen>`. Вызывается
  /// из AuthProvider.setUserData и loadUserData.
  void setUserId(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    // Не логируем userId в release — PII.
    if (kDebugMode) {
      debugPrint('🗺️  TourManager.userId → "${userId.isEmpty ? "<empty>" : "set"}"');
    }
  }

  /// Ключ prefs, где лежит id текущего пользователя.
  static const _kUserIdKey = 'user_id';

  /// Активный namespace пользователя.
  ///
  /// ⚠️ Берём его из prefs, а НЕ из поля `_userId`. Поле требует, чтобы
  /// кто-то вызвал [setUserId] в правильный момент, и при рассинхроне
  /// `markSeen` писал один ключ, а `isSeen` читал другой — гид показывался
  /// заново после повторного входа. prefs — единственный источник правды:
  /// он один и тот же в обоих вызовах, независимо от порядка инициализации.
  /// Поле остаётся запасным вариантом (например, до записи prefs).
  String get _activeUserId {
    final fromPrefs = _prefs?.getString(_kUserIdKey) ?? '';
    return fromPrefs.isNotEmpty ? fromPrefs : _userId;
  }

  /// true — тур на этом экране уже был показан/пропущен для текущего user'а.
  ///
  /// ⚠️ T5-fix: если userId задан, легаси-глобальный ключ
  /// (`tour_passed_<screen>` без uid) ТОЖЕ считается «seen». Это закрывает
  /// race на cold-start: если `markSeen` успел записать глобальный ключ ДО
  /// того как появился userId, теперь мы его уважаем и не показываем тур
  /// повторно.
  bool isSeen(String screenKey) {
    final p = _prefs;
    if (p == null) return false;
    final uid = _activeUserId;
    final scoped =
        p.getBool(TourKeys.prefsKey(screenKey, userId: uid)) ?? false;
    if (uid.isEmpty) {
      if (kDebugMode) debugPrint('🗺️  isSeen[$screenKey] = $scoped');
      return scoped;
    }
    final legacy = p.getBool(TourKeys.prefsKey(screenKey)) ?? false;
    final seen = scoped || legacy;
    if (kDebugMode) debugPrint('🗺️  isSeen[$screenKey] = $seen');
    return seen;
  }

  /// Вызывается при завершении или пропуске тура.
  ///
  /// T5-fix: при наличии userId пишем account-scoped ключ И заодно чистим
  /// возможный легаси-глобальный ключ, чтобы не оставлять мусор в prefs.
  Future<void> markSeen(String screenKey) async {
    final p = _prefs;
    if (p == null) return;
    final uid = _activeUserId;
    await p.setBool(TourKeys.prefsKey(screenKey, userId: uid), true);
    if (uid.isNotEmpty) {
      // Подчищаем легаси-ключ если он образовался во время cold-start race.
      await p.remove(TourKeys.prefsKey(screenKey));
    }
    if (kDebugMode) debugPrint('🗺️  markSeen[$screenKey] → сохранено');
  }

  /// Сброс одного экрана (кнопка «Повторить гид» в настройках).
  Future<void> resetScreen(String screenKey) async {
    final p = _prefs;
    if (p == null) return;
    await p.remove(TourKeys.prefsKey(screenKey, userId: _activeUserId));
    // Сбрасываем и легаси-ключ — иначе replay не сработает (isSeen вернёт
    // true по легаси-ключу).
    await p.remove(TourKeys.prefsKey(screenKey));
    if (kDebugMode) debugPrint('🗺️  resetScreen[$screenKey] → сброшено');
  }

  /// Полный сброс туров **только для текущего пользователя**.
  /// Туры других аккаунтов на устройстве не трогаем.
  Future<void> resetAllForCurrentUser() async {
    final keys = _prefs?.getKeys() ?? {};
    final uid = _activeUserId;
    // ⚠️ При пустом namespace префикс совпал бы со ВСЕМИ тур-ключами и
    // стёр бы прогресс других аккаунтов устройства. Чистим только глобальные.
    final namespace = uid.isEmpty
        ? TourKeys.prefsPrefix
        : '${TourKeys.prefsPrefix}${uid}_';
    final onlyGlobal = uid.isEmpty;
    final tourKeys = keys
        .where((k) => k.startsWith(namespace))
        // Глобальный ключ — без второго '_'-сегмента с id.
        .where((k) => !onlyGlobal ||
            !RegExp(r'^' + TourKeys.prefsPrefix + r'\d+_').hasMatch(k))
        .toList();
    for (final k in tourKeys) {
      await _prefs?.remove(k);
    }
    if (kDebugMode) {
      debugPrint('🗺️  resetAllForCurrentUser → сброшено ${tourKeys.length} туров');
    }
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
    if (kDebugMode) {
      debugPrint('🗺️  restoreSnapshot → восстановлено ${snapshot.length} ключей');
    }
  }

  // T7-fix: удалён вводящий в заблуждение `resetAll()` — его docstring
  // обещал «удалить ВСЕ туры всех пользователей», но реализация просто
  // делегировала в resetAllForCurrentUser(). Метод нигде не вызывался.
  // Нужен полный сброс — используй resetAllForCurrentUser() явно.
}
