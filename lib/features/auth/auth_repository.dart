import 'package:bagla/core/app_config.dart';
import 'package:bagla/core/tour/tour_manager.dart';
import 'package:bagla/features/profile/widgets/shop_categories.dart';
import 'package:bagla/models/district.dart';
import 'package:bagla/models/province.dart';
import 'package:bagla/models/etrap.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';

class AuthRepository {
  final ApiClient _api = ApiClient();

  // ─── OTP ───────────────────────────────────────────────────────────────────

  Future<bool> sendOTP(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');

      final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');

      debugPrint('──────────────────────────────────────');
      debugPrint(
        '📤 SEND_OTP →  POST ${_api.dio.options.baseUrl}/items/otp_codes',
      );
      debugPrint('   payload: {identifier: $cleanPhone}');

      final response = await _api.dio.post(
        '/items/otp_codes',
        data: {'identifier': cleanPhone},
        options: Options(
          headers: {'Authorization': 'Bearer ${AppConfig.publicToken}'},
        ),
      );

      debugPrint('✅ SEND_OTP ← ${response.statusCode}  data: ${response.data}');
      debugPrint('──────────────────────────────────────');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      debugPrint('❌ SEND_OTP ERROR');
      debugPrint('   type   : ${e.type}');
      debugPrint('   message: ${e.message}');
      debugPrint('   status : ${e.response?.statusCode}');
      debugPrint('   data   : ${e.response?.data}');
      debugPrint('──────────────────────────────────────');
      return false;
    }
  }

  Future<Map<String, dynamic>?> verifyOTP(String phone, String code) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
      final cleanCode = code.trim();
      const flowPath = '/flows/trigger/851636a4-92c7-40e5-993b-e9d41fdeff73';

      debugPrint('──────────────────────────────────────');
      debugPrint('📤 VERIFY_OTP →  POST ${_api.dio.options.baseUrl}$flowPath');
      debugPrint('   payload: {identifier: $cleanPhone, code: $cleanCode}');

      final response = await _api.dio.post(
        flowPath,
        data: {'identifier': cleanPhone, 'code': cleanCode},
        options: Options(
          headers: {'Authorization': 'Bearer ${AppConfig.publicToken}'},
        ),
      );

      debugPrint('✅ VERIFY_OTP ← ${response.statusCode}');
      debugPrint('   data keys: ${(response.data as Map?)?.keys.toList()}');
      debugPrint('──────────────────────────────────────');

      final data = response.data as Map<String, dynamic>;

      String? accessToken;
      String? refreshToken;

      for (final key in data.keys) {
        final value = data[key];
        if (value is Map && value['access_token'] != null) {
          accessToken = value['access_token'] as String;
          refreshToken = value['refresh_token'] as String?;
          break;
        }
      }

      if (accessToken != null) {
        await _saveTokens(accessToken, refreshToken ?? '');

        final profile = await fetchProfileFromServer(phone.trim());
        if (profile != null) {
          profile['access_token'] = accessToken;
          profile['refresh_token'] = refreshToken ?? '';
          return profile;
        }
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ VERIFY_OTP ERROR');
      debugPrint('   type   : ${e.type}');
      debugPrint('   message: ${e.message}');
      debugPrint('   status : ${e.response?.statusCode}');
      debugPrint('   data   : ${e.response?.data}');
      debugPrint('──────────────────────────────────────');
      return null;
    }
  }

  Future<bool> refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;

      final response = await _api.dio.post(
        '/flows/trigger/ВАШ_REFRESH_FLOW_ID',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'Authorization': 'Bearer ${AppConfig.publicToken}'},
        ),
      );

      final data = response.data;
      String? newAccessToken;
      String? newRefreshToken;

      for (final key in data.keys) {
        final value = data[key];
        if (value is Map && value['access_token'] != null) {
          newAccessToken = value['access_token'] as String;
          newRefreshToken = value['refresh_token'] as String?;
          break;
        }
      }

      if (newAccessToken != null) {
        await _saveTokens(newAccessToken, newRefreshToken ?? refreshToken);
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint("Ошибка refreshAccessToken: ${e.response?.data}");
      return false;
    }
  }

  // ─── Профиль ───────────────────────────────────────────────────────────────

  Future<bool> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _api.dio.patch(
        '/items/customers/$userId',
        data: data,
      );
      if (response.statusCode == 200) {
        await _saveUserToLocal(response.data['data']);
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint("Ошибка PATCH профиля: ${e.response?.data}");
      return false;
    }
  }

  /// Получение профиля — запрашиваем district, etrap, province вложенно с названиями
  Future<Map<String, dynamic>?> fetchProfileFromServer(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');

      debugPrint('──────────────────────────────────────');
      debugPrint(
        '📤 FETCH_PROFILE →  GET ${_api.dio.options.baseUrl}/items/customers',
      );
      debugPrint('   filter phone: $cleanPhone');

      final response = await _api.dio.get(
        '/items/customers',
        queryParameters: {
          'filter[phone][_eq]': cleanPhone,
          'fields':
              'id,phone,name,surname,role,status,rating,balance_points,address,'
              'district.id,district.district_ru,district.district_tk,'
              'etrap.id,etrap.etrap_ru,etrap.etrap_tk,'
              'province.id,province.province_ru,province.province_tk,'
              'experience_points,wallet_balance,transport_type,category,'
              'rejection_reasons',
        },
      );

      debugPrint('✅ FETCH_PROFILE ← ${response.statusCode}');
      final List data = response.data['data'];
      debugPrint('   records found: ${data.length}');

      if (data.isNotEmpty) {
        final user = data[0];
        debugPrint('📡 Получен статус от сервера: ${user['status']}');
        debugPrint(
          '   id=${user['id']}  role=${user['role']}  name=${user['name']}',
        );
        debugPrint('──────────────────────────────────────');
        await _saveUserToLocal(user);
        return user;
      }
      debugPrint('⚠️  FETCH_PROFILE — пользователь не найден');
      debugPrint('──────────────────────────────────────');
      return null;
    } catch (e) {
      debugPrint('❌ FETCH_PROFILE ERROR');
      debugPrint('   $e');
      debugPrint('──────────────────────────────────────');
      return null;
    }
  }

  // ─── Файлы ─────────────────────────────────────────────────────────────────

  Future<String?> uploadFile(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _api.dio.post('/files', data: formData);
      return response.data['data']['id'];
    } catch (e) {
      debugPrint("Ошибка загрузки файла: $e");
      return null;
    }
  }

  // ─── Баланс ────────────────────────────────────────────────────────────────

  Future<bool> requestTopUp({
    required String userId,
    required int points,
    required double amountTmt,
  }) async {
    try {
      final response = await _api.dio.post(
        '/items/customer_balance',
        data: {
          'customer_ID': [
            {"item": userId, "collection": "customers"},
          ],
          'amountToBeReplenished': amountTmt,
          'points': points,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint("❌ Ошибка M2A: ${e.response?.data}");
      return false;
    }
  }

  // ─── Локация: Велаят → Этрап → Район ──────────────────────────────────────

  Future<List<Province>> getProvinces() async {
    try {
      final res = await _api.dio.get(
        '/items/province',
        queryParameters: {
          'fields': 'id,province_ru,province_tk',
          'sort': 'province_ru',
        },
      );
      final List data = res.data['data'];
      return data.map((e) => Province.fromJson(e)).toList();
    } catch (e) {
      throw Exception("Ошибка загрузки велаятов: $e");
    }
  }

  Future<List<Etrap>> getEtrapsByProvince(String provinceId) async {
    try {
      final res = await _api.dio.get(
        '/items/etraps',
        queryParameters: {
          'fields': 'id,etrap_ru,etrap_tk,province',
          'filter[province][_eq]': provinceId,
          'sort': 'etrap_ru',
        },
      );
      final List data = res.data['data'];
      return data.map((e) => Etrap.fromJson(e)).toList();
    } catch (e) {
      throw Exception("Ошибка загрузки этрапов: $e");
    }
  }

  Future<List<District>> getDistrictsByEtrap(
    String etrapId, {
    String query = '',
    String lang = 'ru',
  }) async {
    try {
      final params = <String, dynamic>{
        'fields': 'id,district_ru,district_tk,etrap',
        'filter[etrap][_eq]': etrapId,
        'sort': 'district_ru',
        'limit': 100,
      };

      if (query.isNotEmpty) {
        final field = lang == 'ru' ? 'district_ru' : 'district_tk';
        params['filter[$field][_icontains]'] = query;
        params['limit'] = 30;
      }

      final res = await _api.dio.get(
        '/items/district_classifier',
        queryParameters: params,
      );
      final List data = res.data['data'];
      return data.map((e) => District.fromJson(e)).toList();
    } catch (e) {
      throw Exception("Ошибка загрузки районов: $e");
    }
  }

  // ─── Категории магазина ────────────────────────────────────────────────────

  /// Получить актуальный список категорий из Directus.
  ///
  /// Ожидаемая схема `shop_categories`:
  ///   - `id` — PK (string slug или int autoincrement — оба работают)
  ///   - `label_ru` — string
  ///   - `label_tk` — string
  ///   - `sort` — integer, опц. (порядок отображения; в Directus это
  ///     системное поле для drag-and-drop сортировки в admin-панели)
  ///   - `icon` — string, опц. (slug для маппинга `kShopCategoryIcons`)
  ///
  /// Сортировка: сначала по `sort` (asc, null'ы в конце), затем по `id` —
  /// порядок остаётся стабильным, даже если ты ещё не расставил sort.
  ///
  /// Если поле `icon` пустое — иконка подбирается по `id` (если `id` — slug).
  /// Если ничего не подошло — дефолтная `storefront`.
  ///
  /// Бросает Exception — вызывающий код решит, использовать ли fallback.
  Future<List<ShopCategory>> getShopCategories() async {
    try {
      final res = await _api.dio.get(
        '/items/shop_categories',
        queryParameters: {
          'fields': 'id,label_ru,label_tk,sort',
          // Directus: `sort` (asc), затем `id` как tie-breaker.
          'sort': 'sort,id',
          'limit': 100,
        },
      );
      final List data = res.data['data'];
      return data.map((row) {
        final m = row as Map<String, dynamic>;
        final id = m['id'];
        // Slug для иконки: 1) поле icon, 2) id если он строковый, 3) fallback.
        final iconSlug = (m['icon'] as String?)?.trim().isNotEmpty == true
            ? m['icon'] as String
            : (id is String ? id : '');
        return ShopCategory(
          id: id,
          icon: iconForSlug(iconSlug),
          labelRu: (m['label_ru'] as String?) ?? '',
          labelTk: (m['label_tk'] as String?) ?? '',
        );
      }).toList();
    } on DioException catch (e) {
      debugPrint('❌ getShopCategories: ${e.response?.statusCode} ${e.message}');
      rethrow;
    }
  }

  Future<double?> fetchTokenRate() async {
    try {
      final response = await _api.dio.get(
        '/items/app_settings',
        queryParameters: {'fields': 'token_rate', 'limit': 1},
      );
      final items = response.data['data'] as List;
      if (items.isEmpty) return null;
      return (items.first['token_rate'] as num?)?.toDouble();
    } catch (e) {
      return null;
    }
  }

  Future<List<District>> getDistricts() async {
    try {
      final res = await _api.dio.get(
        '/items/district_classifier',
        queryParameters: {'fields': 'id,district_ru,district_tk,etrap'},
      );
      final List data = res.data['data'];
      return data.map((e) => District.fromJson(e)).toList();
    } catch (e) {
      throw Exception("Ошибка загрузки районов: $e");
    }
  }

  Future<List<District>> searchDistricts(
    String query, {
    String lang = 'ru',
  }) async {
    if (query.isEmpty) return [];
    final field = lang == 'ru' ? 'district_ru' : 'district_tk';
    try {
      final res = await _api.dio.get(
        '/items/district_classifier',
        queryParameters: {
          'fields': 'id,district_ru,district_tk',
          'filter[$field][_icontains]': query,
          'limit': 20,
        },
      );
      final List data = res.data['data'];
      return data.map((e) => District.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Ошибка поиска районов: $e");
      return [];
    }
  }

  // ─── Токены и кэш ──────────────────────────────────────────────────────────

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    debugPrint("✅ Токены сохранены");
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  /// Достать ID из M2O поля (может прийти как Map или String)
  static String _extractId(dynamic field) {
    if (field == null) return '';
    if (field is Map) return field['id']?.toString() ?? '';
    return field.toString();
  }

  Future<void> _saveUserToLocal(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user['id'].toString());
    await prefs.setString('phone', user['phone'] ?? '');
    await prefs.setString('name', user['name'] ?? '');
    await prefs.setString('surname', user['surname'] ?? '');
    await prefs.setString('role', user['role'] ?? 'client');
    await prefs.setString('status', user['status'] ?? 'pending');
    await prefs.setString('shop_address', user['address'] ?? '');
    // Категория магазина (slug). Может прийти как string slug или Map (expanded m2o).
    final rawCat = user['category'];
    final categorySlug = rawCat == null
        ? ''
        : rawCat is Map
            ? (rawCat['id']?.toString() ?? '')
            : rawCat.toString();
    await prefs.setString('category', categorySlug);

    // rejection_reasons — массив string-кодов. Сохраняем как StringList.
    final rawReasons = user['rejection_reasons'];
    final reasons = rawReasons is List
        ? rawReasons.map((e) => e.toString()).toList()
        : (rawReasons is String && rawReasons.isNotEmpty
            ? rawReasons.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
            : <String>[]);
    await prefs.setStringList('rejection_reasons', reasons);
    await prefs.setDouble('rating', (user['rating'] ?? 0.0).toDouble());
    await prefs.setDouble(
      'balance_points',
      (user['balance_points'] ?? 0.0).toDouble(),
    );
    await prefs.setDouble(
      'wallet_balance',
      (user['wallet_balance'] ?? 0.0).toDouble(),
    );

    // ─── Локация — сохраняем и ID и названия ──────────────────────────────
    final dist = user['district'];
    final etr = user['etrap'];
    final prov = user['province'];

    // District
    await prefs.setString('district_id', _extractId(dist));
    if (dist is Map) {
      await prefs.setString('district_ru', dist['district_ru'] ?? '');
      await prefs.setString('district_tk', dist['district_tk'] ?? '');
    }

    // Etrap
    await prefs.setString('etrap_id', _extractId(etr));
    if (etr is Map) {
      await prefs.setString('etrap_ru', etr['etrap_ru'] ?? '');
      await prefs.setString('etrap_tk', etr['etrap_tk'] ?? '');
    }

    // Province
    await prefs.setString('province_id', _extractId(prov));
    if (prov is Map) {
      await prefs.setString('province_ru', prov['province_ru'] ?? '');
      await prefs.setString('province_tk', prov['province_tk'] ?? '');
    }

    await prefs.setBool('is_logged_in', true);
    debugPrint(
      "✅ Локальный кэш обновлен. "
      "province=${_extractId(prov)} "
      "etrap=${_extractId(etr)} "
      "district=${_extractId(dist)}",
    );
  }

  static Future<bool> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Preserve device-level flags that survive across sessions —
    // тема, язык и onboarding не должны сбрасываться при смене аккаунта.
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final savedLang = prefs.getString('language_code');
    final selectedLang = prefs.getString('selected_lang');
    final isDarkMode = prefs.getBool('is_dark_mode');
    // Account-scoped тур-состояния всех пользователей — чтобы возврат
    // на старый аккаунт не показывал гид заново.
    final tourSnapshot = TourManager.instance.snapshotAllTourKeys();
    await prefs.clear();
    if (onboardingDone) await prefs.setBool('onboarding_done', true);
    if (savedLang != null) await prefs.setString('language_code', savedLang);
    if (selectedLang != null) {
      await prefs.setString('selected_lang', selectedLang);
    }
    if (isDarkMode != null) await prefs.setBool('is_dark_mode', isDarkMode);
    await TourManager.instance.restoreSnapshot(tourSnapshot);
    TourManager.instance.setUserId('');
  }
}
