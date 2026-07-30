/// Правило кэшбека курьеру за доставку в срок.
///
/// Настраивается в Directus (коллекция `cashback_rule`): от какой суммы
/// доставки [minAmount] сколько жетонов [cashback] вернуть курьеру.
/// Кэшбек — ЦЕЛОЕ число жетонов: раньше он считался как процент от списания
/// (`points * 0.2`), давал дробные значения вроде 0.4 и обнулялся при
/// начислении через `toInt()`.
class CashbackRule {
  final double minAmount;
  final int cashback;

  const CashbackRule({required this.minAmount, required this.cashback});

  factory CashbackRule.fromJson(Map<String, dynamic> json) => CashbackRule(
    minAmount: (json['min_amount'] as num?)?.toDouble() ?? 0,
    cashback: (json['cashback'] as num?)?.toInt() ?? 0,
  );
}
