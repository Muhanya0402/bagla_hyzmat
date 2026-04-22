import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _langKey = 'selected_lang';

  // Инициализируем сразу, чтобы UI не получал null или мусор при старте
  AppLanguage _words = AppLanguage.ru;
  bool _isRussian = true;
  bool _isSaving = false; // Флаг для предотвращения "шума" при быстрых кликах

  AppLanguage get words => _words;
  String get label => _isRussian ? "RU" : "TK";

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final String savedCode = prefs.getString(_langKey) ?? 'ru';

    _isRussian = (savedCode == 'ru');
    _words = _isRussian ? AppLanguage.ru : AppLanguage.tk;

    // Уведомляем только если данные действительно загружены
    notifyListeners();
  }

  void toggleLanguage() async {
    // 1. Блокируем повторный вызов, пока идет сохранение
    if (_isSaving) return;
    _isSaving = true;

    // 2. МГНОВЕННО обновляем состояние в памяти (Синхронно)
    _isRussian = !_isRussian;
    _words = _isRussian ? AppLanguage.ru : AppLanguage.tk;

    // 3. Сразу уведомляем UI, чтобы отрисовка была чистой
    notifyListeners();

    // 4. Сохраняем на диск в фоновом режиме
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langKey, _isRussian ? 'ru' : 'tk');
    } catch (e) {
      debugPrint("Ошибка сохранения языка: $e");
    } finally {
      _isSaving = false;
    }
  }
}