import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _langKey = 'selected_lang';

  AppLocale _locale = AppLocale.ru;
  bool _isSaving = false;
  late AppLocalizations _localizations;

  LanguageProvider() {
    _localizations = AppLocalizations(_locale);
  }

  AppLocalizations get words => _localizations;
  AppLocale get locale => _locale;
  String get label => _locale == AppLocale.ru ? 'RU' : 'TK';
  bool get isRu => _locale == AppLocale.ru;

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final String saved = prefs.getString(_langKey) ?? 'ru';
    _locale = saved == 'ru' ? AppLocale.ru : AppLocale.tk;
    _localizations = AppLocalizations(_locale);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    if (_isSaving) return;
    _isSaving = true;

    // Мгновенно меняем в памяти
    _locale = _locale == AppLocale.ru ? AppLocale.tk : AppLocale.ru;
    _localizations = AppLocalizations(_locale);
    notifyListeners();

    // Сохраняем в фоне
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langKey, _locale == AppLocale.ru ? 'ru' : 'tk');
    } catch (e) {
      debugPrint('Ошибка сохранения языка: $e');
    } finally {
      _isSaving = false;
    }
  }
}
