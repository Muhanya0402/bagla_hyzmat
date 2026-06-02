import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Безопасное хранилище access/refresh токенов.
///
/// **Зачем не SharedPreferences?**
/// SharedPreferences — это `<package>/shared_prefs/<file>.xml` в открытом
/// виде. Читается через `adb backup`, через root, через любой file-manager
/// после kernel exploit'а. Для финансовой части приложения (балансы жетонов)
/// — это unacceptable risk.
///
/// **Где хранятся теперь:**
///   - **iOS**: Keychain Services API — hardware-bound, недоступно даже
///     при jailbreak без passcode пользователя
///   - **Android**: EncryptedSharedPreferences (Jetpack Security) поверх
///     AndroidKeystore — ключи в TEE/StrongBox на новых девайсах
///
/// Все остальные prefs (`user_id`, `phone`, `name`, и т.д.) остаются в
/// обычном SharedPreferences — они не sensitive.
class SecureTokenStore {
  SecureTokenStore._();
  static final SecureTokenStore instance = SecureTokenStore._();

  static const _kAccessToken = 'auth_token';
  static const _kRefreshToken = 'refresh_token';
  /// Флаг в обычном prefs: "миграция уже выполнена". Без него каждый старт
  /// приложения пытался бы читать пустой prefs и плодить ложные сбросы.
  static const _kMigrationDone = 'secure_tokens_migrated_v1';

  // ── Конфигурация secure_storage ────────────────────────────────────────
  // На Android используем EncryptedSharedPreferences — это самый надёжный
  // путь без необходимости keystore-биндинга к биометрии.
  // На iOS — first_unlock — токены доступны после первой разблокировки
  // устройства (стандарт для background работы — FCM, WS reconnect).
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Broadcast-стрим изменений токенов.
  /// Слушатели (например, `AuthProvider`) получают сигнал когда токены
  /// были обновлены через `setTokens`/`setAccessToken`/`clear`, чтобы
  /// синхронизировать своё локально-кэшированное состояние и вызвать
  /// `notifyListeners`.
  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  Stream<void> get tokenChanges => _changes.stream;
  void _emitChange() {
    if (!_changes.isClosed) _changes.add(null);
  }

  // ── Public API ─────────────────────────────────────────────────────────

  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _kAccessToken);
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStore.getAccessToken: $e');
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _kRefreshToken);
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStore.getRefreshToken: $e');
      return null;
    }
  }

  Future<void> setTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    try {
      if (accessToken != null && accessToken.isNotEmpty) {
        await _storage.write(key: _kAccessToken, value: accessToken);
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storage.write(key: _kRefreshToken, value: refreshToken);
      }
      _emitChange();
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStore.setTokens: $e');
    }
  }

  Future<void> setAccessToken(String token) async {
    try {
      await _storage.write(key: _kAccessToken, value: token);
      _emitChange();
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStore.setAccessToken: $e');
    }
  }

  /// Стирает оба токена. Используется при:
  ///   - logout (включая server-side revoke)
  ///   - неуспешный refresh (interceptor чистит сессию)
  Future<void> clear() async {
    try {
      await _storage.delete(key: _kAccessToken);
      await _storage.delete(key: _kRefreshToken);
      _emitChange();
    } catch (e) {
      if (kDebugMode) debugPrint('SecureTokenStore.clear: $e');
    }
  }

  // ── JWT expiry detection ───────────────────────────────────────────────

  /// Декодирует payload JWT и возвращает время истечения access-token'а.
  ///
  /// Returns null если:
  ///   - токена нет в хранилище
  ///   - формат не JWT (нет трёх сегментов через `.`)
  ///   - payload не парсится как JSON
  ///   - claim `exp` отсутствует
  ///
  /// **Никаких сторонних пакетов** — JWT это просто base64url(JSON) и
  /// нам нужен только claim `exp` (Unix timestamp).
  Future<DateTime?> getAccessTokenExpiry() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return null;
    return parseJwtExpiry(token);
  }

  /// Идентичен `getAccessTokenExpiry`, но синхронный — для случая когда
  /// токен уже у нас в руках (например, сразу после refresh).
  /// Public для использования из ApiClient в диагностических логах.
  static DateTime? parseJwtExpiry(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;

      // base64url + padding (длина должна быть кратна 4).
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      return null;
    }
  }

  /// Сколько осталось до истечения текущего access-token'а.
  /// Returns `null` если токена нет или он невалидный.
  /// Returns `Duration.zero` (или отрицательную) если уже истёк.
  Future<Duration?> getAccessTokenTimeToExpiry() async {
    final exp = await getAccessTokenExpiry();
    if (exp == null) return null;
    return exp.difference(DateTime.now());
  }

  // ── Migration ──────────────────────────────────────────────────────────

  /// Одноразовая миграция токенов из SharedPreferences → secure storage.
  /// Вызывается в main() **до** любых API-запросов.
  ///
  /// После успешной миграции prefs-ключи удаляются — данные не дублируются.
  /// Флаг `_kMigrationDone` гарантирует что миграция выполнится **один раз**
  /// за всю жизнь установки приложения.
  Future<void> migrateFromPrefsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kMigrationDone) == true) return;

    final oldAccess = prefs.getString(_kAccessToken);
    final oldRefresh = prefs.getString(_kRefreshToken);

    if (oldAccess != null && oldAccess.isNotEmpty) {
      await setTokens(accessToken: oldAccess, refreshToken: oldRefresh);
      if (kDebugMode) {
        debugPrint('🔐 SecureTokenStore: migrated tokens from SharedPreferences');
      }
    }

    // Чистим старое место хранения — даже если токенов не было,
    // не хотим чтобы они там НИКОГДА не появились заново.
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.setBool(_kMigrationDone, true);
  }

  // ── Server-side revoke ─────────────────────────────────────────────────

  /// Отзывает refresh-token на стороне Directus (`POST /auth/logout`).
  /// Без этого refresh-token остаётся валидным до естественного истечения
  /// (по умолчанию 7 дней) — на украденном устройстве с backup'ом это
  /// серьёзная дыра.
  ///
  /// Лучше silent fail: если у сети упало или сервер не ответил, мы всё
  /// равно делаем local cleanup. Лучше залогаутить локально пользователя
  /// сразу, чем оставить его в неопределённом состоянии.
  ///
  /// **Использует отдельный Dio** — `ApiClient` имеет interceptor, который
  /// может зациклиться на 401-response от revoke'нутого токена.
  Future<void> revokeOnServer(String baseUrl) async {
    try {
      final refresh = await getRefreshToken();
      if (refresh == null || refresh.isEmpty) return;
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      await dio.post(
        '/auth/logout',
        data: {'refresh_token': refresh},
      );
      if (kDebugMode) debugPrint('🔐 Server-side token revoked');
    } catch (e) {
      // Не критично — мы всё равно почистим локально дальше.
      if (kDebugMode) debugPrint('🔐 revokeOnServer (silent fail): $e');
    }
  }
}
