import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart'; // Убедитесь, что путь к вашему ApiClient верен

class OrderService {
  final ApiClient _apiClient = ApiClient();

  /// 1. СОЗДАНИЕ ЗАКАЗА
  /// Загружает изображения, получает их ID и создает запись в коллекции orders
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
  }) async {
    try {
      List<String> fileIds = [];

      // Шаг A: Загрузка изображений в Directus (коллекция /files)
      for (var image in images) {
        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        });

        // Отправляем файл. Если токен истек, ApiClient сам его обновит
        var resFile = await _apiClient.dio.post("/files", data: formData);

        if (resFile.data != null && resFile.data["data"] != null) {
          fileIds.add(resFile.data["data"]["id"]);
        }
      }

      // Шаг B: Формирование структуры заказа
      // ВАЖНО: Убедитесь, что системное поле статуса в Directus называется 'status' или 'order_status'
      final Map<String, dynamic> orderData = {
        "order_status": "published", // Системное поле Directus для отображения
        "shopId": [
          {
            "item": userId,
            "collection": "customers", // Связь M2M (Many-to-Many)
          },
        ],
        "shop_adress": shopAddress,
        "shop_phone": shopPhone,
        "adress_of_delivery": address,
        "client_phone": phone.contains('+993') ? phone : "+993 $phone",
        "comment": comment,
        "time_of_delivery": deliveryTime?.toIso8601String(),
        "delivery_amount": deliveryFee,
        "total_amount": itemPrice + deliveryFee,
        "points_amount": pointsAmount,
        // Формат для загрузки картинок в реляционное поле (M2M с directus_files)
        "pictures": fileIds.map((id) => {"directus_files_id": id}).toList(),
      };

      // Шаг C: Отправка заказа
      final response = await _apiClient.dio.post(
        "/items/orders",
        data: orderData,
      );

      return response.statusCode == 200 || response.statusCode == 204;
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
  /// Используется для принятия заказа курьером, отмены или завершения
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

      // Курьер берёт заказ
      if (newStatus == 'active' && userId != null) {
        data["courierId"] = [
          {"item": userId, "collection": "customers"},
        ];
      }

      // Магазин отменяет заказ
      if (newStatus == 'cancelled' && shopId != null) {
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
  /// Включает фильтрацию по ролям и подгрузку связанных файлов
  Future<List<dynamic>> getOrders({
    required String role,
    required String userId,
    bool myOrdersOnly = false,
  }) async {
    try {
      List<String> filters = [];

      if (role == 'courier') {
        if (myOrdersOnly) {
          // Заказы текущего курьера
          filters.add("filter[courierId][item:customers][id][_eq]=$userId");
        } else {
          // Все доступные новые заказы для всех курьеров
          filters.add("filter[order_status][_eq]=published");
        }
      } else if (role == 'shop') {
        // Заказы конкретного магазина
        filters.add("filter[shopId][item:customers][id][_eq]=$userId");
      } else if (role == 'client') {
        // Заказы клиента (если есть связь clientId)
        // filters.add("filter[user_created][_eq]=$userId");
      }

      // Сборка Query параметров
      final String filterQuery = filters.isNotEmpty ? filters.join('&') : "";

      // fields=* подгружает все поля, pictures.directus_files_id — ID файлов для Image.network
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
}
