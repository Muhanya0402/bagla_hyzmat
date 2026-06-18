import 'dart:ui';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:bagla/features/profile/widgets/shop_categories.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public data models
// ─────────────────────────────────────────────────────────────────────────────

class CourierFilterItem {
  final String id;

  /// Legacy / язык-агностичный лейбл. Используется когда сущность
  /// одноязычна (имя магазина, категория) и как fallback если
  /// `labelRu`/`labelTk` не задано.
  final String label;

  /// Двуязычные лейблы для province/etrap/district. Если заданы — UI
  /// рендерит `localizedLabel(isRu)` и не зависит от того, на каком
  /// языке был построен кеш. Раньше items создавались с одной строкой
  /// `label: p.label(isRu)` → после смены языка кеш отдавал старые лейблы.
  final String? labelRu;
  final String? labelTk;

  /// Опциональная вторая строка (например, телефон под именем магазина).
  /// Используется только в `_FilterPickerSheet` и в селектед-tile.
  final String? subtitle;

  /// Опциональная строка для поиска. Если задана — поиск идёт по ней
  /// (не по label). Позволяет искать по полям, которых нет в видимой
  /// надписи (например по телефону, когда показывается только имя).
  /// Если null — поиск идёт по `label`.
  final String? searchKeywords;

  const CourierFilterItem({
    required this.id,
    required this.label,
    this.labelRu,
    this.labelTk,
    this.subtitle,
    this.searchKeywords,
  });

  /// Лейбл с учётом текущего языка. Если двуязычные поля не заданы —
  /// fallback на `label` (этот случай для shops/categories, у них один
  /// язык — имя магазина).
  String localizedLabel(bool isRu) {
    if (isRu) {
      final v = labelRu;
      if (v != null && v.isNotEmpty) return v;
    } else {
      final v = labelTk;
      if (v != null && v.isNotEmpty) return v;
    }
    return label;
  }

  /// Текст для нечёткого поиска. Содержит ОБА языка — чтобы юзер мог
  /// искать «Ашгабат» при выборе на TK-локали и наоборот.
  String get _searchText {
    if (searchKeywords != null) return searchKeywords!.toLowerCase();
    final parts = [
      label,
      ?labelRu,
      ?labelTk,
      ?subtitle,
    ];
    return parts.join(' ').toLowerCase();
  }

  bool matchesQuery(String q) {
    if (q.isEmpty) return true;
    return _searchText.contains(q);
  }

