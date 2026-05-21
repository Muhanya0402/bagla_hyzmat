import '../models/points_rule.dart';

int calculatePoints(double orderSum, List<PointsRule> rules) {
  // rules должны быть отсортированы по убыванию min_amount
  for (final rule in rules) {
    if (orderSum >= rule.minAmount) return rule.points;
  }
  return 0;
}
