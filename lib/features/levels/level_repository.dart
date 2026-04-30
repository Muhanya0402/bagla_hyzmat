import 'package:bagla/features/levels/level_definition.dart';
import 'package:flutter/cupertino.dart';
import '../../core/api_client.dart';

class LevelRepository {
  final ApiClient _api = ApiClient();

  /// Получить все уровни с бонусами
  Future<List<LevelDefinition>> getLevels() async {
    try {
      final res = await _api.dio.get(
        '/items/level_definitions',
        queryParameters: {
          'fields':
              'id,level_number,title_ru,title_tk,icon,xp_required,color_hex,'
              'description_ru,description_tk,'
              'bonuses.bonus_type,bonuses.value_number,bonuses.value_text,'
              'bonuses.label_ru,bonuses.label_tk,bonuses.icon',
          'filter[is_active][_eq]': true,
          'sort': 'level_number',
        },
      );
      final List data = res.data['data'];
      return data.map((e) => LevelDefinition.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Ошибка загрузки уровней: $e");
      return [];
    }
  }

  /// Получить текущий уровень и XP пользователя
  Future<Map<String, dynamic>?> getCustomerLevel(String customerId) async {
    try {
      final res = await _api.dio.get(
        '/items/customers/$customerId',
        queryParameters: {
          'fields':
              'experience_points,current_level_id.id,'
              'current_level_id.level_number,current_level_id.title_ru,'
              'current_level_id.title_tk,current_level_id.icon,'
              'current_level_id.color_hex,current_level_id.xp_required',
        },
      );
      return res.data['data'];
    } catch (e) {
      debugPrint("Ошибка загрузки уровня пользователя: $e");
      return null;
    }
  }

  /// История XP (последние N записей)
  Future<List<XpHistory>> getXpHistory(
    String customerId, {
    int limit = 20,
  }) async {
    try {
      final res = await _api.dio.get(
        '/items/xp_history',
        queryParameters: {
          'filter[customer_id][_eq]': customerId,
          'fields':
              'id,xp_amount,xp_before,xp_after,source_type,'
              'level_before,level_after,did_level_up,'
              'description_ru,description_tk,date_created',
          'sort': '-date_created',
          'limit': limit,
        },
      );
      final List data = res.data['data'];
      return data.map((e) => XpHistory.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Ошибка загрузки истории XP: $e");
      return [];
    }
  }

  /// Проверить — был ли level up с момента последнего просмотра
  /// Возвращает запись xp_history с did_level_up=true, если есть непоказанная
  Future<XpHistory?> getPendingLevelUp(String customerId) async {
    try {
      final res = await _api.dio.get(
        '/items/xp_history',
        queryParameters: {
          'filter[customer_id][_eq]': customerId,
          'filter[did_level_up][_eq]': true,
          'filter[shown_to_user][_eq]': false, // поле нужно добавить в Directus
          'fields':
              'id,xp_amount,level_before,level_after,'
              'description_ru,description_tk,date_created',
          'sort': '-date_created',
          'limit': 1,
        },
      );
      final List data = res.data['data'];
      if (data.isNotEmpty) return XpHistory.fromJson(data[0]);
      return null;
    } catch (e) {
      debugPrint("Ошибка проверки level up: $e");
      return null;
    }
  }

  /// Отметить level up как показанный
  Future<void> markLevelUpShown(int xpHistoryId) async {
    try {
      await _api.dio.patch(
        '/items/xp_history/$xpHistoryId',
        data: {'shown_to_user': true},
      );
    } catch (e) {
      debugPrint("Ошибка отметки level up: $e");
    }
  }
}
