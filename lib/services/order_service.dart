import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';

class OrderService {
  final ApiClient _apiClient = ApiClient();

  static const int pageSize = 5; // заказов за один запрос

  // ─── 1. СОЗДАНИЕ ЗАКАЗА ───────────────────────────────────────────────────

  Future<bool> createOrder({
    required String address,
    required String addresstk,
    required String shopAddress,
    required String phone,
    required String comment,
    required DateTime? deliveryTime,
    required double itemPrice,
    required double deliveryFee,
    required int pointsAmount,
    required List<XFile> images,
    required String userId,
    required String shopPhone,
    required String districtId,
    required String etrapId,
    required String provinceId,
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
        'shop_adress': shopAddress,
        'shop_phone': shopPhone,
        'adress_of_delivery': address,
        'adress_of_deliverytk': addresstk,
        'district': tryParse(districtId),
        'etrap': tryParse(etrapId),
        'province': tryParse(provinceId),
        'client_phone': phone.contains('+993') ? phone : '+993 $phone',
        'comment': comment,
        'time_of_delivery': deliveryTime?.toIso8601String(),
        'delivery_amount': deliveryFee,
        'total_amount': itemPrice + deliveryFee,
        'points_amount': pointsAmount,
        'cashback_amount': cashbackAmount,
        'pictures': fileIds.map((id) => {'directus_files_id': id}).toList(),
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
        print('ОТВЕТ СЕРВЕРА: ${e.response?.data}');
        final errors = e.response?.data['errors'];
        if (errors is List && errors.isNotEmpty) {
          print('ПРИЧИНА: ${errors[0]['message']}');
          print('ДЕТАЛИ: ${errors[0]['extensions']}');
        }
      }
      throw Exception(
        'Не удалось создать заказ: ${e.response?.data?['errors']?[0]?['message'] ?? e.message}',
      );
    } catch (e) {
      print('Неизвестная ошибка createOrder: $e');
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
      print('Ошибка updateStatus: $e');
      return false;
    }
  }

  // ─── 3. ПОЛУЧЕНИЕ ЗАКАЗОВ С ПАГИНАЦИЕЙ ───────────────────────────────────
  //
  // offset = 0  → первые 5 заказов
  // offset = 5  → следующие 5
  // offset = 10 → ещё 5
  // ...
  // Возвращает пустой список когда заказы кончились.

  Future<List<dynamic>> getOrders({
    required String role,
    required String userId,
    bool myOrdersOnly = false,
    int offset = 0, // ← новый параметр
    int limit = pageSize, // ← новый параметр
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

      final filterQuery = filters.join('&');
      final url =
          '/items/orders'
          '?$filterQuery'
          '&sort=-date_created'
          '&fields=*,pictures.directus_files_id'
          '&limit=$limit'
          '&offset=$offset';

      final response = await _apiClient.dio.get(url);
      if (response.data?['data'] != null) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Ошибка getOrders: $e');
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
        print('⏰ Просрочен — кэшбек не начислен');
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
      print('✅ Кэшбек +${cashback.toInt()} → курьер $courierId');
    } catch (e) {
      print('Ошибка applyCashback: $e');
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
      print('generateDeliveryCode: $data');

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
      print('Ошибка generateDeliveryCode: $e');
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
      print('verifyDeliveryCode: $data');

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
      print('Ошибка verifyDeliveryCode: $e');
      return {
        'success': false,
        'message': 'Ошибка сети',
        'xp_earned': 0,
        'level_up': false,
      };
    }
  }
}
