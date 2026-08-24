import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'api_client.dart';

class AppSettingsProvider extends ChangeNotifier {
  String companyName = 'BAGLA IT SOLUTIONS';
  String supportPhone = '+99364012282';

  /// Разрешено ли курьерам пополнять жетоны. Управляется из Directus
  /// (`app_settings.top_up_enabled`). При выключении точки входа в
  /// пополнение скрываются. По умолчанию true — если настройка не
  /// загрузилась, функциональность не должна пропадать сама по себе.
  bool topUpEnabled = true;

  /// Минимально допустимая версия приложения для этой платформы и ссылка на
  /// обновление. Задаются в Directus раздельно для Android и iOS: iOS ходит
  /// через ревью Apple, Android раздаётся напрямую, и общий минимум отрезал
  /// бы iOS-пользователей от версии, которую Apple ещё не пропустил.
  ///
  /// Пустая строка означает «проверка выключена» — так и задумано, пока
  /// приложение раздаётся вручную тестировщикам.
  String minVersion = '';
  String updateUrl = '';

  bool _loading = false;

  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiClient().dio.get(
        '/items/app_settings',
        queryParameters: {
          'fields': 'company_name,support_phone,top_up_enabled,'
              'min_version_android,min_version_ios,'
              'update_url_android,update_url_ios',
          'limit': 1,
        },
      );
      // Directus может вернуть либо singleton-объект, либо массив
      final raw = res.data['data'];
      final Map<String, dynamic> d = raw is List
          ? (raw.isNotEmpty ? raw.first : {})
          : (raw ?? {});

      companyName = (d['company_name'] ?? 'BAGLA IT SOLUTIONS').toString();
      supportPhone = (d['support_phone'] ?? '+99364012282').toString();
      // null (поле ещё не заполнено) трактуем как «включено».
      topUpEnabled = d['top_up_enabled'] != false;

      // Берём поля своей платформы — сравнивать версию Android с минимумом
      // для iOS бессмысленно, они живут своими циклами.
      final isIos = Platform.isIOS;
      minVersion =
          (d[isIos ? 'min_version_ios' : 'min_version_android'] ?? '')
              .toString();
      updateUrl =
          (d[isIos ? 'update_url_ios' : 'update_url_android'] ?? '')
              .toString();
    } catch (_) {
      // оставляем fallback-значения
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
