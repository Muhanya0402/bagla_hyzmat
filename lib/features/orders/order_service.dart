import 'dart:convert';
import 'package:bagla/models/points_rule.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';

class OrderService {
  final ApiClient _apiClient = ApiClient();

  static const int pageSize = 5;

  // ─── 1. СОЗДАНИЕ ЗАКАЗА ───────────────────────────────────────────────────

  Future<bool> createOrder({
    required String address, // адрес доставки (ru)
    required String addresstk, // адрес доставки (tk)
    required String shopAddress, // адрес магазина (ru)
    required String shopAddressTk, // адрес магазина (tk)  ← новый
    required String transportType,
    required String phone,
    required String comment,
    required DateTime? deliveryTime,
    required double itemPrice,
    required double deliveryFee,
    required int pointsAmount,
    required List<XFile> images,
    required String userId,
    required String shopPhone,
    required String? districtId,
    required String? etrapId,
    required String provinceId,
    // ── Локация магазина (откуда забирать) ────────────────────────────────
    required String? shopDistrictId,
    required String? shopEtrapId,
    required String? shopProvinceId,
    // ── Категория магазина (m2o → shop_categories) ────────────────────────
    String? category,
  }) async {
    try {
      List<String> fileIds = [];
      for (var image in images) {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        });
        final resFile = await _apiClient.dio.post('/files', data: formData);
        if (resFile.data?['data'] != null) {
          fileIds.add(resFile.data['data']['id']);
        }
      }

      final double cashbackAmount = (pointsAmount * 0.2).toDouble();

      final orderData = {
        'order_status': 'published',
        'shopId': [
          {'item': userId, 'collection': 'customers'},
        ],

        // ── Адрес магазина (откуда) ────────────────────────────────────────
        'shop_adress': shopAddress,
        'shop_adresstk': shopAddressTk,

        // ── Локация магазина ───────────────────────────────────────────────
        'shop_district': shopDistrictId != null
            ? tryParse(shopDistrictId)
            : null,
        'shop_etrap': shopEtrapId != null ? tryParse(shopEtrapId) : null,
        'shop_province': shopProvinceId != null && shopProvinceId.isNotEmpty
            ? tryParse(shopProvinceId)
            : null,

        'transport_type': transportType,
        'shop_phone': shopPhone,

        // ── Адрес доставки (куда) ──────────────────────────────────────────
        'adress_of_delivery': address,
        'adress_of_deliverytk': addresstk,

        // ── Локация доставки ───────────────────────────────────────────────
        'district': districtId != null ? tryParse(districtId) : null,
        'etrap': etrapId != null ? tryParse(etrapId) : null,
        'province': tryParse(provinceId),

        'client_phone': phone.contains('+993') ? phone : '+993 $phone',
        'comment': comment,
        'time_of_delivery': deliveryTime?.toIso8601String(),
        'delivery_amount': deliveryFee,
        'total_amount': itemPrice + deliveryFee,
        'points_amount': pointsAmount,
        'cashback_amount': cashbackAmount,
        'pictures': fileIds.map((id) => {'directus_files_id': id}).toList(),
        // Категория магазина — slug из shop_categories.
        if (category != null && category.isNotEmpty) 'category': category,
      };

