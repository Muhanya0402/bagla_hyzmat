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

  /// С какой суммы заказ автоматически становится «только для надёжных
  /// курьеров» (`app_settings.trusted_amount_threshold`), в манатах.
  ///
  /// `0` — режим выключен целиком. Это и значение по умолчанию: если
  /// настройка не загрузилась, заказы не должны вдруг начать прятаться от
  /// курьеров. Здесь осторожность работает в другую сторону, чем у
  /// [topUpEnabled]: там сбой не должен отнимать возможность, здесь — не
  /// должен её незаметно включать.
  int trustedAmountThreshold = 0;

  /// Сколько жетонов получает курьер за приглашённого друга
  /// (`app_settings.referral_reward`). `0` — программа выключена.
  ///
  /// По умолчанию 0 по той же причине, что и порог выше: если настройка не
  /// загрузилась, приложение не должно обещать приз, которого может не быть.
  int referralReward = 0;

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
              'update_url_android,update_url_ios,'
              'trusted_amount_threshold,referral_reward',
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

      final rawThreshold = d['trusted_amount_threshold'];
      trustedAmountThreshold = rawThreshold is num
          ? rawThreshold.toInt()
          : int.tryParse('${rawThreshold ?? ''}') ?? 0;

      final rawReward = d['referral_reward'];
      referralReward = rawReward is num
          ? rawReward.toInt()
          : int.tryParse('${rawReward ?? ''}') ?? 0;
    } catch (_) {
      // оставляем fallback-значения
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
