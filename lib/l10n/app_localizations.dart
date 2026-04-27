import 'strings_ru.dart';
import 'strings_tk.dart';

enum AppLocale { ru, tk }

class AppLocalizations {
  final AppLocale locale;
  final Map<String, String> _strings;

  AppLocalizations(this.locale)
    : _strings = locale == AppLocale.ru ? stringsRu : stringsTk;

  // Основной метод получения строки
  String get(String key) {
    assert(_strings.containsKey(key), 'Строка "$key" не найдена в локализации');
    return _strings[key] ?? key;
  }

  // Геттеры для автодополнения в IDE
  String get loginTitle => get('loginTitle');
  String get phoneLabel => get('phoneLabel');
  String get otpLabel => get('otpLabel');
  String get getCodeBtn => get('getCodeBtn');
  String get confirmBtn => get('confirmBtn');
  String get changePhoneBtn => get('changePhoneBtn');
  String get welcome => get('welcome');
  String get codeSent => get('codeSent');
  String get errorPhonePrefix => get('errorPhonePrefix');
  String get errorPhoneLength => get('errorPhoneLength');
  String get errorCodeSend => get('errorCodeSend');
  String get errorInvalidCode => get('errorInvalidCode');
  String get errorConnection => get('errorConnection');
  String get profileTitle => get('profileTitle');
  String get selectRole => get('selectRole');
  String get roleSubtitle => get('roleSubtitle');
  String get saveBtn => get('saveBtn');
  String get roleClient => get('roleClient');
  String get roleCourier => get('roleCourier');
  String get roleClientDesc => get('roleClientDesc');
  String get roleCourierDesc => get('roleCourierDesc');
  String get emptyList => get('emptyList');
  String get myOrders => get('myOrders');
  String get cancelOrder => get('cancelOrder');
  String get cancelReason => get('cancelReason');
  String get back => get('back');
  String get yes => get('yes');
  String get confirm => get('confirm');
  String get error => get('error');
  String get takeOrder => get('takeOrder');
  String get finishOrder => get('finishOrder');
  String get orderFrom => get('orderFrom');
  String get orderTo => get('orderTo');
  String get addressHidden => get('addressHidden');
  String get orderCost => get('orderCost');
  String get deliveryFee => get('deliveryFee');
  String get toReceive => get('toReceive');
  String get orderId => get('orderId');
  String get statusFree => get('statusFree');
  String get statusActive => get('statusActive');
  String get statusDone => get('statusDone');
  String get statusCanceled => get('statusCanceled');
}
