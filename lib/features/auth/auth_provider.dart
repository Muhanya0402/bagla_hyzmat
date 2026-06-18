import 'dart:async';

import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/secure_token_store.dart';
import 'package:bagla/core/tour/tour_manager.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:bagla/features/notifications/active_orders/active_orders_notification.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bagla/features/notifications/push_notification_service.dart';

/// Тип последней ошибки авторизации — экраны решают, как её показать.
/// none        — операция прошла
/// network     — исключение во время запроса (нет сети / таймаут / сервер не отвечает)
/// invalidCode — server вернул user==null на verify (неверный OTP)
/// serverBusy  — sendOTP вернул success==false (rate limit / валидация на бэке)
enum AuthErrorKind { none, network, invalidCode, serverBusy }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  bool _isCodeSent = false;
  bool _isLoading = false;
  AuthErrorKind _lastErrorKind = AuthErrorKind.none;

  String _token = '';
  String _userId = '';
  String _name = '';
  String _surname = '';
  String _phone = '';
  String _address = '';
  String _districtId = '';
  String _etraptId = '';
  String _provinceId = '';

  // Лейблы локации магазина — двуязычные.
  // Нужны при создании заказа: поля `shop_adress` (RU) и `shop_adresstk`
  // (TK) формируются по принципу «<etrap> - <district>», аналогично
  // delivery-адресу. Раньше в `createOrder` отправлялось `auth.address`
  // в оба поля → реально TK-версия дублировала RU. AuthRepository уже
  // сохраняет эти лейблы в SharedPreferences при логине/refresh профиля
  // (`province_ru`, `province_tk`, `etrap_ru`, `etrap_tk`, `district_ru`,
  // `district_tk`) — мы их сюда подгружаем, чтобы UI/createOrder могли
  // строить адрес без отдельных prefs-чтений.
  String _provinceRu = '';
  String _provinceTk = '';
  String _etrapRu = '';
  String _etrapTk = '';
  String _districtRu = '';
  String _districtTk = '';
  String _role = 'client';
  String _status = 'pending';
  double _rating = 0.0;
  double _balancePoints = 0.0;
  double _walletBalance = 0.0;
  String _transportType = 'any';
  String _category = ''; // slug категории магазина (shop only)
  String _selfieFileId = ''; // UUID файла selfie_scan в Directus
  List<String> _rejectionReasons = const []; // коды отказа модератора
  /// true сразу после `setUserData()` из verify-flow. HomeScreen видит этот
  /// флаг и пропускает первый refreshProfile() — экономия одного HTTP'а.
  /// Сбрасывается через `consumeFreshProfileFlag()`.
  bool _hasFreshProfile = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isCodeSent => _isCodeSent;
  bool get isLoading => _isLoading;
  AuthErrorKind get lastErrorKind => _lastErrorKind;
  // ⚠️ НЕ выставляем `_token` через getter — токен должен жить только
  // внутри SecureTokenStore и ApiClient. Раньше тут был
  // `String get token => _token;` — теоретически любой виджет мог
  // случайно залогировать `auth.token`. Если когда-то понадобится
  // — читай через `SecureTokenStore.instance.getAccessToken()`.
  String get userId => _userId;
  String get name => _name;
  String get surname => _surname;
  String get phone => _phone;
  String get address => _address;
  String get districtId => _districtId;
  String get etraptId => _etraptId;
  String get provinceId => _provinceId;

  // Лейблы локации магазина.
  String get provinceRu => _provinceRu;
  String get provinceTk => _provinceTk;
  String get etrapRu => _etrapRu;
  String get etrapTk => _etrapTk;
  String get districtRu => _districtRu;
  String get districtTk => _districtTk;

  /// Адрес магазина в RU для поля `shop_adress` при создании заказа.
  /// Строится по тому же правилу, что delivery-адрес в create_order_screen:
  ///   - есть район        → `etrap - district`
  ///   - есть только etrap → `etrap`
  ///   - только province   → `province`
  /// Если все три пусты — возвращает `_address` как fallback (старое
  /// поведение, не ломаем legacy для случая когда `address` всё-таки есть).
  String get shopAddressRu {
    if (_districtRu.isNotEmpty && _etrapRu.isNotEmpty) {
      return '$_etrapRu - $_districtRu';
    }
    if (_etrapRu.isNotEmpty) return _etrapRu;
    if (_provinceRu.isNotEmpty) return _provinceRu;
    return _address;
  }

  /// То же что `shopAddressRu`, но на туркменском — для поля `shop_adresstk`.
  String get shopAddressTk {
    if (_districtTk.isNotEmpty && _etrapTk.isNotEmpty) {
      return '$_etrapTk - $_districtTk';
    }
    if (_etrapTk.isNotEmpty) return _etrapTk;
    if (_provinceTk.isNotEmpty) return _provinceTk;
    return _address;
  }
  String get role => _role.toLowerCase().trim();
  String get status => _status.toLowerCase().trim();

  // Производные предикаты (один источник истины для UI).
  bool get isCourier => role == 'courier';
  bool get isShop => role == 'shop' || role == 'business';
  bool get isClient => role == 'client';
  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isBanned => status == 'banned';
  bool get isPublished => status == 'published';
  bool get isRejected => status == 'rejected';

  /// Коды полей, которые модератор отметил для исправления.
  List<String> get rejectionReasons => List.unmodifiable(_rejectionReasons);

  /// Одноразовый getter: возвращает true и **сбрасывает** флаг.
  /// HomeScreen использует это чтобы пропустить избыточный refreshProfile
  /// сразу после успешного логина (профиль уже только что прилетел).
  bool consumeFreshProfileFlag() {
    if (!_hasFreshProfile) return false;
    _hasFreshProfile = false;
    return true;
  }

  /// Клиент, прошедший регистрацию, но ещё не выбравший роль.
  bool get needsRoleSelection => isClient && isPublished;

  /// Стоит ли пропускать обучающий тур экранов.
  /// Banned/pending пользователи получают громкие статус-баннеры — тур только
  /// отвлекает их от понимания, что аккаунт ограничен.
  bool get shouldSkipTour =>
      isBanned || isRejected || (isPending && (isCourier || isShop));
  double get rating => _rating;
  // int cast so widgets can do "${auth.balancePoints}" without ".0"
  double get balancePoints => _balancePoints;
  double get walletBalance => _walletBalance;
  String get transportType => _transportType;
  String get category => _category;
  String get selfieFileId => _selfieFileId;

  /// Подписка на изменения токенов в secure storage. Срабатывает при
  /// успешном refresh из ApiClient — мы синхронизируем локально-кэшированный
  /// `_token` и нотифицируем UI (раньше после refresh `_token` оставался
  /// stale до перезапуска приложения).
  StreamSubscription<void>? _tokenChangesSub;

  AuthProvider() {
    loadUserData();
    _tokenChangesSub = SecureTokenStore.instance.tokenChanges.listen((_) async {
      final fresh = await SecureTokenStore.instance.getAccessToken() ?? '';
      if (fresh == _token) return;
      _token = fresh;
      notifyListeners();
    });
  }

  // ── Load from SharedPrefs ──────────────────────────────────────────────────

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    // Токен из secure storage (Keychain/Keystore), не из prefs.
    _token = await SecureTokenStore.instance.getAccessToken() ?? '';
    _userId = prefs.getString('user_id') ?? '';
    _name = prefs.getString('name') ?? '';
    _surname = prefs.getString('surname') ?? '';
    _phone = prefs.getString('phone') ?? '';
    _address = prefs.getString('shop_address') ?? '';
    _districtId = prefs.getString('district_id') ?? '';
    _etraptId = prefs.getString('etrap_id') ?? '';
    _provinceId = prefs.getString('province_id') ?? '';
    // Лейблы пишутся в эти же prefs ключи из AuthRepository при логине
    // и refreshProfile — просто читаем их сюда. Если на момент входа в
    // приложение ключей нет (свежая установка / logout) — пустые строки,
    // shopAddressRu/Tk вернёт `_address` как fallback.
    _provinceRu = prefs.getString('province_ru') ?? '';
    _provinceTk = prefs.getString('province_tk') ?? '';
    _etrapRu = prefs.getString('etrap_ru') ?? '';
    _etrapTk = prefs.getString('etrap_tk') ?? '';
    _districtRu = prefs.getString('district_ru') ?? '';
    _districtTk = prefs.getString('district_tk') ?? '';
    // Whitelist на чтении из prefs — на случай если предыдущий setUserData
    // успел сохранить мусор (legacy).
    const allowedRolesL = {'courier', 'shop', 'business', 'client'};
    const allowedStatusesL = {'active', 'pending', 'banned', 'published', 'rejected'};
    final rawRoleL = prefs.getString('role') ?? 'client';
    _role = allowedRolesL.contains(rawRoleL) ? rawRoleL : 'client';
    final rawStatusL = prefs.getString('status') ?? 'pending';
    _status = allowedStatusesL.contains(rawStatusL) ? rawStatusL : 'pending';
    _rating = prefs.getDouble('rating') ?? 0.0;
    _balancePoints = prefs.getDouble('balance_points') ?? 0.0;
    _walletBalance = prefs.getDouble('wallet_balance') ?? 0.0;
    _transportType = prefs.getString('transport_type') ?? 'any';
    _category = prefs.getString('category') ?? '';
    _selfieFileId = prefs.getString('selfie_file_id') ?? '';
    _rejectionReasons = prefs.getStringList('rejection_reasons') ?? const [];

    if (_phone.isNotEmpty) phoneController.text = _phone;
    // Привязываем тур-namespace к загруженному userId.
    TourManager.instance.setUserId(_userId);
    notifyListeners();
  }

  // ── Refresh from server ────────────────────────────────────────────────────

  Future<void> refreshProfile() async {
    if (_phone.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _phone = prefs.getString('phone') ?? '';
    }
    if (_phone.isEmpty) return;

    try {
      final userData = await _authRepo.fetchProfileFromServer(_phone);
      if (userData != null) setUserData(userData);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Ошибка обновления профиля');
    }
  }

  // ── Set user data & persist ────────────────────────────────────────────────

  Future<void> setUserData(Map<String, dynamic> user) async {
    _token = user['access_token'] ?? user['token'] ?? _token;
    _userId =
        user['id']?.toString() ?? user['customer_ID']?.toString() ?? _userId;
    _name = user['name'] ?? '';
    _surname = user['surname'] ?? '';
    _phone = user['phone'] ?? _phone;
    _address = user['address'] ?? _address;
    // ⚠️ Whitelist для role/status — на случай если сервер вернёт
    // мусор или атакующий компрометирует ответ. Иначе любое значение
    // улетает в state и в prefs (например role='admin').
    const allowedRoles = {'courier', 'shop', 'business', 'client'};
    const allowedStatuses = {'active', 'pending', 'banned', 'published', 'rejected'};
    final rawRole = (user['role'] ?? 'client').toString().toLowerCase().trim();
    _role = allowedRoles.contains(rawRole) ? rawRole : 'client';
    final rawStatus = (user['status']?.toString() ?? 'pending').toLowerCase().trim();
    _status = allowedStatuses.contains(rawStatus) ? rawStatus : 'pending';
    _rating = (user['rating'] ?? 0.0).toDouble();
    _balancePoints = (user['balance_points'] ?? 0.0).toDouble();
    _walletBalance = (user['wallet_balance'] ?? 0.0).toDouble();
    _transportType = user['transport_type']?.toString() ?? 'any';
    // category может прийти как string slug или как Map (expanded m2o).
    final rawCat = user['category'];
    if (rawCat == null) {
      _category = '';
    } else if (rawCat is Map) {
      _category = (rawCat['id'] ?? '').toString();
    } else {
      _category = rawCat.toString();
    }

    // selfie_scan может прийти как UUID-string, либо как Map (expanded m2o).
    final rawSelfie = user['selfie_scan'];
    if (rawSelfie == null) {
      _selfieFileId = '';
    } else if (rawSelfie is Map) {
      _selfieFileId = (rawSelfie['id'] ?? '').toString();
    } else {
      _selfieFileId = rawSelfie.toString();
    }

    // rejection_reasons может прийти как:
    //   - List<dynamic> (Directus JSON-array)
    //   - String с CSV ("name,location,...")
    //   - null
    final rawReasons = user['rejection_reasons'];
    if (rawReasons is List) {
      _rejectionReasons = rawReasons.map((e) => e.toString()).toList();
    } else if (rawReasons is String && rawReasons.isNotEmpty) {
      _rejectionReasons =
          rawReasons.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else {
      _rejectionReasons = const [];
    }

    // ── Location (supports both raw ID and expanded Directus object) ────────
    void extractId(dynamic raw, void Function(String) setter) {
      if (raw == null) return;
      setter(raw is Map ? (raw['id']?.toString() ?? '') : raw.toString());
    }

    extractId(user['district'], (v) => _districtId = v);
    extractId(user['etrap'], (v) => _etraptId = v);
    extractId(user['province'], (v) => _provinceId = v);

    // Лейблы локации — берём из expanded-объектов если они есть.
    // AuthRepository тоже их сохраняет в prefs (см. `fetchProfileFromServer`),
    // но на момент verify-flow свежие значения приходят в `user` и
    // здесь же должны попасть в state, иначе `shopAddressRu/Tk` останутся
    // пусты до следующего `loadUserData()`.
    void extractLabels(
      dynamic raw, {
      required String ruKey,
      required String tkKey,
      required void Function(String) ru,
      required void Function(String) tk,
    }) {
      if (raw is! Map) return;
      final r = (raw[ruKey] ?? '').toString();
      final t = (raw[tkKey] ?? '').toString();
      if (r.isNotEmpty) ru(r);
      if (t.isNotEmpty) tk(t);
    }

    extractLabels(
      user['district'],
      ruKey: 'district_ru',
      tkKey: 'district_tk',
      ru: (v) => _districtRu = v,
      tk: (v) => _districtTk = v,
    );
    extractLabels(
      user['etrap'],
      ruKey: 'etrap_ru',
      tkKey: 'etrap_tk',
      ru: (v) => _etrapRu = v,
      tk: (v) => _etrapTk = v,
    );
    extractLabels(
      user['province'],
      ruKey: 'province_ru',
      tkKey: 'province_tk',
      ru: (v) => _provinceRu = v,
      tk: (v) => _provinceTk = v,
    );

    // Не логируем ID/status/role/district в release — это PII.
    if (kDebugMode) {
      debugPrint('📡 AuthProvider: setUserData → status=$_status role=$_role');
    }

    final prefs = await SharedPreferences.getInstance();
    // Access token — в secure storage, не в plain prefs.
    if (_token.isNotEmpty) {
      await SecureTokenStore.instance.setAccessToken(_token);
    }
    await prefs.setString('user_id', _userId);
    await prefs.setString('name', _name);
    await prefs.setString('surname', _surname);
    await prefs.setString('phone', _phone);
    await prefs.setString('shop_address', _address);
    await prefs.setString('district_id', _districtId);
    await prefs.setString('etrap_id', _etraptId);
    await prefs.setString('province_id', _provinceId);
    await prefs.setString('role', _role);
    await prefs.setString('status', _status);
    await prefs.setDouble('rating', _rating);
    await prefs.setDouble('balance_points', _balancePoints);
    await prefs.setDouble('wallet_balance', _walletBalance);
    await prefs.setString('transport_type', _transportType);
    await prefs.setString('category', _category);
    await prefs.setString('selfie_file_id', _selfieFileId);
    await prefs.setStringList('rejection_reasons', _rejectionReasons);
    await prefs.setBool('is_logged_in', true);

    // Account-scoped тур namespace.
    TourManager.instance.setUserId(_userId);
    // После setUserData профиль считается свежим — следующий
    // вызов handleRefresh() пропустит refreshProfile() (экономим HTTP).
    _hasFreshProfile = true;
    notifyListeners();
  }

  // ── Send OTP (phone screen) ────────────────────────────────────────────────

  /// Sends OTP and returns success. Caller guards context with mounted.
  /// [silent] — не показывать встроенный SnackBar (экран сам отрендерит ошибку).
  Future<bool> sendOTPOnly(
    BuildContext context,
    dynamic lang, {
    bool silent = false,
  }) async {
    _setLoading(true);
    _lastErrorKind = AuthErrorKind.none;
    try {
      final success = await _authRepo.sendOTP(
        '+993${phoneController.text.replaceAll(RegExp(r'\s+'), '')}',
      );
      if (!success) {
        _lastErrorKind = AuthErrorKind.serverBusy;
        if (!silent && context.mounted) {
          _showError(context, lang.words.errorCodeSend);
        }
      }
      return success;
    } catch (e) {
      _lastErrorKind = AuthErrorKind.network;
      if (!silent && context.mounted) _showError(context, '$e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Verify OTP & login ─────────────────────────────────────────────────────

  Future<bool> verifyOtpAndLogin(
    BuildContext context,
    dynamic lang, {
    bool silent = false,
    bool autoNavigate = true,
  }) async {
    _setLoading(true);
    _lastErrorKind = AuthErrorKind.none;
    try {
      final user = await _authRepo.verifyOTP(
        '+993${phoneController.text.replaceAll(RegExp(r'\s+'), '')}',
        otpController.text.trim(),
      );

      if (user != null) {
        await setUserData(user);
        // Check mounted AFTER every await

        // FCM init НЕ ждём — он медленный (permission dialog, getToken),
        // а его результат не нужен для перехода на /home. Полностью
        // безопасно: initialize() идемпотентен и сам синхронизирует токен
        // когда подгрузится.
        unawaited(PushNotificationService().initialize());
        if (!context.mounted) return true;
        if (autoNavigate) await _navigate(context);
        return true;
      } else {
        _lastErrorKind = AuthErrorKind.invalidCode;
        if (!silent && context.mounted) {
          _showError(context, lang.words.errorInvalidCode);
        }
        return false;
      }
    } catch (e) {
      _lastErrorKind = AuthErrorKind.network;
      if (!silent && context.mounted) _showError(context, '$e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Full auth flow (legacy) ────────────────────────────────────────────────

  Future<void> handleAuth(BuildContext context, dynamic langProvider) async {
    final words = langProvider.words;
    final phoneInput = phoneController.text.replaceAll(RegExp(r'\s+'), '');

    if (!phoneInput.startsWith('+993') || phoneInput.length < 12) {
      _showError(context, words.errorPhoneLength ?? 'Неверный формат номера');
      return;
    }

    _setLoading(true);
    try {
      if (!_isCodeSent) {
        final success = await _authRepo.sendOTP(phoneInput);
        if (success) {
          _isCodeSent = true;
        } else {
          if (context.mounted) {
            _showError(context, words.errorCodeSend ?? 'Ошибка отправки кода');
          }
        }
      } else {
        final user = await _authRepo.verifyOTP(
          phoneInput,
          otpController.text.trim(),
        );

        if (user != null) {
          await setUserData(user);
          if (!context.mounted) return;
          await _navigate(context);
        } else {
          otpController.clear();
          if (context.mounted) {
            _showError(context, words.errorInvalidCode ?? 'Неверный код');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, '${words.errorConnection}: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // ── Navigation after login ─────────────────────────────────────────────────

  Future<void> _navigate(BuildContext context) async {
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  // ── Skip onboarding ────────────────────────────────────────────────────────

  Future<void> skipOnboarding(BuildContext context) async {
    _setLoading(true);
    try {
      await _authRepo.updateProfile(userId: _userId, data: {'role': 'client'});
      _role = 'client';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', 'client');
      await prefs.setBool('onboarding_done', true);
      notifyListeners();

      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Ошибка skipOnboarding');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  // ── Profile update helpers ─────────────────────────────────────────────────

  Future<bool> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    return _authRepo.updateProfile(userId: userId, data: data);
  }

  void updateShopAddress(String newAddress) async {
    _address = newAddress;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_address', newAddress);
    if (kDebugMode) debugPrint('🏠 Адрес магазина обновлён');
    notifyListeners();
  }

  void updateDistrict(String newDistrictId) async {
    _districtId = newDistrictId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('district_id', newDistrictId);
    if (kDebugMode) debugPrint('📍 Район обновлён');
    notifyListeners();
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    // 1. Server-side revoke + clear secure tokens.
    // Не блокирует UI — silent fail OK, local cleanup всё равно произойдёт.
    await SecureTokenStore.instance.revokeOnServer(BaseUrl.url);
    await SecureTokenStore.instance.clear();

    // 2. Plain prefs cleanup с сохранением device-flag'ов.
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final savedLang = prefs.getString('language_code');
    final isDarkMode = prefs.getBool('is_dark_mode');
    final tokenMigrationDone =
        prefs.getBool('secure_tokens_migrated_v1') ?? false;
    // Account-scoped тур-состояния (всех пользователей) — сохраняем
    // через TourManager, чтобы при возврате на этот аккаунт гид не
    // показывался заново.
    final tourSnapshot = TourManager.instance.snapshotAllTourKeys();
    await prefs.clear();
    if (onboardingDone) await prefs.setBool('onboarding_done', true);
    if (savedLang != null) await prefs.setString('selected_lang', savedLang);
    if (isDarkMode != null) await prefs.setBool('is_dark_mode', isDarkMode);
    if (tokenMigrationDone) {
      await prefs.setBool('secure_tokens_migrated_v1', true);
    }
    await TourManager.instance.restoreSnapshot(tourSnapshot);
    // На время "нет активного userId" — глобальный namespace.
    TourManager.instance.setUserId('');
    // Локальный кэш прочитанных уведомлений принадлежит ушедшему пользователю.
    NotificationService.clearLocallyRead();
    // Скрываем persistent notification с активными заказами — они не должны
    // продолжать висеть в lock screen после logout.
    unawaited(ActiveOrdersNotification.hide());
    _token = '';
    _userId = '';
    _phone = '';
    _name = '';
    _surname = '';
    _address = '';
    _districtId = '';
    _etraptId = '';
    _provinceId = '';
    _provinceRu = '';
    _provinceTk = '';
    _etrapRu = '';
    _etrapTk = '';
    _districtRu = '';
    _districtTk = '';
    _role = 'client';
    _status = 'pending';
    _balancePoints = 0.0;
    _walletBalance = 0.0;
    _rating = 0.0;
    _category = '';
    _selfieFileId = '';
    _rejectionReasons = const [];
    _isCodeSent = false;
    notifyListeners();
  }

  void resetStatus() {
    _isCodeSent = false;
    _isLoading = false;
    otpController.clear();
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _tokenChangesSub?.cancel();
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }
}
