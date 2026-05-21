class PointsRule {
  final double minAmount;
  final int points;

  const PointsRule({required this.minAmount, required this.points});

  factory PointsRule.fromJson(Map<String, dynamic> json) => PointsRule(
    minAmount: (json['min_amount'] as num).toDouble(),
    points: (json['points'] as num).toInt(),
  );
}
