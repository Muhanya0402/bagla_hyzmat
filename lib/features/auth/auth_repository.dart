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

      final response = await _api.dio.post(
        '/items/otp_codes',
        data: {'identifier': phone.trim()},
        options: Options(
          headers: {'Authorization': 'Bearer 8TYMndErscy0GgMcVcO1u_jLD-6GaqMD'},
        ),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      debugPrint("Ошибка SEND_OTP: ${e.response?.data}");
      return false;
    }
  }

  Future<Map<String, dynamic>?> verifyOTP(String phone, String code) async {
    try {
      final response = await _api.dio.post(
        '/flows/trigger/851636a4-92c7-40e5-993b-e9d41fdeff73',
        data: {'identifier': phone.trim(), 'code': code.trim()},
        options: Options(
          headers: {'Authorization': 'Bearer 8TYMndErscy0GgMcVcO1u_jLD-6GaqMD'},
        ),
      );

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
      debugPrint("Ошибка verifyOTP: ${e.response?.data}");
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

  /// Получение профиля — запрашиваем district, etrap, province вложенно
  Future<Map<String, dynamic>?> fetchProfileFromServer(String phone) async {
    try {
      final response = await _api.dio.get(
        '/items/customers',
        queryParameters: {
          'filter[phone][_eq]': phone.trim(),
          'fields':
              'id,phone,name,surname,role,status,rating,balance_points,address,'
              'district.id,etrap.id,province.id',
        },
      );

      final List data = response.data['data'];
      if (data.isNotEmpty) {
        final user = data[0];
        debugPrint("📡 Получен статус от сервера: ${user['status']}");
        await _saveUserToLocal(user);
        return user;
      }
      return null;
    } catch (e) {
      debugPrint("Ошибка запроса профиля: $e");
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

  /// Вспомогательная функция — достать ID из M2O поля (может прийти как Map или String/int)
  static String _extractId(dynamic field) {
    if (field == null) return '';
    if (field is Map) return field['id']?.toString() ?? '';
    return field.toString();
  }

  Future<void> _saveUserToLocal(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user['id'].toString());
    await prefs.setString('phone', user['phone'] ?? "");
    await prefs.setString('name', user['name'] ?? "");
    await prefs.setString('surname', user['surname'] ?? "");
    await prefs.setString('role', user['role'] ?? "client");
    await prefs.setString('status', user['status'] ?? "pending");
    await prefs.setString('shop_address', user['address'] ?? "");
    await prefs.setDouble('rating', (user['rating'] ?? 0.0).toDouble());
    await prefs.setInt('balance_points', user['balance_points'] ?? 0);

    // ─── Локация ───────────────────────────────────────────────────────────
    await prefs.setString('district_id', _extractId(user['district']));
    await prefs.setString('etrap_id', _extractId(user['etrap']));
    await prefs.setString('province_id', _extractId(user['province']));

    await prefs.setBool('is_logged_in', true);
    debugPrint(
      "✅ Локальный кэш обновлен. "
      "district=${_extractId(user['district'])} "
      "etrap=${_extractId(user['etrap'])} "
      "province=${_extractId(user['province'])}",
    );
  }

  static Future<bool> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
