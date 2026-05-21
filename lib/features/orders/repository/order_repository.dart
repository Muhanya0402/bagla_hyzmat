import 'package:bagla/core/api_client.dart';
import 'package:bagla/models/points_rule.dart';

class OrderRepository {
  Future<List<PointsRule>> fetchPointsRules() async {
    final ApiClient _api = ApiClient();
    final response = await _api.dio.get(
      '/items/points_rules',
      queryParameters: {'sort': '-min_amount'},
    );
    final List data = response.data['data'] as List;
    return data.map((e) => PointsRule.fromJson(e)).toList();
  }
}
