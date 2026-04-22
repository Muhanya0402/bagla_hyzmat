import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();

  final TextEditingController phoneController = TextEditingController(
    text: '+993',
  );
  final TextEditingController otpController = TextEditingController();

  bool _isCodeSent = false;
  bool _isLoading = false;

  String _token = "";
  String _userId = "";
  String _name = "";
  String _surname = "";
  String _phone = "";
  String _address = "";
  String _role = "client";
  String _status = "pending";
  double _rating = 0.0;
  int _balancePoints = 0;

  bool get isCodeSent => _isCodeSent;
  bool get isLoading => _isLoading;
  String get token => _token;
  String get userId => _userId;
  String get name => _name;
  String get surname => _surname;
  String get phone => _phone;
  String get address => _address;
  String get role => _role;
  String get status => _status;
  double get rating => _rating;
  int get balancePoints => _balancePoints;

  AuthProvider() {
    loadUserData();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token') ?? "";
    _userId = prefs.getString('user_id') ?? "";
    _name = prefs.getString('name') ?? "";
    _surname = prefs.getString('surname') ?? "";
    _phone = prefs.getString('phone') ?? "";
    _address = prefs.getString('shop_address') ?? "";
    _role = prefs.getString('role') ?? "client";
    _status = prefs.getString('status') ?? "pending";
    _rating = prefs.getDouble('rating') ?? 0.0;
    _balancePoints = prefs.getInt('balance_points') ?? 0;

    if (_phone.isNotEmpty) {
      phoneController.text = _phone;
    }
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (_phone.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _phone = prefs.getString('phone') ?? "";
    }
    if (_phone.isEmpty) return;

    try {
      final userData = await _authRepo.fetchProfileFromServer(_phone);
      if (userData != null) {
        setUserData(userData);
      }
    } catch (e) {
      debugPrint("❌ Ошибка обновления профиля: $e");
    }
  }

  void setUserData(Map<String, dynamic> user) async {
    _token = user['access_token'] ?? user['token'] ?? _token;
    _userId =
        user['id']?.toString() ?? user['customer_ID']?.toString() ?? _userId;
    _name = user['name'] ?? "";
    _surname = user['surname'] ?? "";
    _phone = user['phone'] ?? _phone;
    _address = user['address'] ?? _address;
    _role = user['role'] ?? "client";
    _status = (user['status']?.toString() ?? "pending").toLowerCase().trim();
    _rating = (user['rating'] ?? 0.0).toDouble();
    _balancePoints = user['balance_points'] ?? 0;

    debugPrint("📡 AuthProvider: ID: $_userId, status: $_status, role: $_role");

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token);
    await prefs.setString('user_id', _userId);
    await prefs.setString('name', _name);
    await prefs.setString('surname', _surname);
    await prefs.setString('phone', _phone);
    await prefs.setString('shop_address', _address);
    await prefs.setString('role', _role);
    await prefs.setString('status', _status);
    await prefs.setDouble('rating', _rating);
    await prefs.setInt('balance_points', _balancePoints);
    await prefs.setBool('is_logged_in', true);

    notifyListeners();
  }

  Future<void> handleAuth(BuildContext context, dynamic langProvider) async {
    final words = langProvider.words;
    final String phoneInput = phoneController.text.trim();

    if (!phoneInput.startsWith('+993') || phoneInput.length < 12) {
      _showError(context, words.errorPhoneLength ?? "Неверный формат номера");
      return;
    }

    _setLoading(true);

    try {
      if (!_isCodeSent) {
        final success = await _authRepo.sendOTP(phoneInput);
        if (success) {
          _isCodeSent = true;
        } else {
          _showError(context, words.errorCodeSend ?? "Ошибка отправки кода");
        }
      } else {
        final user = await _authRepo.verifyOTP(
          phoneInput,
          otpController.text.trim(),
        );

        if (user != null) {
          setUserData(user);

          if (context.mounted) {
            await _navigate(context);
          }
        } else {
          otpController.clear();
          _showError(context, words.errorInvalidCode ?? "Неверный код");
        }
      }
    } catch (e) {
      _showError(context, "${words.errorConnection}: $e");
    } finally {
      _setLoading(false);
    }
  }

  /// Навигация после логина
  Future<void> _navigate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;

    // Новый пользователь — статус pending и онбординг ещё не пройден
    final isNewUser = _status == 'published' && !onboardingDone;

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

  /// Вызывается из OnboardingScreen при нажатии "Пропустить"
  Future<void> skipOnboarding(BuildContext context) async {
    _setLoading(true);
    try {
      // Ставим роль client по умолчанию
      await _authRepo.updateProfile(userId: _userId, data: {'role': 'client'});
      _role = 'client';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', 'client');
      await prefs.setBool('onboarding_done', true);

      notifyListeners();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      debugPrint("❌ Ошибка skipOnboarding: $e");
    } finally {
      _setLoading(false);
    }
  }

  /// Вызывается из UserTypeSelectionScreen после сохранения роли
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

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
    debugPrint("🏠 Адрес магазина обновлен: $_address");
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _token = "";
    _userId = "";
    _phone = "";
    _name = "";
    _surname = "";
    _address = "";
    _role = "client";
    _status = "pending";
    _balancePoints = 0;
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