      final response = await _apiClient.dio.post(
        '/items/orders',
        data: orderData,
      );
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } on DioException catch (e) {
      if (e.response != null) {
        if (kDebugMode) print('ОТВЕТ СЕРВЕРА: ${e.response?.data}');
        final errors = e.response?.data['errors'];
        if (errors is List && errors.isNotEmpty) {
          if (kDebugMode) print('ПРИЧИНА: ${errors[0]['message']}');
          if (kDebugMode) print('ДЕТАЛИ: ${errors[0]['extensions']}');
        }
      }
      throw Exception(
        'Не удалось создать заказ: ${e.response?.data?['errors']?[0]?['message'] ?? e.message}',
      );
    } catch (e) {
      if (kDebugMode) print('Неизвестная ошибка createOrder: $e');
      return false;
    }
  }

  int? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return int.tryParse(value);
  }

  // ─── 2. ОБНОВЛЕНИЕ СТАТУСА ────────────────────────────────────────────────

  Future<bool> updateStatus(
    String orderId,
    String newStatus, {
    String? userId,
    String? courierPhone,
    String? cancelReason,
    String? shopId,
  }) async {
    try {
      final Map<String, dynamic> data = {'order_status': newStatus};
      if (newStatus == 'active' && userId != null) {
        data['courierId'] = [
          {'item': userId, 'collection': 'customers'},
        ];
      }
      if (newStatus == 'canceled' && shopId != null) {
        data['cancelled_by'] = 'shop';
      }
      if (courierPhone != null) data['courier_phone'] = courierPhone;
      if (cancelReason != null) data['cancel_reason'] = cancelReason;

      await _apiClient.dio.patch('/items/orders/$orderId', data: data);
      return true;
    } catch (e) {
      if (kDebugMode) print('Ошибка updateStatus: $e');
      return false;
    }
  }

  // ─── 3. ПОЛУЧЕНИЕ ЗАКАЗОВ С ПАГИНАЦИЕЙ ───────────────────────────────────

  Future<List<dynamic>> getOrders({
    required String role,
    required String userId,
    bool myOrdersOnly = false,
    int offset = 0,
    int limit = pageSize,
    // ── Серверные фильтры ──────────────────────────────────────────
    String? transportFilter,
    String? shopProvinceId,
    String? shopEtrapId,
    String? shopDistrictId,
    String? deliveryProvinceId,
    String? deliveryEtrapId,
    String? deliveryDistrictId,
    String? shopPhone,
    String? orderStatus,
    String? categoryFilter,
  }) async {
    try {
      final filters = <String>[];

      if (role == 'courier') {
        if (myOrdersOnly) {
          filters.add('filter[courierId][item:customers][id][_eq]=$userId');
        } else {
          filters.add('filter[order_status][_nin]=completed,canceled');
          filters.add('filter[courierId][_null]=true');
        }
      } else if (role == 'shop' || role == 'business') {
        filters.add('filter[shopId][item:customers][id][_eq]=$userId');
      } else {
        filters.add('filter[courierId][_null]=true');
        filters.add('filter[order_status][_nin]=completed,canceled');
      }

      // ── Серверная фильтрация ───────────────────────────────────────
      if (transportFilter != null && transportFilter != 'any') {
        filters.add('filter[transport_type][_eq]=$transportFilter');
      }
      if (shopProvinceId != null) {
        filters.add('filter[shop_province][_eq]=$shopProvinceId');
      }
      if (shopEtrapId != null) {
        filters.add('filter[shop_etrap][_eq]=$shopEtrapId');
      }
      if (shopDistrictId != null) {
        filters.add('filter[shop_district][_eq]=$shopDistrictId');
      }
      if (deliveryProvinceId != null) {
        filters.add('filter[province][_eq]=$deliveryProvinceId');
      }
      if (deliveryEtrapId != null) {
        filters.add('filter[etrap][_eq]=$deliveryEtrapId');
      }
      if (deliveryDistrictId != null) {
        filters.add('filter[district][_eq]=$deliveryDistrictId');
      }
      if (shopPhone != null) {
        filters.add('filter[shop_phone][_eq]=$shopPhone');
      }
      if (orderStatus != null) {
        filters.add('filter[order_status][_eq]=$orderStatus');
      }
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        filters.add('filter[category][_eq]=$categoryFilter');
      }
      // ─────────────────────────────────────────────────────────────

      final filterQuery = filters.join('&');
      final url =
          '/items/orders'
          '?$filterQuery'
          '&sort=-date_created'
          '&fields=*,pictures.directus_files_id'
          ',district.id,district.district_ru,district.district_tk'
          ',etrap.id,etrap.etrap_ru,etrap.etrap_tk'
          ',province.id,province.province_ru,province.province_tk'
          ',shop_district.id,shop_district.district_ru,shop_district.district_tk'
          ',shop_etrap.id,shop_etrap.etrap_ru,shop_etrap.etrap_tk'
          ',shop_province.id,shop_province.province_ru,shop_province.province_tk'
          ',courierId.*'
          '&limit=$limit'
          '&offset=$offset';

      final response = await _apiClient.dio.get(url);
      if (response.data?['data'] == null) return [];

      final List<dynamic> orders = response.data['data'] as List<dynamic>;

      final Set<String> courierIds = {};
      for (final order in orders) {
        final courierId = order['courierId'];
        if (courierId is List && courierId.isNotEmpty) {
          final first = courierId[0];
          if (first is Map) {
            final id = first['item']?.toString();
            if (id != null) courierIds.add(id);
          }
        }
      }

      final Map<String, Map<String, dynamic>> courierMap = {};
      if (courierIds.isNotEmpty) {
        try {
          final courierResp = await _apiClient.dio.get(
            '/items/customers',
            queryParameters: {
              'filter[id][_in]': courierIds.join(','),
              'fields': 'id,name,surname',
            },
          );
          final courierData = courierResp.data?['data'];
          if (courierData is List) {
            for (final c in courierData) {
              final id = c['id']?.toString();
              if (id != null) courierMap[id] = Map<String, dynamic>.from(c);
            }
          }
        } catch (_) {}
      }

      for (final order in orders) {
        final courierId = order['courierId'];
        if (courierId is List && courierId.isNotEmpty) {
          final first = courierId[0];
          if (first is Map) {
            final id = first['item']?.toString();
            if (id != null && courierMap.containsKey(id)) {
              final c = courierMap[id]!;
              order['courier_name'] = '${c['name'] ?? ''} ${c['surname'] ?? ''}'
                  .trim();
            }
          }
        }
      }

      return orders;
    } catch (e) {
      if (kDebugMode) print('Ошибка getOrders: $e');
      return [];
    }
  }

  // ─── 4. КЭШБЕК ───────────────────────────────────────────────────────────

  Future<void> applyCashbackIfOnTime({
    required String orderId,
    required String courierId,
  }) async {
    try {
      final orderResp = await _apiClient.dio.get(
        '/items/orders/$orderId',
        queryParameters: {
          'fields': 'cashback_amount,time_of_delivery,courierId',
        },
      );
      final order = orderResp.data['data'];
      final double cashback = (order['cashback_amount'] ?? 0.0).toDouble();
      if (cashback <= 0) return;

      final String? tod = order['time_of_delivery'];
      bool isOnTime = true;
      if (tod != null && tod.isNotEmpty) {
        isOnTime = DateTime.now().isBefore(DateTime.parse(tod).toLocal());
      }
      if (!isOnTime) {
        if (kDebugMode) print('⏰ Просрочен — кэшбек не начислен');
        return;
      }

      final courierResp = await _apiClient.dio.get(
        '/items/customers/$courierId',
        queryParameters: {'fields': 'balance_points'},
      );
      final int current =
          (courierResp.data['data']['balance_points'] ?? 0) as int;
      await _apiClient.dio.patch(
        '/items/customers/$courierId',
        data: {'balance_points': current + cashback.toInt()},
      );
      if (kDebugMode) {
        print('✅ Кэшбек +${cashback.toInt()} → курьер $courierId');
      }
    } catch (e) {
      if (kDebugMode) print('Ошибка applyCashback: $e');
    }
  }

  // ─── 5. ГЕНЕРАЦИЯ КОДА ДОСТАВКИ ──────────────────────────────────────────

  Map<String, dynamic> _parseFlow(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return {};
  }

  Future<Map<String, dynamic>> generateDeliveryCode({
    required String orderId,
    required String courierId,
    required String clientPhone,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/flows/trigger/64ece654-d07e-4ff4-a34c-f50d736a3b32',
        data: {
          'order_id': orderId,
          'courier_id': courierId,
          'client_phone': clientPhone,
        },
      );
      final data = _parseFlow(response.data);
      if (kDebugMode) print('generateDeliveryCode: $data');

      if (data['delivery_code'] != null) {
        return {'success': true, 'code': data['delivery_code'].toString()};
      }
      for (final v in data.values) {
        if (v is Map && v['delivery_code'] != null) {
          return {'success': true, 'code': v['delivery_code'].toString()};
        }
      }
      return {'success': false};
    } catch (e) {
      if (kDebugMode) print('Ошибка generateDeliveryCode: $e');
      return {'success': false};
    }
  }

  // ─── 6. ВЕРИФИКАЦИЯ КОДА ДОСТАВКИ ────────────────────────────────────────

  Future<Map<String, dynamic>> verifyDeliveryCode({
    required String orderId,
    required String code,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/flows/trigger/6074ab32-630b-406b-9cb5-936c33f8bc42',
        data: {'order_id': orderId, 'code': code},
      );
      final data = _parseFlow(response.data);
      if (kDebugMode) print('verifyDeliveryCode: $data');

      Map<String, dynamic>? found;
      if (data['success'] != null) {
        found = data;
      } else {
        for (final v in data.values) {
          if (v is Map && v['success'] != null) {
            found = Map<String, dynamic>.from(v);
            break;
          }
        }
      }

      if (found != null) {
        return {
          'success': found['success'] == 'yes' || found['success'] == true,
          'message': found['message'] ?? '',
          'xp_earned': found['xp_earned'] ?? 0,
          'level_up': found['level_up'] ?? false,
        };
      }
      return {
        'success': false,
        'message': 'Ошибка',
        'xp_earned': 0,
        'level_up': false,
      };
    } catch (e) {
      if (kDebugMode) print('Ошибка verifyDeliveryCode: $e');
      return {
        'success': false,
        'message': 'Ошибка сети',
        'xp_earned': 0,
        'level_up': false,
      };
    }
  }

  // ─── 7. КОЛИЧЕСТВО АКТИВНЫХ ЗАКАЗОВ КУРЬЕРА ──────────────────────────────

  Future<int> getActiveOrdersCount(String courierId) async {
    try {
      final response = await _apiClient.dio.get(
        '/items/orders',
        queryParameters: {
          'filter[courierId][item:customers][id][_eq]': courierId,
          'filter[order_status][_eq]': 'active',
          'aggregate[count]': 'id',
        },
      );
      final data = response.data?['data'];
      if (data is List && data.isNotEmpty) {
        return int.tryParse(data[0]['count']?['id']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) print('Ошибка getActiveOrdersCount: $e');
      return 0;
    }
  }

  // ─── 8. ПРАВИЛА НАЧИСЛЕНИЯ БАЛЛОВ ────────────────────────────────────────

  Future<List<PointsRule>> fetchPointsRules() async {
    try {
      final response = await _apiClient.dio.get(
        '/items/points_rules',
        queryParameters: {'sort': '-min_amount'},
      );
      final List data = response.data['data'] as List;
      return data.map((e) => PointsRule.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) print('Ошибка fetchPointsRules: $e');
      // fallback — старая логика, если Directus недоступен
      return [
        PointsRule(minAmount: 2000, points: 5),
        PointsRule(minAmount: 1000, points: 4),
        PointsRule(minAmount: 500, points: 3),
        PointsRule(minAmount: 100, points: 2),
        PointsRule(minAmount: 0, points: 0),
      ];
    }
  }

  int calculatePoints(double orderSum, List<PointsRule> rules) {
    for (final rule in rules) {
      if (orderSum >= rule.minAmount) return rule.points;
    }
    return 0;
  }
}
