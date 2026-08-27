/// Типизированное представление заказа.
///
/// API возвращает `Map<String, dynamic>`. `OrderDto.fromMap` инкапсулирует
/// все string-key lookups в одном месте и даёт остальному коду строгий API.
///
/// Использование:
/// ```
/// final dto = OrderDto.fromMap(order as Map);
/// Text(dto.shopAddress(isRu));
/// Text('${dto.deliveryAmount.toStringAsFixed(0)} TMT');
/// ```
class OrderDto {
  final String id;
  final String status;
  final String? transportType;
  final double totalAmount;
  final double deliveryAmount;
  final int pointsAmount;
  final double cashbackAmount;
  final String comment;
  final List<dynamic> pictures;
  final String? timeOfDelivery;
  // Параллельные RU/TK поля для адресов.
  final String shopAddressRu;
  final String shopAddressTk;
  final String deliveryAddressRu;
  final String deliveryAddressTk;
  // Контакты
  final String shopName;

  /// Имя заказчика — **только имя, без фамилии**. Показывается курьеру в
  /// карточке заказа и в деталях, чтобы было видно, кто заказал.
  /// `shopName` для этого не годится: там «Имя Фамилия».
  final String shopFirstName;
  final String shopPhone;
  final String clientPhone;
  final String courierPhone;
  final String courierName;

  /// UUID файла `selfie_scan` курьера — для рендеринга круглой аватарки.
  /// Пустая строка если курьера нет или у него не загружено фото.
  final String courierSelfieFileId;

  /// Slug категории магазина (food/cafe/...). Может быть пустым у старых заказов.
  final String category;

  /// true — магазин предлагает несколько товаров на выбор (курьер фотает,
  /// клиент выбирает). У старых заказов всегда false.
  final bool multipleItems;

  /// Заказ виден только надёжным курьерам этого магазина.
  ///
  /// Курьеру значок объясняет, почему заказ есть у него и нет у других;
  /// магазину — что заказ ушёл узкому кругу и берут его не сразу.
  final bool trustedOnly;

  /// ID курьера (customer id). Нужен для `generateDeliveryCode` из
  /// background isolate'а при нажатии «Завершить». Пустая строка у магазина.
  final String courierId;
  // Сырая мапа — на случай если где-то понадобится поле, которого нет в DTO.
  final Map<String, dynamic> raw;

  const OrderDto({
    required this.id,
    required this.status,
    required this.transportType,
    required this.totalAmount,
    required this.deliveryAmount,
    required this.pointsAmount,
    required this.cashbackAmount,
    required this.comment,
    required this.pictures,
    required this.timeOfDelivery,
    required this.shopAddressRu,
    required this.shopAddressTk,
    required this.deliveryAddressRu,
    required this.deliveryAddressTk,
    required this.shopName,
    required this.shopFirstName,
    required this.shopPhone,
    required this.clientPhone,
    required this.courierPhone,
    required this.courierName,
    required this.courierSelfieFileId,
    required this.courierId,
    required this.category,
    required this.multipleItems,
    required this.trustedOnly,
    required this.raw,
  });

  /// Развёрнутая карточка заказчика из M2A-связи `shopId`.
  ///
  /// В WS-событии связь приходит как `[{item: {id, name, surname}}]`, при
  /// обычной загрузке — как `[{item: '254'}]`. Второй случай нам здесь не
  /// нужен: там имя уже подставлено отдельным полем.
  static Map<String, dynamic>? _expandedShop(dynamic field) {
    if (field is! List || field.isEmpty) return null;
    final first = field.first;
    if (first is! Map) return null;
    final item = first['item'];
    return item is Map ? Map<String, dynamic>.from(item) : null;
  }