  @override
  bool operator ==(Object other) =>
      other is CourierFilterItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class CourierFilters {
  final String transportFilter;

  final CourierFilterItem? shopProvince;
  final CourierFilterItem? shopEtrap;
  final CourierFilterItem? shopDistrict;

  final CourierFilterItem? deliveryProvince;
  final CourierFilterItem? deliveryEtrap;
  final CourierFilterItem? deliveryDistrict;

  final CourierFilterItem? shop;
  final CourierFilterItem? category;

  const CourierFilters({
    this.transportFilter = 'any',
    this.shopProvince,
    this.shopEtrap,
    this.shopDistrict,
    this.deliveryProvince,
    this.deliveryEtrap,
    this.deliveryDistrict,
    this.shop,
    this.category,
  });

  int get activeCount {
    int n = 0;
    if (transportFilter != 'any') n++;
    if (shopProvince != null) n++;
    if (shopEtrap != null) n++;
    if (shopDistrict != null) n++;
    if (deliveryProvince != null) n++;
    if (deliveryEtrap != null) n++;
    if (deliveryDistrict != null) n++;
    if (shop != null) n++;
    if (category != null) n++;
    return n;
  }

  static const _s = Object();

  CourierFilters copyWith({
    String? transportFilter,
    Object? shopProvince = _s,
    Object? shopEtrap = _s,
    Object? shopDistrict = _s,
    Object? deliveryProvince = _s,
    Object? deliveryEtrap = _s,
    Object? deliveryDistrict = _s,
    Object? shop = _s,
    Object? category = _s,
  }) => CourierFilters(
    transportFilter: transportFilter ?? this.transportFilter,
    shopProvince: shopProvince == _s
        ? this.shopProvince
        : shopProvince as CourierFilterItem?,
    shopEtrap: shopEtrap == _s
        ? this.shopEtrap
        : shopEtrap as CourierFilterItem?,
    shopDistrict: shopDistrict == _s
        ? this.shopDistrict
        : shopDistrict as CourierFilterItem?,
    deliveryProvince: deliveryProvince == _s
        ? this.deliveryProvince
        : deliveryProvince as CourierFilterItem?,
    deliveryEtrap: deliveryEtrap == _s
        ? this.deliveryEtrap
        : deliveryEtrap as CourierFilterItem?,
    deliveryDistrict: deliveryDistrict == _s
        ? this.deliveryDistrict
        : deliveryDistrict as CourierFilterItem?,
    shop: shop == _s ? this.shop : shop as CourierFilterItem?,
    category: category == _s ? this.category : category as CourierFilterItem?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Classifier cache singleton
// ─────────────────────────────────────────────────────────────────────────────

class ClassifierCache {
  static final ClassifierCache _i = ClassifierCache._();
  ClassifierCache._();
  factory ClassifierCache() => _i;

  List<CourierFilterItem> provinces = [];
  final Map<String, List<CourierFilterItem>> etraps = {};
  final Map<String, List<CourierFilterItem>> districts = {};
  List<ShopCategory> shopCategories = [];

  /// Накопительный кеш магазинов (телефон → item). Растёт по мере того
  /// как пользователь видит новые заказы. Не стирается между перезагрузками
  /// списка заказов — это решает кейс, когда юзер открывает фильтр на
  /// «пустой» вкладке (refresh идёт / фильтр срезал всё) и tile «Магазин»
  /// был бы disabled, потому что текущий `orders` пуст.
  ///
  /// Имя в значении всегда «лучшее» (непустое перекрывает пустое).
  final Map<String, CourierFilterItem> shopItemsCache = {};

  /// Сливает новые items в кеш. Если у уже закешированного был label
  /// без имени (только телефон), а новый пришёл с именем — обновляем.
  void mergeShopItems(Iterable<CourierFilterItem> items) {
    for (final it in items) {
      final old = shopItemsCache[it.id];
      // Новый item с subtitle (= имя+телефон) всегда перекрывает старый
      // без subtitle (= только телефон). Иначе оставляем кеш как есть.
      if (old == null || (old.subtitle == null && it.subtitle != null)) {
        shopItemsCache[it.id] = it;
      }
    }
  }

  /// Отсортированный список для UI.
  List<CourierFilterItem> get sortedShopItems {
    final list = shopItemsCache.values.toList();
    list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  /// Пополнить кеш магазинов из сырого списка orders. Вызывается
  /// контроллером после каждой успешной загрузки orders (handleRefresh,
  /// смена вкладки, пагинация, WS-push). Так кеш растёт независимо от
  /// открытия фильтр-модалки → tile «Магазин» в фильтре никогда не
  /// будет пустым, если хоть один заказ когда-то был виден.
  ///
  /// «Лучшее» имя побеждает: если у магазина был заказ без `shop_name`,
  /// а потом пришёл с именем — обновляем item на двухстрочный
  /// (имя + телефон).
  void mergeFromOrders(List<dynamic> orders) {
    final bestName = <String, String>{};
    for (final o in orders) {
      if (o is! Map) continue;
      final phone = (o['shop_phone'] ?? '').toString().trim();
      if (phone.isEmpty) continue;
      final name = (o['shop_name'] ?? o['shop_title'] ?? '').toString().trim();
      if (name.isEmpty) {
        bestName.putIfAbsent(phone, () => '');
      } else {
        bestName[phone] = name;
      }
    }

    final fresh = bestName.entries.map(
      (e) => CourierFilterItem(
        id: e.key,
        label: e.value.isNotEmpty ? e.value : e.key,
        subtitle: e.value.isNotEmpty ? e.key : null,
        searchKeywords: '${e.value} ${e.key}',
      ),
    );
    mergeShopItems(fresh);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper — opens the modal with expand-from-button animation
// ─────────────────────────────────────────────────────────────────────────────

void showCourierFilterModal({
  required BuildContext context,
  GlobalKey? buttonKey,
  required CourierFilters initial,
  required bool isRu,
  required AppLocalizations words,
  required ClassifierCache cache,
  required AuthRepository authRepo,
  required List<CourierFilterItem> shopItems,
  bool applyDefaults = true,
  CourierFilterItem? defaultProvince,
  CourierFilterItem? defaultEtrap,
  required void Function(CourierFilters) onApply,
  required VoidCallback onClear,
}) {
  final renderBox = buttonKey?.currentContext?.findRenderObject() as RenderBox?;
  final buttonCenter = renderBox?.localToGlobal(
    Offset(renderBox.size.width / 2, renderBox.size.height / 2),
  );

  showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: '',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, _) => _FilterOverlay(
      buttonCenter: buttonCenter,
      initial: initial,
      isRu: isRu,
      words: words,
      cache: cache,
      authRepo: authRepo,
      shopItems: shopItems,
      applyDefaults: applyDefaults,
      defaultProvince: defaultProvince,
      defaultEtrap: defaultEtrap,
      onApply: onApply,
      onClear: onClear,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterOverlay — handles expand-from-button + blur backdrop animation
// ─────────────────────────────────────────────────────────────────────────────

class _FilterOverlay extends StatefulWidget {
  final Offset? buttonCenter;
  final CourierFilters initial;
  final bool isRu;
  final AppLocalizations words;
  final ClassifierCache cache;
  final AuthRepository authRepo;
  final List<CourierFilterItem> shopItems;
  final bool applyDefaults;
  final CourierFilterItem? defaultProvince;
  final CourierFilterItem? defaultEtrap;
  final void Function(CourierFilters) onApply;
  final VoidCallback onClear;

  const _FilterOverlay({
    required this.buttonCenter,
    required this.initial,
    required this.isRu,
    required this.words,
    required this.cache,
    required this.authRepo,
    required this.shopItems,
    required this.applyDefaults,
    required this.defaultProvince,
    required this.defaultEtrap,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterOverlay> createState() => _FilterOverlayState();
}

class _FilterOverlayState extends State<_FilterOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _backdropFade;
  late final Animation<double> _scale;
  late final Animation<double> _modalFade;

  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 250),
    );

    // Backdrop fades in faster than modal appears
    _backdropFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      reverseCurve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    // Modal scale: starts very small (button-like) → full size
    _scale = Tween<double>(
      begin: 0.08,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Modal fades in during the first half of the animation
    _modalFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _ctrl.reverse();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  // Scale origin: maps the button's horizontal position to the modal's
  // alignment space (-1 = left, 1 = right), with Y fixed above the modal top
  // so the tiny modal appears near the button at open/close endpoints.
  Alignment _scaleAlignment(Size screen) {
    final alignX = widget.buttonCenter != null
        ? ((widget.buttonCenter!.dx / screen.width) * 2 - 1).clamp(-1.0, 1.0)
        : 0.8;
    return Alignment(alignX, -1.5);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Stack(
        children: [
          // ── Blur backdrop (only FadeTransition — no scale/slide to avoid freeze)
          FadeTransition(
            opacity: _backdropFade,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: BackdropFilter(
                // sigma 2 для GPU-friendly blur'а на старых девайсах.
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(color: Colors.black.withValues(alpha: 0.38)),
              ),
            ),
          ),

          // ── Modal: scale + fade, scale origin near button position
          Align(
            alignment: Alignment.bottomCenter,
            child: FadeTransition(
              opacity: _modalFade,
              child: ScaleTransition(
                scale: _scale,
                alignment: _scaleAlignment(screen),
                child: CourierFilterModal(
                  initial: widget.initial,
                  isRu: widget.isRu,
                  words: widget.words,
                  cache: widget.cache,
                  authRepo: widget.authRepo,
                  shopItems: widget.shopItems,
                  applyDefaults: widget.applyDefaults,
                  defaultProvince: widget.defaultProvince,
                  defaultEtrap: widget.defaultEtrap,
                  onApply: (filters) {
                    widget.onApply(filters);
                    _close();
                  },
                  onClear: widget.onClear,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CourierFilterModal
// ─────────────────────────────────────────────────────────────────────────────

class CourierFilterModal extends StatefulWidget {
  final CourierFilters initial;
  final bool isRu;
  final AppLocalizations words;
  final ClassifierCache cache;
  final AuthRepository authRepo;
  final CourierFilterItem? defaultProvince;
  final CourierFilterItem? defaultEtrap;
  final List<CourierFilterItem> shopItems;
  final bool applyDefaults;
  final void Function(CourierFilters) onApply;
  final VoidCallback onClear;

  const CourierFilterModal({
    super.key,
    required this.initial,
    required this.isRu,
    required this.words,
    required this.cache,
    required this.authRepo,
    required this.shopItems,
    this.applyDefaults = true,
    this.defaultProvince,
    this.defaultEtrap,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<CourierFilterModal> createState() => _CourierFilterModalState();
}

class _CourierFilterModalState extends State<CourierFilterModal>
    with AppTourMixin<CourierFilterModal> {
  late CourierFilters _draft;
  bool _loadingAny = false;
  bool _defaultsApplied = false;
  final _transportKey = GlobalKey();
  final _applyKey = GlobalKey();

  List<(String, IconData, String)> _transportOptions() => [
    ('any', Icons.directions_run_rounded, widget.words.filterTransportAny),
    ('car', Icons.directions_car_rounded, widget.words.filterTransportCar),
    ('truck', Icons.local_shipping_rounded, widget.words.filterTransportTruck),
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _applyDefaults();
    startTourIfNeeded(
      screenKey: TourKeys.courierFilter,
      targetsBuilder: _buildTourTargets,
    );
  }

  List<TargetFocus> _buildTourTargets() => [
    TourTarget.build(
      id: 'courier_filter_0',
      key: _transportKey,
      titleRu: 'Вид транспорта',
      titleTk: 'Ulag görnüşi',
      bodyRu:
          'Фильтруйте курьеров по типу транспорта: пешком, авто или грузовик.',
      bodyTk:
          'Kurýerleri ulag görnüşi boýunça süzüň: pyýada, awtoulag ýa-da ýük ulagy.',
      isRu: widget.isRu,
      align: ContentAlign.bottom,
    ),
    TourTarget.build(
      id: 'courier_filter_1',
      key: _applyKey,
      titleRu: 'Применить фильтры',
      titleTk: 'Süzgüçleri ulan',
      bodyRu:
          'Нажмите чтобы применить выбранные фильтры и найти подходящих курьеров.',
      bodyTk:
          'Saýlanan süzgüçleri ulanmak we laýyk kurýerleri tapmak üçin basyň.',
      isRu: widget.isRu,
      align: ContentAlign.top,
    ),
  ];

  void _applyDefaults() {
    if (_defaultsApplied) return;
    _defaultsApplied = true;
    if (!widget.applyDefaults) return;

    var d = _draft;
    if (d.shopProvince == null && widget.defaultProvince != null) {
      d = d.copyWith(shopProvince: widget.defaultProvince);
    }
    if (d.shopEtrap == null &&
        d.shopProvince != null &&
        widget.defaultEtrap != null) {
      d = d.copyWith(shopEtrap: widget.defaultEtrap);
    }
    if (d.deliveryProvince == null && widget.defaultProvince != null) {
      d = d.copyWith(deliveryProvince: widget.defaultProvince);
    }
    if (d.deliveryEtrap == null &&
        d.deliveryProvince != null &&
        widget.defaultEtrap != null) {
      d = d.copyWith(deliveryEtrap: widget.defaultEtrap);
    }
    _draft = d;
  }

  // ── Loaders ────────────────────────────────────────────────────────────────

  Future<List<CourierFilterItem>> _loadProvinces() async {
    if (widget.cache.provinces.isNotEmpty) return _sortedByLang(widget.cache.provinces);
    setState(() => _loadingAny = true);
    try {
      final resp = await widget.authRepo.getProvinces();
      final items = resp
          .map<CourierFilterItem>(
            (p) => CourierFilterItem(
              id: p.id,
              // `label` — текущий язык для legacy-кода, который читает
              // `item.label` напрямую. UI-рендер использует
              // `localizedLabel(isRu)` и при смене языка возьмёт
              // правильную версию из `labelRu`/`labelTk`.
              label: p.label(widget.isRu),
              labelRu: p.ru,
              labelTk: p.tk,
            ),
          )
          .toList();
      widget.cache.provinces = items;
      return _sortedByLang(items);
    } catch (_) {
      return [];
    } finally {
      if (mounted) setState(() => _loadingAny = false);
    }
  }

  Future<List<CourierFilterItem>> _loadEtraps(String provinceId) async {
    if (widget.cache.etraps.containsKey(provinceId)) {
      return _sortedByLang(widget.cache.etraps[provinceId]!);
    }
    setState(() => _loadingAny = true);
    try {
      final list = await widget.authRepo.getEtrapsByProvince(provinceId);
      final items = list
          .map<CourierFilterItem>(
            (e) => CourierFilterItem(
              id: e.id,
              label: e.label(widget.isRu),
              labelRu: e.ru,
              labelTk: e.tk,
            ),
          )
          .toList();
      widget.cache.etraps[provinceId] = items;
      return _sortedByLang(items);
    } catch (_) {
      return [];
    } finally {
      if (mounted) setState(() => _loadingAny = false);
    }
  }

  /// Сортируем по текущему языку при ВЫДАЧЕ, не при кешировании. Иначе
  /// при смене языка порядок остался бы по первому языку.
  List<CourierFilterItem> _sortedByLang(List<CourierFilterItem> items) {
    final copy = List<CourierFilterItem>.from(items);
    copy.sort(
      (a, b) => a
          .localizedLabel(widget.isRu)
          .toLowerCase()
          .compareTo(b.localizedLabel(widget.isRu).toLowerCase()),
    );
    return copy;
  }

  Future<List<ShopCategory>> _loadShopCategories() async {
    if (widget.cache.shopCategories.isNotEmpty) {
      return widget.cache.shopCategories;
    }
    try {
      final list = await widget.authRepo.getShopCategories();
      final items = list.isNotEmpty ? list : kLocalShopCategories;
      widget.cache.shopCategories = items;
      return items;
    } catch (_) {
      widget.cache.shopCategories = kLocalShopCategories;
      return kLocalShopCategories;
    }
  }

  Future<List<CourierFilterItem>> _loadDistricts(String etrapId) async {
    if (widget.cache.districts.containsKey(etrapId)) {
      return _sortedByLang(widget.cache.districts[etrapId]!);
    }
    setState(() => _loadingAny = true);
    try {
      final list = await widget.authRepo.getDistrictsByEtrap(etrapId);
      final items = list
          .map<CourierFilterItem>(
            (d) => CourierFilterItem(
              id: d.id,
              label: d.label(widget.isRu),
              labelRu: d.ru,
              labelTk: d.tk,
            ),
          )
          .toList();
      widget.cache.districts[etrapId] = items;
      return _sortedByLang(items);
    } catch (_) {
      return [];
    } finally {
      if (mounted) setState(() => _loadingAny = false);
    }
  }

  // ── Picker ─────────────────────────────────────────────────────────────────

  Future<CourierFilterItem?> _openPicker({
    required String title,
    required Future<List<CourierFilterItem>> itemsFuture,
    required String? selectedId,
  }) async {
    final items = await itemsFuture;
    if (!mounted) return null;

    return showModalBottomSheet<CourierFilterItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (pickerCtx) => _FilterPickerSheet(
        title: title,
        items: items,
        selectedId: selectedId,
        words: widget.words,
        isRu: widget.isRu,
        onSelect: (id) {
          final item = items.firstWhere((i) => i.id == id);
          Navigator.pop(pickerCtx, item);
        },
        onClear: selectedId != null
            ? () => Navigator.pop(
                pickerCtx,
                const CourierFilterItem(id: '__clear__', label: ''),
              )
            : null,
      ),
    );
  }

  bool _isCleared(CourierFilterItem? item) =>
      item != null && item.id == '__clear__';

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 2.5,
            height: 12,
            decoration: BoxDecoration(
              color: c.ink.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppText.semiBold(
              fontSize: 11,
              color: c.inkMuted,
            ).copyWith(letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String hint,
    required CourierFilterItem? selected,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool disabled = false,
  }) {
    final c = AppColors.of(context);
    final bool has = selected != null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: disabled
              ? c.borderSoft.withValues(alpha: 0.5)
              : has
              ? c.emeraldTint
              : c.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: has && !disabled
                ? c.ink.withValues(alpha: 0.35)
                : c.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: disabled
                  ? c.border
                  : has
                  ? c.ink
                  : c.inkSoft,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // `localizedLabel` подберёт RU/TK в зависимости от
                    // текущей локали. Если поля двуязычные не заданы
                    // (shops/categories — там один язык) — fallback на `label`.
                    has ? selected.localizedLabel(widget.isRu) : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: disabled
                        ? AppText.regular(fontSize: 13, color: c.border)
                        : has
                        ? AppText.semiBold(fontSize: 13, color: c.ink)
                        : AppText.regular(fontSize: 13, color: c.inkSoft),
                  ),
                  // Двухстрочное отображение для магазинов: имя + телефон
                  // под ним. Для province/etrap/district `subtitle` null —
                  // эта строка не рендерится.
                  if (has &&
                      selected.subtitle != null &&
                      selected.subtitle!.isNotEmpty &&
                      !disabled) ...[
                    const SizedBox(height: 1),
                    Text(
                      selected.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.regular(fontSize: 10.5, color: c.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            if (has && !disabled && onClear != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.close_rounded, size: 14, color: c.inkSoft),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: disabled ? c.border : c.inkSoft,
              ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final w = widget.words;
    final transportOptions = _transportOptions();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          bottomInset > 0 ? bottomInset + 16 : bottomPadding + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ───────────────────────────────────────────────────
              const SheetHandle(topPadding: 0),
              const SizedBox(height: 14),

              // ── Header ───────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    w.filterTitle,
                    style: AppText.serif(fontSize: 17, color: c.ink),
                  ),
                  const Spacer(),
                  if (_loadingAny)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: c.ink,
                      ),
                    )
                  else if (_draft.activeCount > 0)
                    _ResetButton(
                      label: w.filterReset,
                      onTap: () =>
                          setState(() => _draft = const CourierFilters()),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Transport ────────────────────────────────────────────────
              _sectionLabel(w.transportSection),
              KeyedSubtree(
                key: _transportKey,
                child: Row(
                  children: transportOptions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final opt = entry.value;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i < transportOptions.length - 1 ? 6 : 0,
                        ),
                        child: _TransportTag(
                          selected: _draft.transportFilter == opt.$1,
                          icon: opt.$2,
                          label: opt.$3,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(
                              transportFilter: opt.$1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Category ─────────────────────────────────────────────────
              _sectionLabel(w.filterCategorySection),
              _pickerTile(
                icon: _draft.category != null
                    ? iconForSlug(_draft.category!.id)
                    : Icons.category_outlined,
                hint: w.filterPickCategory,
                selected: _draft.category,
                onTap: () async {
                  final cats = await _loadShopCategories();
                  if (!mounted) return;
                  final items = cats
                      .map(
                        (c) => CourierFilterItem(
                          id: c.id.toString(),
                          label: c.label(widget.isRu),
                          // Кеш категорий — singleton; без двуязычных
                          // лейблов после смены RU↔TK pickerщее
                          // показывал бы вчерашнюю локаль.
                          labelRu: c.labelRu,
                          labelTk: c.labelTk,
                        ),
                      )
                      .toList();
                  final res = await _openPicker(
                    title: w.filterCategorySection,
                    itemsFuture: Future.value(items),
                    selectedId: _draft.category?.id,
                  );
                  if (res == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      category: _isCleared(res) ? null : res,
                    ),
                  );
                },
                onClear: _draft.category != null
                    ? () => setState(
                        () => _draft = _draft.copyWith(category: null),
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Shop address ─────────────────────────────────────────────
              _sectionLabel(w.filterShopAddress),
              _pickerTile(
                icon: Icons.map_outlined,
                hint: w.filterPickProvince,
                selected: _draft.shopProvince,
                onTap: () async {
                  final res = await _openPicker(
                    title: w.filterProvinceShop,
                    itemsFuture: _loadProvinces(),
                    selectedId: _draft.shopProvince?.id,
                  );
                  if (res == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      shopProvince: _isCleared(res) ? null : res,
                      shopEtrap: null,
                      shopDistrict: null,
                    ),
                  );
                },
                onClear: _draft.shopProvince != null
                    ? () => setState(
                        () => _draft = _draft.copyWith(
                          shopProvince: null,
                          shopEtrap: null,
                          shopDistrict: null,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              _pickerTile(
                icon: Icons.location_city_outlined,
                hint: w.filterPickEtrap,
                selected: _draft.shopEtrap,
                disabled: _draft.shopProvince == null,
                onTap: () async {
                  final res = await _openPicker(
                    title: w.filterEtrapShop,
                    itemsFuture: _loadEtraps(_draft.shopProvince!.id),
                    selectedId: _draft.shopEtrap?.id,
                  );
                  if (res == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      shopEtrap: _isCleared(res) ? null : res,
                      shopDistrict: null,
                    ),
                  );
                },
                onClear: _draft.shopEtrap != null
                    ? () => setState(
                        () => _draft = _draft.copyWith(
                          shopEtrap: null,
                          shopDistrict: null,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              _pickerTile(
                icon: Icons.pin_drop_outlined,
                hint: w.filterPickDistrict,
                selected: _draft.shopDistrict,
                disabled: _draft.shopEtrap == null,
                onTap: () async {
                  final res = await _openPicker(
                    title: w.filterDistrictShop,
                    itemsFuture: _loadDistricts(_draft.shopEtrap!.id),
                    selectedId: _draft.shopDistrict?.id,
                  );
                  if (res == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      shopDistrict: _isCleared(res) ? null : res,
                    ),
                  );
                },
                onClear: _draft.shopDistrict != null
                    ? () => setState(
                        () => _draft = _draft.copyWith(shopDistrict: null),
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Delivery address ─────────────────────────────────────────
              _sectionLabel(w.filterDeliveryAddress),
              _pickerTile(
                icon: Icons.map_outlined,
                hint: w.filterPickProvince,
                selected: _draft.deliveryProvince,
                onTap: () async {
                  final res = await _openPicker(
                    title: w.filterProvinceDelivery,
                    itemsFuture: _loadProvinces(),
                    selectedId: _draft.deliveryProvince?.id,
                  );
                  if (res == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      deliveryProvince: _isCleared(res) ? null : res,
                      deliveryEtrap: null,
                      deliveryDistrict: null,
                    ),
                  );
                },
                onClear: _draft.deliveryProvince != null
                    ? () => setState(
                        () => _draft = _draft.copyWith(
                          deliveryProvince: null,
                          deliveryEtrap: null,
                          deliveryDistrict: null,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              _pickerTile(
                icon: Icons.location_city_outlined,
                hint: w.filterPickEtrap,
                selected: _draft.deliveryEtrap,
                disabled: _draft.deliveryProvince == null,
                onTap: () async {
                  final res = await _openPicker(
                    title: w.filterEtrapDelivery,
                    itemsFuture: _loadEtraps(_draft.deliveryProvince!.id),
                    selectedId: _draft.deliveryEtrap?.id,
                  );
                  if (res == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      deliveryEtrap: _isCleared(res) ? null : res,
                      deliveryDistrict: null,
                    ),
                  );
                },
                onClear: _draft.deliveryEtrap != null
                    ? () => setState(
                        () => _draft = _draft.copyWith(
                          deliveryEtrap: null,
                          deliveryDistrict: null,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              _pickerTile(
                icon: Icons.pin_drop_outlined,
                hint: w.filterPickDistrict,
                selected: _draft.deliveryDistrict,
                disabled: _draft.deliveryEtrap == null,
                onTap: () async {
                  final res = await _openPicker(
                    title: w.filterDistrictDelivery,
                    itemsFuture: _loadDistricts(_draft.deliveryEtrap!.id),
                    selectedId: _draft.deliveryDistrict?.id,
                  );
                  if (res == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      deliveryDistrict: _isCleared(res) ? null : res,
                    ),
                  );
                },
                onClear: _draft.deliveryDistrict != null
                    ? () => setState(
                        () => _draft = _draft.copyWith(deliveryDistrict: null),
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Shop ─────────────────────────────────────────────────────
              _sectionLabel(w.filterShopLabel),
              // ⚠️ Читаем магазины НАПРЯМУЮ из кеша, не из `widget.shopItems`.
              // `shopItems` — снимок на момент открытия модалки. Если юзер
              // открыл фильтр когда orders пуст (refresh / срезанная вкладка),
              // снимок пустой → tile был бы disabled, выбрать заказчика нельзя.
              // Кеш же пополняется после каждой загрузки orders (см.
              // home_screen_controller) — там магазины из всех прошлых
              // выгрузок, даже если текущий список пуст.
              Builder(
                builder: (ctx) {
                  final shopList = widget.cache.sortedShopItems;
                  return _pickerTile(
                    icon: Icons.store_outlined,
                    hint: w.filterPickShop,
                    selected: _draft.shop,
                    disabled: shopList.isEmpty,
                    onTap: () async {
                      final res = await _openPicker(
                        title: w.filterShopLabel,
                        itemsFuture: Future.value(shopList),
                        selectedId: _draft.shop?.id,
                      );
                      if (res == null) return;
                      setState(
                        () => _draft = _draft.copyWith(
                          shop: _isCleared(res) ? null : res,
                        ),
                      );
                    },
                    onClear: _draft.shop != null
                        ? () => setState(
                            () => _draft = _draft.copyWith(shop: null),
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(height: 18),

              // ── Apply ─────────────────────────────────────────────────────
              KeyedSubtree(
                key: _applyKey,
                child: _ApplyButton(
                  label: w.filterApply,
                  onTap: () => widget.onApply(_draft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TransportTag
// ─────────────────────────────────────────────────────────────────────────────

class _TransportTag extends StatefulWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TransportTag({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_TransportTag> createState() => _TransportTagState();
}

class _TransportTagState extends State<_TransportTag> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected ? c.emeraldTint : c.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? c.ink.withValues(alpha: 0.35)
                  : c.borderSoft,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.selected ? c.ink : c.inkSoft,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: widget.selected
                    ? AppText.semiBold(fontSize: 11, color: c.ink)
                    : AppText.regular(fontSize: 11, color: c.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ResetButton
// ─────────────────────────────────────────────────────────────────────────────

class _ResetButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ResetButton({required this.label, required this.onTap});

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Builder(
          builder: (context) {
            final c = AppColors.of(context);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.errorTint,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                widget.label,
                style: AppText.medium(fontSize: 12, color: c.errorMuted),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ApplyButton
// ─────────────────────────────────────────────────────────────────────────────

class _ApplyButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ApplyButton({required this.label, required this.onTap});

  @override
  State<_ApplyButton> createState() => _ApplyButtonState();
}

class _ApplyButtonState extends State<_ApplyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 50,
          decoration: BoxDecoration(
            color: _pressed ? c.ink.withValues(alpha: 0.85) : c.ink,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _pressed
                ? null
                : [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppText.semiBold(fontSize: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterPickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPickerSheet extends StatefulWidget {
  final String title;
  final List<CourierFilterItem> items;
  final String? selectedId;
  final void Function(String id) onSelect;
  final VoidCallback? onClear;
  final AppLocalizations words;
  final bool isRu;

  const _FilterPickerSheet({
    required this.title,
    required this.items,
    required this.onSelect,
    required this.words,
    required this.isRu,
    this.selectedId,
    this.onClear,
  });

  @override
  State<_FilterPickerSheet> createState() => _FilterPickerSheetState();
}

class _FilterPickerSheetState extends State<_FilterPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final w = widget.words;
    // Поиск через `matchesQuery` — учитывает `searchKeywords` (имя+телефон
    // для магазинов), а не только `label`. Раньше поиск шёл строго по
    // `label`, и если в нём был только телефон — найти магазин по имени
    // было невозможно.
    final filtered = widget.items.where((i) => i.matchesQuery(_q)).toList();

    return Material(
      color: Colors.transparent,
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SheetHandle(),
              const SizedBox(height: 14),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: AppText.serif(fontSize: 16, color: c.ink),
                    ),
                    const Spacer(),
                    if (widget.onClear != null)
                      GestureDetector(
                        onTap: widget.onClear,
                        child: Text(
                          w.filterReset,
                          style: AppText.medium(
                            fontSize: 12,
                            color: c.errorMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _q = v.toLowerCase()),
                  style: AppText.regular(fontSize: 14, color: c.ink),
                  decoration: InputDecoration(
                    hintText: w.filterSearchHint,
                    hintStyle: AppText.regular(fontSize: 13, color: c.inkSoft),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: c.inkSoft,
                      size: 18,
                    ),
                    suffixIcon: _q.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _q = '');
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: c.inkSoft,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: c.bg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.borderSoft),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.borderSoft),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: c.ink.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(height: 0.5, color: c.borderSoft),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          w.filterNotFound,
                          style: AppText.regular(
                            fontSize: 14,
                            color: c.inkSoft,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: sc,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => Container(
                          height: 0.5,
                          margin: const EdgeInsets.only(left: 48),
                          color: c.borderSoft,
                        ),
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          final isActive = item.id == widget.selectedId;
                          return InkWell(
                            onTap: () => widget.onSelect(item.id),
                            splashColor: c.ink.withValues(alpha: 0.05),
                            highlightColor: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isActive ? c.emeraldTint : c.bg,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Icon(
                                      isActive
                                          ? Icons.check_rounded
                                          // Если item имеет subtitle, считаем
                                          // что это магазин (имя+телефон),
                                          // показываем store. Иначе location.
                                          : (item.subtitle != null
                                                ? Icons.store_outlined
                                                : Icons.location_on_outlined),
                                      size: 14,
                                      color: isActive ? c.ink : c.inkSoft,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          // Локализованный лейбл — берёт
                                          // RU/TK из item'а в зависимости
                                          // от текущего языка. Fallback
                                          // на `label` для одноязычных
                                          // (shops, categories).
                                          item.localizedLabel(widget.isRu),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: isActive
                                              ? AppText.semiBold(
                                                  fontSize: 14,
                                                  color: c.ink,
                                                )
                                              : AppText.regular(
                                                  fontSize: 14,
                                                  color: c.ink,
                                                ),
                                        ),
                                        if (item.subtitle != null &&
                                            item.subtitle!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppText.regular(
                                              fontSize: 11,
                                              color: c.inkSoft,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isActive)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: c.ink,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
