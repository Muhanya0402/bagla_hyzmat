import 'package:bagla/core/tour/tour_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ключи, принадлежащие УСТРОЙСТВУ, а не аккаунту — переживают logout.
const Set<String> kKeepOnLogout = {
  'onboarding_done',
  'language_code',
  'selected_lang',
  'is_dark_mode',
  'secure_tokens_migrated_v1',
};

/// Очистка prefs при выходе из аккаунта.
///
/// ⚠️ Намеренно НЕ используем `prefs.clear()`. Раньше logout стирал всё и
/// затем вручную возвращал «список того, что вспомнили» (включая снимок
/// тур-ключей). Схема хрупкая: любой сбой между `clear()` и восстановлением —
/// и состояние пропадает молча. Так терялись пройденные гиды: после
/// повторного входа они запускались заново на ВСЕХ экранах.
///
/// Теперь наоборот: удаляем только то, что относится к аккаунту, а
/// тур-состояния (`tour_passed_*`) и настройки устройства не трогаем вообще —
/// им нечего терять. Новый ключ, добавленный в будущем, по умолчанию будет
/// удалён вместе с аккаунтом, что безопаснее, чем случайно «утечь» между
/// пользователями.
Future<void> clearAccountPrefs(SharedPreferences prefs) async {
  for (final key in prefs.getKeys().toList()) {
    // Пройденные гиды — привязаны к аккаунту через namespace в самом ключе,
    // поэтому безопасно хранятся для всех пользователей устройства.
    if (key.startsWith(TourKeys.prefsPrefix)) continue;
    if (kKeepOnLogout.contains(key)) continue;
    await prefs.remove(key);
  }
}
