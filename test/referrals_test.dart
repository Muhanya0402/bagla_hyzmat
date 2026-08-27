import 'package:bagla/features/profile/referrals_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Реферальная программа «Приведи друга».
///
/// Нормализация номера — самое хрупкое место всей затеи. В `customers.phone`
/// формат строго `+993` и восемь цифр, а курьер вводит номер под маской
/// `## ## ## ##`. Ошибись здесь — и приглашения просто никогда не сработают,
/// причём молча: ни ошибки, ни записи в логах, друг зарегистрировался, а приз
/// не пришёл.
void main() {
  group('normalizePhone', () {
    test('номер под маской приводится к виду базы', () {
      expect(ReferralsService.normalizePhone('61 55 33 03'), '+99361553303');
      expect(ReferralsService.normalizePhone('65403020'), '+99365403020');
    });

    test('номер, введённый полностью, тоже принимается', () {
      expect(ReferralsService.normalizePhone('+993 61 55 33 03'), '+99361553303');
      expect(ReferralsService.normalizePhone('+99361553303'), '+99361553303');
      expect(ReferralsService.normalizePhone('99361553303'), '+99361553303');
    });

    test('посторонние символы не мешают', () {
      expect(ReferralsService.normalizePhone('(61) 55-33-03'), '+99361553303');
      expect(ReferralsService.normalizePhone(' 61 55 33 03 '), '+99361553303');
    });

    test('неверная длина отвергается', () {
      expect(ReferralsService.normalizePhone('61 55 33 0'), '');
      expect(ReferralsService.normalizePhone('61 55 33 033'), '');
      expect(ReferralsService.normalizePhone(''), '');
      expect(ReferralsService.normalizePhone('абв'), '');
    });

    test('ПРЕФИКС 993 срезается только у одиннадцати цифр', () {
      // Восьмизначный номер может начинаться на 993 сам по себе — например
      // 993 44 55. Срезать префикс у него нельзя, иначе получится обрубок.
      expect(ReferralsService.normalizePhone('99 34 45 56'), '+99399344556');
      expect(ReferralsService.normalizePhone('99361553303'), '+99361553303');
    });

    test('результат всегда либо пустой, либо ровно 12 символов', () {
      for (final raw in [
        '61 55 33 03',
        '+99361553303',
        '99361553303',
        '(61) 55-33-03',
      ]) {
        expect(ReferralsService.normalizePhone(raw).length, 12, reason: raw);
      }
    });
  });

  group('parseOutcome', () {
    test('успех', () {
      expect(
        ReferralsService.parseOutcome({'ok': true, 'id': [1]}),
        ReferralOutcome.ok,
      );
    });

    test('каждый код отказа разбирается в свой исход', () {
      const cases = {
        'BAD_PHONE': ReferralOutcome.badPhone,
        'SELF_INVITE': ReferralOutcome.selfInvite,
        'ALREADY_REGISTERED': ReferralOutcome.alreadyRegistered,
        'ALREADY_INVITED': ReferralOutcome.alreadyInvited,
        'LIMIT_REACHED': ReferralOutcome.limitReached,
        'NOT_FOUND': ReferralOutcome.notFound,
        'DISABLED': ReferralOutcome.disabled,
        'NOT_A_COURIER': ReferralOutcome.notACourier,
      };
      cases.forEach((code, want) {
        expect(
          ReferralsService.parseOutcome({'ok': false, 'code': code}),
          want,
          reason: code,
        );
      });
    });

    test('ok:false никогда не читается как успех', () {
      expect(
        ReferralsService.parseOutcome({'ok': false}),
        ReferralOutcome.error,
      );
      expect(
        ReferralsService.parseOutcome({'ok': false, 'code': 'ЧТО_ТО'}),
        ReferralOutcome.error,
      );
    });

    test('ответ строкой и завёрнутый в ключ шага', () {
      expect(
        ReferralsService.parseOutcome('{"ok":false,"code":"LIMIT_REACHED"}'),
        ReferralOutcome.limitReached,
      );
      expect(
        ReferralsService.parseOutcome({
          'respond_err': {'ok': false, 'code': 'SELF_INVITE'},
        }),
        ReferralOutcome.selfInvite,
      );
    });

    test('пустое и мусорное тело — ошибка', () {
      expect(ReferralsService.parseOutcome({}), ReferralOutcome.error);
      expect(ReferralsService.parseOutcome(null), ReferralOutcome.error);
      expect(ReferralsService.parseOutcome('не json'), ReferralOutcome.error);
    });
  });
}
