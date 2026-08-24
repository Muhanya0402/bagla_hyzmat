import 'package:package_info_plus/package_info_plus.dart';

/// Версия приложения на устройстве и сравнение версий.
///
/// Раньше версия в профиле бралась из строки `app_settings.app_version`,
/// которую вписывали руками в Directus. Она разъехалась с реальностью: в
/// настройках стояло `1.2.1`, а собиралось `1.0.0+1`. Показывать номер, не
/// связанный с тем, что стоит у человека, хуже, чем не показывать вовсе —
/// на него ориентируются при разборе жалоб.
abstract final class AppVersion {
  AppVersion._();

  static String _version = '';
  static String _build = '';

  /// Прочитать версию у платформы. Вызывать один раз при старте.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _build = info.buildNumber;
    } catch (_) {
      // Не смогли прочитать — оставляем пустое. Пустая версия нигде не
      // блокирует вход: отрезать человека от приложения из-за сбоя чтения
      // собственных метаданных нельзя.
    }
  }

  /// Версия без номера сборки: `1.0.0`. С ней сравниваются минимальные
  /// версии из Directus.
  static String get version => _version;

  /// Для показа человеку: `1.0.0 (1)`.
  ///
  /// Номер сборки здесь не украшение. При ежедневных пересборках номер
  /// версии не меняется, а сборки — меняется, и только он отличает свежий
  /// APK от вчерашнего.
  static String get display {
    if (_version.isEmpty) return '';
    return _build.isEmpty ? _version : '$_version ($_build)';
  }

  /// Ниже ли [current] минимально допустимой [minimum].
  ///
  /// Сравнение покомпонентное и числовое. Строковое сравнение здесь —
  /// классическая ловушка: `'1.10.0'.compareTo('1.9.0')` даёт «меньше»,
  /// потому что символ `1` идёт раньше `9`. Проявляется такое не сразу, а
  /// к десятому релизу, и отсекает не тех пользователей.
  ///
  /// Пустая [minimum] означает «проверка выключена» — всегда `false`.
  /// Пустая [current] тоже не блокирует: см. [load].
  /// Нечисловые части (`1.0.0-beta`) игнорируются, разная длина
  /// дополняется нулями: `1.2` и `1.2.0` равны.
  static bool isBelow(String current, String minimum) {
    if (minimum.trim().isEmpty || current.trim().isEmpty) return false;

    final a = _parts(current);
    final b = _parts(minimum);
    final len = a.length > b.length ? a.length : b.length;

    for (var i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x < y;
    }
    return false; // равны
  }

  static List<int> _parts(String v) {
    // Номер сборки после `+` к сравнению не относится: минимальную версию
    // задают в виде `1.2.0`, а не `1.2.0+7`.
    final core = v.split('+').first.trim();
    return core
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
