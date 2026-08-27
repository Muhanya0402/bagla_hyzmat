import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';

/// Приглашение друга.
class Referral {
  final int id;
  final String phone;

  /// `invited` — ждём регистрации, `registered` — друг зарегистрировался,
  /// `paid` — приз начислен.
  final String status;

  /// Сколько жетонов начислено. Заполняется только у оплаченных.
  final int reward;

  /// Имя приглашённого, если он уже зарегистрировался.
  final String inviteeName;

  const Referral({
    required this.id,
    required this.phone,
    required this.status,
    this.reward = 0,
    this.inviteeName = '',
  });

  bool get isPending => status == 'invited';
  bool get isPaid => status == 'paid';
}

/// Чем закончилась попытка изменить список приглашений.
enum ReferralOutcome {
  ok,

  /// Номер не похож на туркменский.
  badPhone,

  /// Свой собственный номер.
  selfInvite,

  /// Такой номер уже есть в приложении — приглашать можно только новых.
  alreadyRegistered,

  /// Этот номер уже кем-то приглашён.
  alreadyInvited,

  /// Исчерпан потолок неоплаченных приглашений.
  limitReached,

  /// Приглашение не найдено: чужое, несуществующее или уже сработавшее.
  notFound,

  /// Программа выключена в настройках.
  disabled,

  /// Вызывающий не курьер. В обычной работе не встречается.
  notACourier,

  /// Сеть или сервер.
  error,
}

/// Реферальная программа «Приведи друга».
///
/// **Читаем напрямую, пишем только через флоу.** Прав на создание и удаление
/// у приложения нет: Directus не применяет связанный фильтр к праву `create`
/// (проверено 27.08), и любой пользователь смог бы вписать приглашение от
/// чужого имени. Пригласивший определяется на сервере по авторизации.
class ReferralsService {
  final ApiClient _apiClient = ApiClient();

  static const _flowInvite = '07d74030-ac9b-44fe-914d-2841a6e6097a';
  static const _flowCancel = 'c63a32d4-72aa-4429-b25d-9d0d08b00f45';

  /// `61 55 33 03` → `+99361553303`. Пустая строка, если номер не подходит.
  ///
  /// В `customers.phone` формат строго один: `+993` и восемь цифр, без
  /// пробелов — так лежат все записи. Курьер же вводит номер под маской
  /// `## ## ## ##`. Без приведения к общему виду сверка по номеру молча не
  /// находила бы совпадений: ошибок в логах не было бы, приглашения просто
  /// никогда не срабатывали.
  ///
  /// Ту же нормализацию делает сервер — здесь она нужна, чтобы поймать
  /// опечатку до отправки и не гонять заведомо плохой запрос.
  static String normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    // Номер могли ввести полностью: «+993 61 55 33 03» или «99361553303».
    final local = digits.length == 11 && digits.startsWith('993')
        ? digits.substring(3)
        : digits;
    if (local.length != 8) return '';
    return '+993$local';
  }

  /// Разбор ответа флоу. Коды приходят телом, а не исключением: текст
  /// брошенной ошибки Directus наружу не отдаёт.
  static ReferralOutcome parseOutcome(dynamic raw) {
    Map<String, dynamic>? body;
    if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) body = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    if (body == null) return ReferralOutcome.error;

    var r = body;
    if (!r.containsKey('ok') && !r.containsKey('code')) {
      for (final v in body.values) {
        if (v is Map) {
          final nested = Map<String, dynamic>.from(v);
          if (nested.containsKey('ok') || nested.containsKey('code')) {
            r = nested;
            break;
          }
        }
      }
    }

    if (r['ok'] == true) return ReferralOutcome.ok;
    switch ((r['code'] ?? '').toString()) {
      case 'BAD_PHONE':
        return ReferralOutcome.badPhone;
      case 'SELF_INVITE':
        return ReferralOutcome.selfInvite;
      case 'ALREADY_REGISTERED':
        return ReferralOutcome.alreadyRegistered;
      case 'ALREADY_INVITED':
        return ReferralOutcome.alreadyInvited;
      case 'LIMIT_REACHED':
        return ReferralOutcome.limitReached;
      case 'NOT_FOUND':
        return ReferralOutcome.notFound;
      case 'DISABLED':
        return ReferralOutcome.disabled;
      case 'NOT_A_COURIER':
        return ReferralOutcome.notACourier;
      default:
        return ReferralOutcome.error;
    }
  }

  /// Свои приглашения, свежие сверху.
  ///
  /// Фильтр по себе не нужен: право на чтение отдаёт только те строки, где
  /// пригласивший — ты.
  Future<List<Referral>> list() async {
    try {
      final res = await _apiClient.dio.get(
        '/items/referrals',
        queryParameters: {
          'limit': -1,
          'sort': '-date_created',
          'fields': 'id,invited_phone,status,reward_amount,'
              'invitee_id.name,invitee_id.surname',
        },
      );
      final data = res.data?['data'];
      if (data is! List) return [];
      return [
        for (final row in data)
          if (row is Map) _fromRow(Map<String, dynamic>.from(row)),
      ];
    } catch (e) {
      if (kDebugMode) print('ReferralsService.list: $e');
      return [];
    }
  }

  static Referral _fromRow(Map<String, dynamic> row) {
    final invitee = row['invitee_id'];
    final name = invitee is Map
        ? [
            '${invitee['name'] ?? ''}'.trim(),
            '${invitee['surname'] ?? ''}'.trim(),
          ].where((s) => s.isNotEmpty).join(' ')
        : '';
    return Referral(
      id: row['id'] is int
          ? row['id'] as int
          : int.tryParse('${row['id']}') ?? 0,
      phone: '${row['invited_phone'] ?? ''}',
      status: '${row['status'] ?? 'invited'}',
      reward: row['reward_amount'] is num
          ? (row['reward_amount'] as num).toInt()
          : 0,
      inviteeName: name,
    );
  }

  /// Пригласить друга. `phone` — как ввёл человек, под маской.
  Future<ReferralOutcome> invite(String phone) async {
    final normalized = normalizePhone(phone);
    // Ловим опечатку до отправки: сервер ответит тем же кодом, но незачем
    // гонять заведомо плохой запрос.
    if (normalized.isEmpty) return ReferralOutcome.badPhone;
    return _callFlow(_flowInvite, {'phone': normalized});
  }

  /// Убрать своё приглашение, пока друг не зарегистрировался.
  Future<ReferralOutcome> cancel(int rowId) =>
      _callFlow(_flowCancel, {'id': rowId});

  Future<ReferralOutcome> _callFlow(String flowId, Map<String, dynamic> body) async {
    try {
      // Пригласивший НЕ передаётся: сервер берёт его из авторизации.
      final res = await _apiClient.dio.post('/flows/trigger/$flowId', data: body);
      return parseOutcome(res.data);
    } on DioException catch (e) {
      return parseOutcome(e.response?.data);
    } catch (e) {
      if (kDebugMode) print('ReferralsService._callFlow: $e');
      return ReferralOutcome.error;
    }
  }
}
