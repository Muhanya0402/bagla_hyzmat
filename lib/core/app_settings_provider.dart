import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'api_client.dart';

class AppSettingsProvider extends ChangeNotifier {
  String companyName = 'BAGLA IT SOLUTIONS';
  String supportPhone = '+99364012282';

  /// Разрешено ли курьерам пополнять жетоны. Управляется из Directus
  /// (`app_settings.top_up_enabled`). При выключении точки входа в
  /// пополнение скрываются.
  ///
  /// **По умолчанию false.** Раньше стояло `true` с мыслью «сбой загрузки не
  /// должен отнимать возможность» — но на деле выходило обратное: сразу после
  /// установки, пока настройки ещё не пришли с сервера, кнопка «Пополнить»
  /// показывалась, хотя пополнение выключено. Показать вход в отключённую
  /// функцию хуже, чем на мгновение не показать доступную.
  ///
  /// Чтобы сбой сети не отнимал кнопку у тех, кому она положена, последнее
  /// известное значение переживает перезапуск (см. [_kTopUpCache]).
  bool topUpEnabled = false;

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

  static const _kTopUpCache = 'app_settings_top_up_enabled';

  /// Запоминаем последнее известное значение, чтобы после перезапуска
  /// показать то же, что и в прошлый раз, ещё до ответа сервера.
  Future<void> _cacheTopUp(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTopUpCache, value);
    } catch (_) {
      // Не критично: без кеша просто дождёмся ответа сервера.
    }
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    // Сначала показываем прошлое известное значение — оно почти всегда верное
    // и приходит мгновенно. Сервер ниже его подтвердит или поправит.
    try {
      final cached = (await SharedPreferences.getInstance()).getBool(
        _kTopUpCache,
      );
      if (cached != null && cached != topUpEnabled) {
        topUpEnabled = cached;
        notifyListeners();
      }
    } catch (_) {}

    try {
      final res = await ApiClient().dio.get(
        '/items/app_settings',
        queryParameters: {
          'fields':
              'company_name,support_phone,top_up_enabled,'
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
      // Включаем только по ЯВНОМУ true. Пустое или отсутствующее значение —
      // это «неизвестно», а неизвестность не повод показывать пополнение.
      topUpEnabled = d['top_up_enabled'] == true;
      await _cacheTopUp(topUpEnabled);

      // Берём поля своей платформы — сравнивать версию Android с минимумом
      // для iOS бессмысленно, они живут своими циклами.
      final isIos = Platform.isIOS;
      minVersion = (d[isIos ? 'min_version_ios' : 'min_version_android'] ?? '')
          .toString();
      updateUrl = (d[isIos ? 'update_url_ios' : 'update_url_android'] ?? '')
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
