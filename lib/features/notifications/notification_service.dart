import 'package:bagla/core/api_client.dart';

class NotificationService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getNotifications(
    String customerId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await _api.dio.get(
      '/items/notifications',
      queryParameters: {
        'filter[customer_id][_eq]': customerId,
        'sort': '-date_created',
        'limit': limit,
        'offset': offset,
      },
    );
    return response.data['data'] as List<dynamic>;
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _api.dio.patch(
        '/items/notifications/$notificationId',
        data: {'is_read': true},
      );
    } catch (_) {}
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
    } catch (_) {}
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
      final data = response.data['data'];
      if (data is List && data.isNotEmpty) {
        return int.tryParse(data[0]['count']?['id']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // исправлен: добавлен try/catch
  Future<List<Map<String, dynamic>>> getUnread(String customerId) async {
    try {
      final response = await _api.dio.get(
        '/items/notifications',
        queryParameters: {
          'filter[customer_id][_eq]': customerId,
          'filter[is_read][_eq]': false,
          'sort': '-date_created',
          'limit': 20,
        },
      );
      final items = response.data['data'] as List;
      return items.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
