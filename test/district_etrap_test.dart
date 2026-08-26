import 'package:bagla/models/district.dart';
import 'package:flutter_test/flutter_test.dart';

/// В создании заказа больше нет выбора велаята и этрапа: велаят берётся из
/// профиля магазина, а этрап — из выбранного района. Значит район обязан
/// принести этрап с собой, иначе адрес заказа соберётся неполным.
void main() {
  group('District.fromJson — этрап', () {
    test('развёрнутая связь даёт id и оба названия', () {
      final d = District.fromJson({
        'id': 21,
        'district_ru': '10 мкр',
        'district_tk': '10 mkr',
        'etrap': {'id': 59, 'etrap_ru': 'Ашхабад', 'etrap_tk': 'Aşgabat'},
      });
      expect(d.id, '21');
      expect(d.etrapId, '59');
      expect(d.etrapRu, 'Ашхабад');
      expect(d.etrapTk, 'Aşgabat');
    });

    test('связь пришла числом — берём хотя бы идентификатор', () {
      // Так отвечает старый запрос getDistrictsByEtrap: там etrap не
      // разворачивают, и названий в ответе нет.
      final d = District.fromJson({
        'id': 22,
        'district_ru': '11 мкр',
        'district_tk': '11 mkr',
        'etrap': 59,
      });
      expect(d.etrapId, '59');
      expect(d.etrapRu, '');
      expect(d.etrapTk, '');
    });

    test('связи нет — разбор не падает', () {
      final d = District.fromJson({
        'id': 23,
        'district_ru': 'Арзув',
        'district_tk': 'Arzuw',
      });
      expect(d.id, '23');
      expect(d.etrapId, '');
      expect(d.etrapRu, '');
      expect(d.etrapTk, '');
    });

    test('числовой id района приводится к строке', () {
      expect(District.fromJson({'id': 7}).id, '7');
    });
  });
}
