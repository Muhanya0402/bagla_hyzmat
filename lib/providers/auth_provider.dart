import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/auth_repository.dart';
import 'package:bagla/services/push_notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  bool _isCodeSent = false;
  bool _isLoading = false;

  String _token = '';
  String _userId = '';
  String _name = '';
  String _surname = '';
  String _phone = '';
  String _address = '';
  String _districtId = '';
  String _etraptId = '';
  String _provinceId = '';
  String _role = 'client';
  String _status = 'pending';
  double _rating = 0.0;
  double _balancePoints = 0.0;
  double _walletBalance = 0.0;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isCodeSent => _isCodeSent;
  bool get isLoading => _isLoading;
  String get token => _token;
  String get userId => _userId;
  String get name => _name;
  String get surname => _surname;
  String get phone => _phone;
  String get address => _address;
  String get districtId => _districtId;
  String get etraptId => _etraptId;
  String get provinceId => _provinceId;
  String get role => _role;
  String get status => _status;
  double get rating => _rating;
  // int cast so widgets can do "${auth.balancePoints}" without ".0"
  double get balancePoints => _balancePoints;
  double get walletBalance => _walletBalance;

  AuthProvider() {
    loadUserData();
  }

  // ── Load from SharedPrefs ──────────────────────────────────────────────────

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token') ?? '';
    _userId = prefs.getString('user_id') ?? '';
    _name = prefs.getString('name') ?? '';
    _surname = prefs.getString('surname') ?? '';
    _phone = prefs.getString('phone') ?? '';
    _address = prefs.getString('shop_address') ?? '';
    _districtId = prefs.getString('district_id') ?? '';
    _etraptId = prefs.getString('etrap_id') ?? '';
    _provinceId = prefs.getString('province_id') ?? '';
    _role = prefs.getString('role') ?? 'client';
    _status = prefs.getString('status') ?? 'pending';
    _rating = prefs.getDouble('rating') ?? 0.0;
    _balancePoints = prefs.getDouble('balance_points') ?? 0.0;
    _walletBalance = prefs.getDouble('wallet_balance') ?? 0.0;

    if (_phone.isNotEmpty) phoneController.text = _phone;
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
      debugPrint('❌ Ошибка обновления профиля: $e');
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
    _role = user['role'] ?? 'client';
    _status = (user['status']?.toString() ?? 'pending').toLowerCase().trim();
    _rating = (user['rating'] ?? 0.0).toDouble();
    _balancePoints = (user['balance_points'] ?? 0.0).toDouble();
    _walletBalance = (user['wallet_balance'] ?? 0.0).toDouble();

    // ── Location (supports both raw ID and expanded Directus object) ────────
    void extractId(dynamic raw, void Function(String) setter) {
      if (raw == null) return;
      setter(raw is Map ? (raw['id']?.toString() ?? '') : raw.toString());
    }

    extractId(user['district'], (v) => _districtId = v);
    extractId(user['etrap'], (v) => _etraptId = v);
    extractId(user['province'], (v) => _provinceId = v);

    debugPrint(
      '📡 AuthProvider: ID=$_userId status=$_status role=$_role district=$_districtId',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token);
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
    await prefs.setBool('is_logged_in', true);

    notifyListeners();
  }

  // ── Send OTP (phone screen) ────────────────────────────────────────────────

  /// Sends OTP and returns success. Caller guards context with mounted.
  Future<bool> sendOTPOnly(BuildContext context, dynamic lang) async {
    _setLoading(true);
    try {
      final success = await _authRepo.sendOTP(
        '+993${phoneController.text.trim()}',
      );
      if (!success && context.mounted) {
        _showError(context, lang.words.errorCodeSend);
      }
      return success;
    } catch (e) {
      if (context.mounted) _showError(context, '$e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Verify OTP & login ─────────────────────────────────────────────────────

  Future<bool> verifyOtpAndLogin(BuildContext context, dynamic lang) async {
    _setLoading(true);
    try {
      final user = await _authRepo.verifyOTP(
        '+993${phoneController.text.trim()}',
        otpController.text.trim(),
      );

      if (user != null) {
        await setUserData(user);
        // Check mounted AFTER every await

        await PushNotificationService().initialize();
        if (!context.mounted) return true;
        await _navigate(context);
        return true;
      } else {
        if (context.mounted) _showError(context, lang.words.errorInvalidCode);
        return false;
      }
    } catch (e) {
      if (context.mounted) _showError(context, '$e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Full auth flow (legacy) ────────────────────────────────────────────────

  Future<void> handleAuth(BuildContext context, dynamic langProvider) async {
    final words = langProvider.words;
    final phoneInput = phoneController.text.trim();

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
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final isNewUser = _status == 'published' && !onboardingDone;

    // Always guard with mounted after every await
    if (!context.mounted) return;

    if (isNewUser) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/onboarding',
        (route) => false,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
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
      debugPrint('❌ Ошибка skipOnboarding: $e');
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
    debugPrint('🏠 Адрес магазина обновлён: $_address');
    notifyListeners();
  }

  void updateDistrict(String newDistrictId) async {
    _districtId = newDistrictId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('district_id', newDistrictId);
    debugPrint('📍 Район обновлён: $_districtId');
    notifyListeners();
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _token = '';
    _userId = '';
    _phone = '';
    _name = '';
    _surname = '';
    _address = '';
    _districtId = '';
    _etraptId = '';
    _provinceId = '';
    _role = 'client';
    _status = 'pending';
    _balancePoints = 0.0;
    _walletBalance = 0.0;
    _rating = 0.0;
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
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }
}
