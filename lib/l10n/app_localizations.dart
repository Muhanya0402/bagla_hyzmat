class AppLanguage {
  final String loginTitle;
  final String phoneLabel;
  final String otpLabel;
  final String getCodeBtn;
  final String confirmBtn;
  final String changePhoneBtn;
  final String welcome;
  final String codeSent;
  final String errorPhonePrefix;
  final String errorPhoneLength;
  final String errorCodeSend;
  final String errorInvalidCode;
  final String errorConnection;
  final String profileTitle;
  final String selectRole;
  final String roleSubtitle;
  final String saveBtn;
  final String roleClient;
  final String roleCourier;
  final String roleClientDesc;
  final String roleCourierDesc;
  final String emptyList;
  final String myOrders;

  AppLanguage({
    required this.loginTitle, required this.phoneLabel, required this.otpLabel,
    required this.getCodeBtn, required this.confirmBtn, required this.changePhoneBtn,
    required this.welcome, required this.codeSent, required this.errorPhonePrefix,
    required this.errorPhoneLength, required this.errorCodeSend,
    required this.errorInvalidCode, required this.errorConnection,
    required this.profileTitle, required this.selectRole,
    required this.roleSubtitle, required this.saveBtn,
    required this.roleClient, required this.roleCourier,
    required this.roleClientDesc, required this.roleCourierDesc, required this.emptyList,
    required this.myOrders,
  });

  static AppLanguage ru = AppLanguage(
    loginTitle: "Bagla",
    phoneLabel: "Телефон",
    otpLabel: "Код из SMS",
    getCodeBtn: "Получить код",
    confirmBtn: "Подтвердить вход",
    changePhoneBtn: "Изменить номер",
    welcome: "Привет",
    codeSent: "Код отправлен",
    errorPhonePrefix: "Номер должен начинаться с +993",
    errorPhoneLength: "Введите полный номер (8 цифр)",
    errorCodeSend: "Ошибка отправки кода",
    errorInvalidCode: "Неверный код",
    errorConnection: "Ошибка соединения",
    profileTitle: "Личный кабинет",
    selectRole: "Выберите роль",
    roleSubtitle: "Кем вы хотите быть в системе?",
    saveBtn: "Сохранить изменения",
    roleClient: "Я Заказчик",
    roleCourier: "Я Доставщик",
    roleClientDesc: "Хочу заказывать товары",
    roleCourierDesc: "Хочу зарабатывать на доставке",
    emptyList: "Пустой лист",
    myOrders: "Мои заказы",
  );

  static AppLanguage tk = AppLanguage(
    loginTitle: "Bagla",
    phoneLabel: "Telefon",
    otpLabel: "SMS kody",
    getCodeBtn: "Kod almak",
    confirmBtn: "Girişi tassyklamak",
    changePhoneBtn: "Belgini üýtgetmek",
    welcome: "Salam",
    codeSent: "Kod iberildi",
    errorPhonePrefix: "Belgi +993 bilen başlamaly",
    errorPhoneLength: "Doly belgini giriziň (8 sany san)",
    errorCodeSend: "Kod ibermekde ýalňyşlyk",
    errorInvalidCode: "Nädogry kod",
    errorConnection: "Aragatnaşyk ýalňyşlygy",
    profileTitle: "Şahsy otag",
    selectRole: "Hasabyň görnüşi",
    roleSubtitle: "Ulgamda kim bolmak isleýärsiňiz?",
    saveBtn: "Üýtgetmeleri sakla",
    roleClient: "Men Sargytçy",
    roleCourier: "Men Eltip beriji",
    roleClientDesc: "Haryt sargyt etmek isleýärin",
    roleCourierDesc: "Eltip bermek bilen gazanmak isleýärin",
    emptyList: "Arassa list",
    myOrders: "Meniň zakazlarym",
  );
}