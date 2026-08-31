import 'package:flutter/foundation.dart';
import 'package:bagla/core/api_client.dart';

class NotificationService {
  final ApiClient _api = ApiClient();

  /// Глобальный сигнал «состояние прочитанности изменилось».
  /// Бампается в `markAsRead`/`markAllAsRead`. Экраны (notifications_screen)
  /// подписываются и обновляются — чтобы после «Прочитать все» в модалке
  /// список на экране уведомлений освежался сам, без pull-to-refresh.
  static final ValueNotifier<int> readStateRevision = ValueNotifier<int>(0);
  static void _bumpReadState() => readStateRevision.value++;

  /// Глобальный кэш id'шек, помеченных как прочитанные клиентом.
  /// Заполняется в `markAsRead`/`markAllAsRead` и в `applyLocalReadOverrides`
  /// при показе списка — гарантирует, что даже если GET успел проскочить
  /// до того, как PATCH дошёл до сервера, UI всё равно покажет уведомление
  /// прочитанным.
  ///
  /// ⚠️ SECURITY: привязан к `_scopeUserId`. Если в `_assertScope` пришёл
  /// другой userId — кеш АВТОМАТИЧЕСКИ чистится. Раньше singleton жил
  /// между логин-сессиями, и если приложение крашалось между logout/login
  /// нового юзера — он видел «прочитанные» уведомления предыдущего.
  static final Set<String> _locallyReadIds = <String>{};
  static String _scopeUserId = '';

  /// Возвращает копию текущего набора локально прочитанных id'шек.
  /// Использовать в экранах для override'а серверных данных.
  static Set<String> get locallyReadIds => Set.unmodifiable(_locallyReadIds);

  /// Очистить локальный кэш — вызывается на logout.
  static void clearLocallyRead() {
    _locallyReadIds.clear();
    _scopeUserId = '';
  }

  /// Tenant guard: если в singleton приходит запрос для другого юзера —
  /// кеш чистим. Не полагаемся на корректный вызов `clearLocallyRead`
  /// в logout-пути (мог не сработать на крэше).
  static void _assertScope(String userId) {
    if (userId.isEmpty) return;
    if (_scopeUserId.isNotEmpty && _scopeUserId != userId) {
      _locallyReadIds.clear();
    }
    _scopeUserId = userId;
  }

  Future<List<dynamic>> getNotifications(
    String customerId, {
    int limit = 30,
    int offset = 0,
  }) async {
    _assertScope(customerId);
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
    // Локальный override — даже если PATCH упадёт, экран покажет прочитанным.
    _locallyReadIds.add(notificationId);
    _bumpReadState();
    try {
      await _api.dio.patch(
        '/items/notifications/$notificationId',
        data: {'is_read': true},
      );
    } catch (_) {}
  }

  /// Помечает прочитанными ВСЕ непрочитанные уведомления пользователя.
  ///
  /// Раньше список брался через `getNotifications`, а это 30 последних
  /// записей — непрочитанные из более старых туда просто не попадали и
  /// оставались непрочитанными навсегда: пользователь жал «Прочитать все»,
  /// а при следующем запуске снова видел ту же пачку. Теперь непрочитанные
  /// запрашиваются у сервера напрямую, без окна.
  ///
  /// Бросает исключение, если сервер не принял изменение — вызывающий код
  /// не должен показывать подтверждение, когда на деле ничего не сохранилось.
  Future<void> markAllAsRead(String customerId) async {
    _assertScope(customerId);

    final response = await _api.dio.get(
      '/items/notifications',
      queryParameters: {
        'filter[customer_id][_eq]': customerId,
        'filter[is_read][_eq]': false,
        'fields': 'id',
        'limit': -1,
      },
    );
    final unread = (response.data['data'] as List)
        .map((n) => n['id'].toString())
        .toList();

    if (unread.isEmpty) return;

    // Локальный override: добавляем сразу, ДО PATCH'а — гарантирует
    // что параллельные GET'ы увидят их прочитанными.
    _locallyReadIds.addAll(unread);
    _bumpReadState(); // уведомить открытый notifications_screen

    try {
      // Пачками — на случай, когда непрочитанных накопились сотни.
      for (var i = 0; i < unread.length; i += 100) {
        final chunk = unread.sublist(
          i,
          i + 100 > unread.length ? unread.length : i + 100,
        );
        await _api.dio.patch(
          '/items/notifications',
          data: {
            'keys': chunk,
            'data': {'is_read': true},
          },
        );
      }
    } catch (_) {
      // Сервер не принял — снимаем локальную отметку, иначе экран будет
      // показывать прочитанным то, что на сервере таковым не стало.
      _locallyReadIds.removeAll(unread);
      _bumpReadState();
      rethrow;
    }
  }

  Future<int> getUnreadCount(String customerId) async {
    _assertScope(customerId);
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
    _assertScope(customerId);
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
