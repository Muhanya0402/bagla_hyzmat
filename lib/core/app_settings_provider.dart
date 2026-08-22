import 'package:flutter/material.dart';
import 'api_client.dart';

class AppSettingsProvider extends ChangeNotifier {
  String appVersion = '';
  String companyName = 'BAGLA IT SOLUTIONS';
  String supportPhone = '+99364012282';

  /// Разрешено ли курьерам пополнять жетоны. Управляется из Directus
  /// (`app_settings.top_up_enabled`). При выключении точки входа в
  /// пополнение скрываются. По умолчанию true — если настройка не
  /// загрузилась, функциональность не должна пропадать сама по себе.
  bool topUpEnabled = true;
  bool _loading = false;

  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiClient().dio.get(
        '/items/app_settings',
        queryParameters: {
          'fields': 'app_version,company_name,support_phone,top_up_enabled',
          'limit': 1,
        },
      );
      // Directus может вернуть либо singleton-объект, либо массив
      final raw = res.data['data'];
      final Map<String, dynamic> d = raw is List
          ? (raw.isNotEmpty ? raw.first : {})
          : (raw ?? {});

      appVersion = (d['app_version'] ?? '').toString();
      companyName = (d['company_name'] ?? 'BAGLA IT SOLUTIONS').toString();
      supportPhone = (d['support_phone'] ?? '+99364012282').toString();
      // null (поле ещё не заполнено) трактуем как «включено».
      topUpEnabled = d['top_up_enabled'] != false;
    } catch (_) {
      // оставляем fallback-значения
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
