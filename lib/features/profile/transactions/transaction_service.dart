import 'package:bagla/core/api_client.dart';
import 'package:flutter/foundation.dart';

/// Вид операции в истории транзакций курьера.
enum TxKind {
  /// Пополнение баланса на сумму (деньги) + начисленные жетоны.
  topUp,

  /// Списание жетонов за конкретный заказ.
  orderDebit,

  /// Начисление жетонов по кэшбеку за доставку в срок.
  cashback,

  /// Ежедневный бонус жетонами за уровень.
  dailyBonus,

  /// Прочее начисление жетонов.
  other,
}

/// Одна запись истории транзакций.
class TransactionEntry {
  final DateTime? date;
  final TxKind kind;

  /// Изменение баланса жетонов: положительное — начисление, отрицательное —
  /// списание.
  final double tokens;

  /// Сумма пополнения деньгами (только для [TxKind.topUp]).
  final double? money;

  /// Короткий id заказа (для списания за заказ).
  final String? orderShortId;

  /// Комментарий из журнала (если есть).
  final String comment;

  const TransactionEntry({
    required this.date,
    required this.kind,
    required this.tokens,
    this.money,
    this.orderShortId,
    this.comment = '',
  });
}

class TransactionService {
  final ApiClient _api = ApiClient();

  static DateTime? _parseDate(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  static String? _firstM2AItem(dynamic field) {
    if (field is List && field.isNotEmpty) {
      final first = field.first;
      if (first is Map) return first['item']?.toString();
    }
    return null;
  }

  /// Полная история транзакций пользователя: движения жетонов
  /// (`points_transactions`) + денежные пополнения (`customer_balance`),
  /// слитые в один список по дате (новые сверху).
  Future<List<TransactionEntry>> fetchHistory(String userId) async {
    if (userId.isEmpty) return const [];
    final entries = <TransactionEntry>[];

    // ── Движения жетонов ──────────────────────────────────────────────────
    try {
      final resp = await _api.dio.get(
        '/items/points_transactions',
        queryParameters: {
          'filter[customer_id][item:customers][id][_eq]': userId,
          'fields': 'id,type,amount,comment,date_created,order_id.item',
          'sort': '-date_created',
          'limit': 200,
        },
      );
      final data = resp.data?['data'];
      if (data is List) {
        for (final raw in data) {
          if (raw is! Map) continue;
          final type = (raw['type'] ?? '').toString().toLowerCase();
          final amount = _toDouble(raw['amount']);
          final TxKind kind;
          final double tokens;
          switch (type) {
            case 'debit':
              kind = TxKind.orderDebit;
              tokens = -amount.abs();
              break;
            case 'cashback':
              kind = TxKind.cashback;
              tokens = amount.abs();
              break;
            case 'daily_bonus':
              kind = TxKind.dailyBonus;
              tokens = amount.abs();
              break;
            default:
              kind = TxKind.other;
              // type 'credit' и пр. — считаем начислением.
              tokens = type == 'credit' ? amount.abs() : amount;
          }
          entries.add(
            TransactionEntry(
              date: _parseDate(raw['date_created']),
              kind: kind,
              tokens: tokens,
              orderShortId: _firstM2AItem(raw['order_id']),
              comment: (raw['comment'] ?? '').toString(),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchHistory points_transactions error: $e');
    }

    // ── Денежные пополнения ───────────────────────────────────────────────
    try {
      final resp = await _api.dio.get(
        '/items/customer_balance',
        queryParameters: {
          'filter[customer_ID][item:customers][id][_eq]': userId,
          'fields': 'id,amountToBeReplenished,points,date_created',
          'sort': '-date_created',
          'limit': 200,
        },
      );
      final data = resp.data?['data'];
      if (data is List) {
        for (final raw in data) {
          if (raw is! Map) continue;
          entries.add(
            TransactionEntry(
              date: _parseDate(raw['date_created']),
              kind: TxKind.topUp,
              tokens: _toDouble(raw['points']),
              money: _toDouble(raw['amountToBeReplenished']),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchHistory customer_balance error: $e');
    }

    // Сортировка по дате (новые сверху); записи без даты — в конец.
    entries.sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return entries;
  }
}
