import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';

class OrderService {
  final ApiClient _apiClient = ApiClient();

  /// 1. СОЗДАНИЕ ЗАКАЗА
  Future<bool> createOrder({
    required String address,
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
        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        });
        var resFile = await _apiClient.dio.post("/files", data: formData);
        if (resFile.data != null && resFile.data["data"] != null) {
          fileIds.add(resFile.data["data"]["id"]);
        }
      }

      // Считаем кэшбек — 20% от суммы доставки
      final double cashbackAmount = (pointsAmount * 0.2).toDouble();

      final Map<String, dynamic> orderData = {
        "order_status": "published",
        "shopId": [
          {"item": userId, "collection": "customers"},
        ],
        "shop_adress": shopAddress,
        "shop_phone": shopPhone,
        "adress_of_delivery": address,
        "district": districtId,
        "etrap": etrapId,
        "province": provinceId,
        "client_phone": phone.contains('+993') ? phone : "+993 $phone",
        "comment": comment,
        "time_of_delivery": deliveryTime?.toIso8601String(),
        "delivery_amount": deliveryFee,
        "total_amount": itemPrice + deliveryFee,
        "points_amount": pointsAmount,
        "cashback_amount": cashbackAmount, // 20% кэшбек доставщику
        "pictures": fileIds.map((id) => {"directus_files_id": id}).toList(),
      };

      final response = await _apiClient.dio.post(
        "/items/orders",
        data: orderData,
      );

      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['errors']?[0]?['message'] ?? e.message;
      print("Ошибка при создании заказа (Dio): $errorMsg");
      throw Exception("Не удалось создать заказ: $errorMsg");
    } catch (e) {
      print("Неизвестная ошибка в OrderService: $e");
      return false;
    }
  }

  /// 2. ОБНОВЛЕНИЕ СТАТУСА ЗАКАЗА
  Future<bool> updateStatus(
    String orderId,
    String newStatus, {
    String? userId,
    String? courierPhone,
    String? cancelReason,
    String? shopId,
  }) async {
    try {
      final Map<String, dynamic> data = {"order_status": newStatus};

      if (newStatus == 'active' && userId != null) {
        data["courierId"] = [
          {"item": userId, "collection": "customers"},
        ];
      }

      if (newStatus == 'canceled' && shopId != null) {
        data["cancelled_by"] = "shop";
      }

      if (courierPhone != null) data["courier_phone"] = courierPhone;
      if (cancelReason != null) data["cancel_reason"] = cancelReason;

      await _apiClient.dio.patch("/items/orders/$orderId", data: data);
      return true;
    } catch (e) {
      print("Ошибка обновления статуса: $e");
      return false;
    }
  }

  /// 3. ПОЛУЧЕНИЕ СПИСКА ЗАКАЗОВ
  Future<List<dynamic>> getOrders({
    required String role,
    required String userId,
    bool myOrdersOnly = false,
  }) async {
    try {
      List<String> filters = [];

      if (role == 'courier') {
        if (myOrdersOnly) {
          filters.add("filter[courierId][item:customers][id][_eq]=$userId");
        } else {
          filters.add("filter[order_status][_nin]=completed,canceled");
          filters.add("filter[courierId][_null]=true");
        }
      } else if (role == 'shop') {
        filters.add("filter[shopId][item:customers][id][_eq]=$userId");
      } else {
        // 👇 ВАЖНО: только свободные заказы (без курьера)
        filters.add("filter[courierId][_null]=true");
        filters.add("filter[order_status][_nin]=completed,canceled");
      }

      final String filterQuery = filters.isNotEmpty ? filters.join('&') : "";
      final String url =
          "/items/orders?$filterQuery&sort=-date_created&fields=*,pictures.directus_files_id&limit=-1";

      final response = await _apiClient.dio.get(url);

      if (response.data != null && response.data["data"] != null) {
        return response.data["data"] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Ошибка получения заказов: $e");
      return [];
    }
  }

  /// 4. НАЧИСЛЕНИЕ КЭШБЕКА ДОСТАВЩИКУ
  /// Вызывается после успешного закрытия заказа через код подтверждения
  Future<void> applyCashbackIfOnTime({
    required String orderId,
    required String courierId,
  }) async {
    try {
      // Читаем заказ
      final orderResp = await _apiClient.dio.get(
        '/items/orders/$orderId',
        queryParameters: {
          'fields': 'cashback_amount,time_of_delivery,courierId',
        },
      );

      final order = orderResp.data['data'];
      final double cashback = (order['cashback_amount'] ?? 0.0).toDouble();
      final String? timeOfDelivery = order['time_of_delivery'];

      if (cashback <= 0) return;

      // Проверяем не просрочен ли заказ
      bool isOnTime = true;
      if (timeOfDelivery != null && timeOfDelivery.isNotEmpty) {
        final DateTime deadline = DateTime.parse(timeOfDelivery).toLocal();
        final DateTime now = DateTime.now();
        isOnTime = now.isBefore(deadline);
      }

      if (!isOnTime) {
        print("⏰ Заказ просрочен — кэшбек не начисляется");
        return;
      }

      // Читаем текущий баланс курьера
      final courierResp = await _apiClient.dio.get(
        '/items/customers/$courierId',
        queryParameters: {'fields': 'balance_points'},
      );

      final int currentPoints =
          (courierResp.data['data']['balance_points'] ?? 0) as int;
      final int newPoints = currentPoints + cashback.toInt();

      // Начисляем кэшбек
      await _apiClient.dio.patch(
        '/items/customers/$courierId',
        data: {'balance_points': newPoints},
      );

      print(
        "✅ Кэшбек начислен: +${cashback.toInt()} жетонов курьеру $courierId",
      );
    } catch (e) {
      print("Ошибка начисления кэшбека: $e");
    }
  }

  // Хелпер для парсинга ответа Flow
  Map<String, dynamic> _parseFlowResponse(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
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

      final data = _parseFlowResponse(response.data);
      print("generateDeliveryCode data: $data");

      if (data['delivery_code'] != null) {
        return {'success': true, 'code': data['delivery_code'].toString()};
      }

      for (final key in data.keys) {
        final value = data[key];
        if (value is Map) {
          final inner = Map<String, dynamic>.from(value);
          if (inner['delivery_code'] != null) {
            return {'success': true, 'code': inner['delivery_code'].toString()};
          }
        }
      }

      return {'success': false};
    } catch (e) {
      print("Ошибка генерации кода: $e");
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> verifyDeliveryCode({
    required String orderId,
    required String code,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/flows/trigger/6074ab32-630b-406b-9cb5-936c33f8bc42',
        data: {'order_id': orderId, 'code': code},
      );

      final data = _parseFlowResponse(response.data);
      print("verifyDeliveryCode data: $data");

      if (data['success'] != null) {
        return {
          'success': data['success'] == 'yes' || data['success'] == true,
          'message': data['message'] ?? '',
        };
      }

      for (final key in data.keys) {
        final value = data[key];
        if (value is Map) {
          final inner = Map<String, dynamic>.from(value);
          if (inner['success'] != null) {
            return {
              'success': inner['success'] == 'yes' || inner['success'] == true,
              'message': inner['message'] ?? '',
            };
          }
        }
      }

      return {'success': false, 'message': 'Ошибка'};
    } catch (e) {
      print("Ошибка верификации кода: $e");
      return {'success': false, 'message': 'Ошибка сети'};
    }
  }
}
