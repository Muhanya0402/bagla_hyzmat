import 'dart:async';

import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/secure_token_store.dart';
import 'package:bagla/main.dart' show navigatorKey;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton-обёртка над Dio с automatic token refresh.
///
/// Поведение:
///   1. Каждый запрос подписывается текущим `auth_token` из prefs.
///   2. Если сервер вернул 401 (протухший access-token) — запускаем refresh
///      через `/auth/refresh`. Если refresh успешен — повторяем оригинальный
///      запрос с новым токеном. Если refresh упал по auth-причине — чистим
///      токены, редиректим на /login (сетевые осечки сессию не убивают).
///      403 (нет прав) НЕ триггерит refresh — это permission, не auth.
///   3. **Refresh-singleflight**: если другой запрос уже refresh'ит, мы ждём
///      его completion (через `Completer`), а не запускаем второй параллельный.
///   4. **Timeout**: refresh-запрос ограничен 10 сек. Если висит — все
///      ожидающие отваливаются с ошибкой, юзер видит логин.
///   5. **Никаких silent stuck-completer'ов**: если refresh упал, мы
///      `completer.completeError(err)` для каждого ожидающего, не оставляем
///      их подвешенными в памяти.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  static const String _baseUrl = BaseUrl.url;

  // ── Refresh singleflight state ─────────────────────────────────────────
  // Если `_refreshFuture != null` — refresh уже идёт. Новые 401-запросы
  // ждут его через `await _refreshFuture`, не запускают параллельный.
  Future<void>? _refreshFuture;
  // Timeout на один refresh-запрос. Хардкод 10 сек — больше чем connect
  // timeout (10 сек) делать не стоит, юзер не должен ждать 30 сек на «спиннере».
  static const _refreshTimeout = Duration(seconds: 10);
  /// За сколько до истечения access-token'а мы проактивно refresh'имся.
  /// 60 сек даёт запас на медленных сетях — refresh успеет завершиться
  /// раньше, чем токен реально протухнет, и 401-цикл вообще не сработает.
  static const _proactiveRefreshThreshold = Duration(seconds: 60);

  /// Cooldown между proactive refresh'ами.
  /// **Зачем:** если Directus отдаёт access-token с TTL короче, чем
  /// `_proactiveRefreshThreshold` (например, TTL=15 сек), то без cooldown'а
  /// каждый следующий запрос видел бы свежий токен как «почти истёк» и
  /// триггерил новый refresh → бесконечный loop (наблюдалось 1 раз/сек+).
  ///
  /// Cooldown гарантирует «не чаще раза в N сек» вне зависимости от
  /// серверного TTL. Если токен реально протухнет внутри cooldown'а,
  /// fallback-путь через 401-retry всё равно отработает.
  static const _refreshCooldown = Duration(seconds: 30);
  DateTime? _lastRefreshAt;

  /// Колбэк показа toast'а пользователю при принудительном logout
  /// (например, refresh-token протух). Задаётся снаружи (main.dart),
  /// чтобы ApiClient не зависел от MaterialApp/ScaffoldMessenger.
  void Function()? onSessionExpired;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Не вмешиваемся в сам /auth/refresh — иначе рекурсия.
          final isRefreshCall =
              options.path.contains('/auth/refresh');

          if (!isRefreshCall) {
            // Proactive refresh: если до истечения <60 сек И мы не
            // refresh'ились в течение последних `_refreshCooldown`,
            // обновляем токен ДО отправки запроса. Cooldown спасает от
            // loop'а если Directus отдаёт короткие токены.
            final ttl = await SecureTokenStore.instance
                .getAccessTokenTimeToExpiry();
            final since = _lastRefreshAt == null
                ? null
                : DateTime.now().difference(_lastRefreshAt!);
            final cooledDown = since == null || since >= _refreshCooldown;
            if (ttl != null &&
                ttl <= _proactiveRefreshThreshold &&
                cooledDown) {
              try {
                _refreshFuture ??= _runRefresh();
                await _refreshFuture;
              } catch (_) {
                // refresh упал — продолжаем без него, пусть запрос
                // получит 401 и interceptor обработает как обычно.
              }
            }
          }

          // Токен из secure storage (Keychain/Keystore).
          final token = await SecureTokenStore.instance.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final statusCode = e.response?.statusCode;

          // Только 401 = протухший/невалидный access-token → refresh.
          // 403 в Directus = «аутентифицирован, но нет прав» (permission) —
          // refresh не поможет, а раньше любой 403 (напр. lean-fields в
          // getOrders или закрытый ресурс) дёргал refresh и при его осечке
          // выкидывал юзера из аккаунта (#7). Пропускаем 403 наверх —
          // caller обработает (getOrders сам ретраит с `fields=*`).
          // Также не трогаем сам /auth/refresh, чтобы не зациклиться.
          if (statusCode != 401 ||
              e.requestOptions.path.contains('/auth/refresh')) {
            return handler.next(e);
          }

          // **Cooldown в 401-path** — защита от refresh-loop'а.
          // Если refresh был меньше `_refreshCooldown` назад, и мы СНОВА
          // получили 401, значит:
          //   - либо это параллельный запрос, что начался ДО refresh'а и
          //     успел протухнуть к моменту прихода на сервер (race-условие)
          //   - либо Directus отдаёт TTL короче чем network roundtrip
          //
          // В обоих случаях **не делаем повторный refresh** — это бы
          // зациклилось. Просто пропагируем 401 наверх — caller
          // (`getOrders().catchError(...)` и т.д.) сам обработает.
          //
          // НЕ force logout здесь — пользователь только что вошёл, не надо
          // паниковать на каждом race-условии. Если refresh реально мёртв,
          // следующий запрос **вне** cooldown'а попытается refresh снова
          // и при ошибке кинет на login через `_runRefresh.catch`.
          if (_lastRefreshAt != null &&
              DateTime.now().difference(_lastRefreshAt!) <
                  _refreshCooldown) {
            if (kDebugMode) {
              debugPrint(
                '🔑 Got 401 within cooldown — propagating error without refresh. '
                'Если повторяется — проверь ACCESS_TOKEN_TTL в Directus.',
              );
            }
            return handler.next(e);
          }

          try {
            // Singleflight: если refresh ещё не идёт — запускаем,
            // если уже идёт — просто ждём его.
            _refreshFuture ??= _runRefresh();
            await _refreshFuture;

            // refresh успешен → повторяем оригинальный запрос с новым токеном
            final retryResponse = await _retry(e.requestOptions);
            return handler.resolve(retryResponse);
          } catch (refreshErr) {
            // refresh упал → токены уже почищены внутри _runRefresh,
            // нас перебросило на login. Возвращаем оригинальную 401-ошибку
            // (или новую DioException — тут не принципиально).
            return handler.next(e);
          }
        },
      ),
    );
  }

  /// Выполняет /auth/refresh и сохраняет новые токены.
  /// Бросает исключение если что-то пошло не так — caller (interceptor)
  /// обработает редирект на логин.
  ///
  /// Singleflight гарантия: вызывается под protect `_refreshFuture`, второй
  /// конкуррентный запрос не возможен.
  Future<void> _runRefresh() async {
    try {
      final refreshToken = await SecureTokenStore.instance.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('No refresh token');
      }

      // Отдельный Dio без interceptor'а — иначе при 401 на самом refresh
      // мы бы попали в рекурсию.
      final refreshDio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: _refreshTimeout,
        receiveTimeout: _refreshTimeout,
      ));

      final response = await refreshDio
          .post(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
          )
          .timeout(_refreshTimeout);

      final data = response.data['data'];
      final newAccessToken = data?['access_token'] as String?;
      final newRefreshToken = data?['refresh_token'] as String?;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        throw Exception('Refresh response without access_token');
      }

      await SecureTokenStore.instance.setTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      _lastRefreshAt = DateTime.now();
      if (kDebugMode) {
        debugPrint('🔑 Token refreshed successfully');
        // Диагностика: если Directus отдаёт токены с очень коротким TTL,
        // proactive refresh будет ловить каждый запрос. Это симптом
        // мисконфига сервера. Лог даёт это заметить.
        final newTtl = SecureTokenStore.parseJwtExpiry(newAccessToken)
            ?.difference(DateTime.now());
        if (newTtl != null && newTtl <= _proactiveRefreshThreshold) {
          debugPrint(
            '⚠️ New access-token TTL = ${newTtl.inSeconds}s, '
            'short for proactive threshold ${_proactiveRefreshThreshold.inSeconds}s. '
            'Cooldown protects from loop, но проверь ACCESS_TOKEN_TTL в Directus.',
          );
        }
      }
    } catch (err) {
      if (kDebugMode) debugPrint('🔑 Token refresh FAILED: $err');
      // #7: выкидываем из аккаунта ТОЛЬКО при реальном auth-failure
      // (сервер сказал 401/403 на /auth/refresh, нет refresh-token'а,
      // битый ответ). При транзиентной сетевой ошибке (timeout, обрыв
      // соединения) refresh-token ещё валиден — НЕ убиваем сессию, иначе
      // юзера выбрасывает при каждом флапе сети «в непонятный момент».
      if (_isFatalRefreshError(err)) {
        await _forceSessionExpired();
      }
      rethrow;
    } finally {
      // Освобождаем lock в любом случае — следующий 401-запрос сможет
      // запустить новый refresh (например, после успешного re-login'а).
      _refreshFuture = null;
    }
  }

  /// Отличает «фатальную» ошибку refresh'а (сессия реально мертва →
  /// logout) от транзиентной сетевой (refresh-token валиден → сессию
  /// сохраняем, запрос просто провалится и повторится позже).
  ///
  ///   - DioException c ответом сервера 401/403 → refresh-token невалиден
  ///     (фатально).
  ///   - DioException без ответа (timeout / connectionError / etc.) →
  ///     сетевая проблема (НЕ фатально).
  ///   - Прочие DioException c кодом (500, 502, ...) → серверная проблема,
  ///     НЕ вина токена (НЕ фатально).
  ///   - Не-Dio Exception (нет refresh-token'а / битый ответ без
  ///     access_token) → сессию восстановить нечем (фатально).
  bool _isFatalRefreshError(Object err) {
    if (err is DioException) {
      final sc = err.response?.statusCode;
      return sc == 401 || sc == 403;
    }
    return true;
  }

  /// Полностью завершить текущую сессию: чистим токены, перебрасываем
  /// на /login, показываем toast пользователю.
  ///
  /// Вызывается из:
  ///   - `_runRefresh` catch (refresh упал)
  ///   - onError 401-handler если в cooldown'е получили 401 (loop guard)
  ///
  /// **Идемпотентно** — повторный вызов безопасен (после первого clear
  /// токенов нет, навигация на /login со /login это no-op).
  Future<void> _forceSessionExpired() async {
    // ⚠️ Best-effort server-side revoke ДО локального clear — если
    // refresh-token валиден (но access протух), сервер должен пометить
    // его как использованный. Иначе украденный refresh-token живёт до
    // своего собственного expiry даже после нашего «logout».
    //
    // Silent fail — главное локально очистить. Сетевые проблемы не должны
    // блокировать user-flow.
    await SecureTokenStore.instance.revokeOnServer(_baseUrl);

    await SecureTokenStore.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
    // Уведомляем пользователя что сессия истекла — иначе silent push
    // на /login выглядит как баг приложения. Хук подключается в main.dart
    // через global ScaffoldMessengerKey.
    onSessionExpired?.call();
  }

  Future<Response> _retry(RequestOptions requestOptions) async {
    final token = await SecureTokenStore.instance.getAccessToken();

    final options = Options(
      method: requestOptions.method,
      headers: {...requestOptions.headers, 'Authorization': 'Bearer $token'},
    );

    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}
