import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';

class RoleProvider extends ChangeNotifier {
  String _selectedRole = 'client';
  bool _isSaving = false;

  String get selectedRole => _selectedRole;
  bool get isSaving => _isSaving;

  RoleProvider() {
    _initRole();
  }

  Future<void> _initRole() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedRole = prefs.getString('role') ?? 'client';
    notifyListeners();
  }

  void selectRole(String roleId) {
    _selectedRole = roleId;
    notifyListeners();
  }

  Future<void> saveRole(BuildContext context) async {
    _isSaving = true;
    notifyListeners();

    try {
      final authProv = Provider.of<AuthProvider>(context, listen: false);

      // Сохраняем роль на сервере
      await authProv.updateProfile(
        userId: authProv.userId,
        data: {'role': _selectedRole},
      );

      // Помечаем онбординг как пройденный
      await authProv.completeOnboarding();

      // Сохраняем локально
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', _selectedRole);

      // Обновляем AuthProvider
      if (context.mounted) {
        final Map<String, dynamic> updatedData = {
          'role': _selectedRole,
          'name': authProv.name,
          'surname': authProv.surname,
          'phone': authProv.phone,
          'status': authProv.status,
          'rating': authProv.rating,
          'balance_points': authProv.balancePoints,
        };
        authProv.setUserData(updatedData);
      }

      if (context.mounted) {
        Navigator.pushNamed(
          context,
          '/registration_details',
          arguments: _selectedRole,
        );
      }
    } catch (e) {
      debugPrint("Ошибка при сохранении роли: $e");
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
