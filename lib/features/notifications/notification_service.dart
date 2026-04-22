import 'package:bagla/core/api_client.dart';

class NotificationService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getNotifications(String customerId) async {
    try {
      final response = await _api.dio.get(
        '/items/notifications',
        queryParameters: {
          'filter[customer_id][_eq]': customerId,
          'sort': '-date_created',
          'limit': 50,
        },
      );
      return response.data['data'] as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _api.dio.patch(
        '/items/notifications/$notificationId',
        data: {'is_read': true},
      );
    } catch (e) {
      return;
    }
  }

  Future<void> markAllAsRead(String customerId) async {
    try {
      final notifications = await getNotifications(customerId);
      final unread = notifications
          .where((n) => n['is_read'] == false)
          .map((n) => n['id'].toString())
          .toList();

      if (unread.isEmpty) return;

      await _api.dio.patch(
        '/items/notifications',
        data: unread.map((id) => {'id': id, 'is_read': true}).toList(),
      );
    } catch (e) {
      return;
    }
  }

  Future<int> getUnreadCount(String customerId) async {
    try {
      final response = await _api.dio.get(
        '/items/notifications',
        queryParameters: {
          'filter[customer_id][_eq]': customerId,
          'filter[is_read][_eq]': false,
          'aggregate[count]': 'id',
        },
      );
      return response.data['data'][0]['count']['id'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