  /// Первое непустое значение после обрезки пробелов.
  static String _firstNonEmpty(List<String> values) {
    for (final v in values) {
      final t = v.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  factory OrderDto.fromMap(Map<String, dynamic> m) {
    String s(String k) => (m[k] ?? '').toString();
    double d(String k) {
      final v = m[k];
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int i(String k) {
      final v = m[k];
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final pics = m['pictures'];

    // Имя заказчика приходит тремя путями, и берём первый доступный:
    //   1. `shop_first_name` — подставляет OrderService при загрузке списка;
    //   2. развёрнутая связь `shopId` — так имя приезжает в WS-событии;
    //   3. первое слово из «Имя Фамилия» — на случай старых данных.
    // Три источника, потому что заказ попадает в приложение по-разному, а
    // курьеру имя нужно одинаково во всех случаях: без него новый заказ
    // выглядел безымянным до тех пор, пока список не перезагрузится.
    final expanded = _expandedShop(m['shopId']);
    final shopFullName = _firstNonEmpty([
      (m['shop_name'] ?? m['shop_title'] ?? '').toString(),
      '${expanded?['name'] ?? ''} ${expanded?['surname'] ?? ''}',
    ]);
    final shopFirst = _firstNonEmpty([
      (m['shop_first_name'] ?? '').toString(),
      (expanded?['name'] ?? '').toString(),
      shopFullName.isEmpty ? '' : shopFullName.split(RegExp(r'\s+')).first,
    ]);
    // category может прийти как string slug или Map (expanded m2o).
    final rawCat = m['category'];
    final categorySlug = rawCat == null
        ? ''
        : rawCat is Map
        ? (rawCat['id']?.toString() ?? '')
        : rawCat.toString();
    return OrderDto(
      id: s('id'),
      // На бэке встречаются оба имени поля.
      status: ((m['status'] ?? m['order_status']) ?? 'published')
          .toString()
          .toLowerCase()
          .trim(),
      transportType: m['transport_type']?.toString(),
      totalAmount: d('total_amount'),
      deliveryAmount: d('delivery_amount'),
      pointsAmount: i('points_amount'),
      cashbackAmount: d('cashback_amount'),
      comment: s('comment'),
      pictures: pics is List ? pics : const [],
      timeOfDelivery: m['time_of_delivery']?.toString(),
      shopAddressRu: s('shop_adress'),
      shopAddressTk: s('shop_adresstk'),
      deliveryAddressRu: s('adress_of_delivery'),
      deliveryAddressTk: s('adress_of_deliverytk'),
      shopName: shopFullName,
      shopFirstName: shopFirst,
      shopPhone: s('shop_phone'),
      clientPhone: s('client_phone'),
      courierPhone: s('courier_phone'),
      courierName: s('courier_name'),
      courierSelfieFileId: s('courier_selfie_file_id'),
      category: categorySlug,
      multipleItems: m['multiple_items'] == true,
      trustedOnly: m['trusted_only'] == true,
      courierId: s('courierId'),
      raw: m,
    );
  }

  /// Короткий ID для отображения в UI: первый сегмент UUID в верхнем регистре.
  String get shortId => id.isEmpty ? '' : id.split('-').first.toUpperCase();

  /// Адрес магазина с учётом языка + локализованный fallback.
  String shopAddress(bool isRu, {String? fallback}) {
    if (isRu) {
      return shopAddressRu.isNotEmpty ? shopAddressRu : (fallback ?? '');
    }
    return shopAddressTk.isNotEmpty ? shopAddressTk : (fallback ?? '');
  }

  /// Адрес доставки с учётом языка + локализованный fallback.
  String deliveryAddress(bool isRu, {String? fallback}) {
    if (isRu) {
      return deliveryAddressRu.isNotEmpty
          ? deliveryAddressRu
          : (fallback ?? '');
    }
    return deliveryAddressTk.isNotEmpty ? deliveryAddressTk : (fallback ?? '');
  }

  /// Прибыль курьера = delivery_amount; для магазина — total - delivery.
  double amountFor({required bool isShop}) =>
      isShop ? (totalAmount - deliveryAmount) : deliveryAmount;
}
