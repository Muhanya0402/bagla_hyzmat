import 'package:flutter/material.dart';
import 'api_client.dart';

class AppSettingsProvider extends ChangeNotifier {
  String appVersion = '';
  String companyName = 'BAGLA IT SOLUTIONS';
  String supportPhone = '+99364012282';
  bool _loading = false;

  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiClient().dio.get(
        '/items/app_settings',
        queryParameters: {
          'fields': 'app_version,company_name,support_phone',
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
    } catch (_) {
      // оставляем fallback-значения
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
