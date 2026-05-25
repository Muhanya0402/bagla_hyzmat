import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Публичная модель фильтров курьера
// ─────────────────────────────────────────────────────────────────────────────

class CourierFilterItem {
  final String id;
  final String label;
  const CourierFilterItem({required this.id, required this.label});

  @override
  bool operator ==(Object other) =>
      other is CourierFilterItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class CourierFilters {
  final String transportFilter; // 'any' | 'car' | 'truck'

  final CourierFilterItem? shopProvince;
  final CourierFilterItem? shopEtrap;
  final CourierFilterItem? shopDistrict;

  final CourierFilterItem? deliveryProvince;
  final CourierFilterItem? deliveryEtrap;
  final CourierFilterItem? deliveryDistrict;

  final CourierFilterItem? shop;

  const CourierFilters({
    this.transportFilter = 'any',
    this.shopProvince,
    this.shopEtrap,
    this.shopDistrict,
    this.deliveryProvince,
    this.deliveryEtrap,
    this.deliveryDistrict,
    this.shop,
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
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Синглтон-кэш классификатора
// ─────────────────────────────────────────────────────────────────────────────

class ClassifierCache {
  static final ClassifierCache _i = ClassifierCache._();
  ClassifierCache._();
  factory ClassifierCache() => _i;

  List<CourierFilterItem> provinces = [];
  final Map<String, List<CourierFilterItem>> etraps = {};
  final Map<String, List<CourierFilterItem>> districts = {};
}

// ─────────────────────────────────────────────────────────────────────────────
// CourierFilterModal
// ─────────────────────────────────────────────────────────────────────────────

class CourierFilterModal extends StatefulWidget {
  final CourierFilters initial;
  final bool isRu;
  final AppLocalizations words; // ← добавлено
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
    required this.words, // ← добавлено
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

class _CourierFilterModalState extends State<CourierFilterModal> {
  late CourierFilters _draft;
  bool _loadingAny = false;
  bool _defaultsApplied = false;

  // transport options теперь строятся из words в build
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
  }

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

  // ── Загрузчики ──────────────────────────────────────────────────────────

  Future<List<CourierFilterItem>> _loadProvinces() async {
    if (widget.cache.provinces.isNotEmpty) return widget.cache.provinces;
    setState(() => _loadingAny = true);
    try {
      final resp = await widget.authRepo.getProvinces();
      final items =
          resp
              .map<CourierFilterItem>(
                (p) => CourierFilterItem(id: p.id, label: p.label(widget.isRu)),
              )
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label));
      widget.cache.provinces = items;
      return items;
    } catch (_) {
      return [];
    } finally {
      if (mounted) setState(() => _loadingAny = false);
    }
  }

  Future<List<CourierFilterItem>> _loadEtraps(String provinceId) async {
    if (widget.cache.etraps.containsKey(provinceId)) {
      return widget.cache.etraps[provinceId]!;
    }
    setState(() => _loadingAny = true);
    try {
      final list = await widget.authRepo.getEtrapsByProvince(provinceId);
      final items =
          list
              .map<CourierFilterItem>(
                (e) => CourierFilterItem(id: e.id, label: e.label(widget.isRu)),
              )
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label));
      widget.cache.etraps[provinceId] = items;
      return items;
    } catch (_) {
      return [];
    } finally {
      if (mounted) setState(() => _loadingAny = false);
    }
  }

  Future<List<CourierFilterItem>> _loadDistricts(String etrapId) async {
    if (widget.cache.districts.containsKey(etrapId)) {
      return widget.cache.districts[etrapId]!;
    }
    setState(() => _loadingAny = true);
    try {
      final list = await widget.authRepo.getDistrictsByEtrap(etrapId);
      final items =
          list
              .map<CourierFilterItem>(
                (d) => CourierFilterItem(id: d.id, label: d.label(widget.isRu)),
              )
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label));
      widget.cache.districts[etrapId] = items;
      return items;
    } catch (_) {
      return [];
    } finally {
      if (mounted) setState(() => _loadingAny = false);
    }
  }

  // ── Пикер ────────────────────────────────────────────────────────────────

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (pickerCtx) => _FilterPickerSheet(
        title: title,
        items: items,
        selectedId: selectedId,
        words: widget.words, // ← передаём words
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

  // ── UI helpers ───────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Text(
      text,
      style: AppText.semiBold(fontSize: 13, color: const Color(0xFF0F1117)),
    ),
  );

  Widget _pickerTile({
    required IconData icon,
    required String hint,
    required CourierFilterItem? selected,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool disabled = false,
  }) {
    final bool has = selected != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: disabled
                ? const Color(0xFFF0F1F3)
                : has
                ? const Color(0xFF1A7A3C).withValues(alpha: 0.06)
                : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: has && !disabled
                  ? const Color(0xFF1A7A3C).withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: disabled
                    ? const Color(0xFFD0D4DA)
                    : has
                    ? const Color(0xFF1A7A3C)
                    : const Color(0xFF9AA3AF),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  has ? selected.label : hint,
                  style: disabled
                      ? AppText.regular(
                          fontSize: 14,
                          color: const Color(0xFFD0D4DA),
                        )
                      : has
                      ? AppText.semiBold(
                          fontSize: 14,
                          color: const Color(0xFF0F1117),
                        )
                      : AppText.regular(
                          fontSize: 14,
                          color: const Color(0xFF9AA3AF),
                        ),
                ),
              ),
              if (has && !disabled && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF9AA3AF),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: disabled
                      ? const Color(0xFFD0D4DA)
                      : const Color(0xFF9AA3AF),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.words;
    final transportOptions = _transportOptions();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0F3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Заголовок + кнопка сброса
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    w.filterTitle,
                    style: AppText.bold(
                      fontSize: 18,
                      color: const Color(0xFF0F1117),
                    ),
                  ),
                  const Spacer(),
                  if (_loadingAny)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1A7A3C),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () =>
                          setState(() => _draft = const CourierFilters()),
                      child: Text(
                        w.filterReset,
                        style: AppText.medium(
                          fontSize: 13,
                          color: const Color(0xFFD32F1E),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Транспорт ─────────────────────────────────────────────────
            _sectionLabel(w.transportSection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: transportOptions.map((opt) {
                  final bool sel = _draft.transportFilter == opt.$1;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(
                        () => _draft = _draft.copyWith(transportFilter: opt.$1),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF1A7A3C).withValues(alpha: 0.08)
                              : const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? const Color(
                                    0xFF1A7A3C,
                                  ).withValues(alpha: 0.35)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              opt.$2,
                              size: 22,
                              color: sel
                                  ? const Color(0xFF1A7A3C)
                                  : const Color(0xFF9AA3AF),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              opt.$3,
                              style: sel
                                  ? AppText.semiBold(
                                      fontSize: 11,
                                      color: const Color(0xFF1A7A3C),
                                    )
                                  : AppText.regular(
                                      fontSize: 11,
                                      color: const Color(0xFF9AA3AF),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // ── Адрес ОТПРАВКИ ────────────────────────────────────────────
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
            const SizedBox(height: 8),

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
            const SizedBox(height: 8),

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

            const SizedBox(height: 20),

            // ── Адрес ДОСТАВКИ ────────────────────────────────────────────
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
            const SizedBox(height: 8),

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
            const SizedBox(height: 8),

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

            const SizedBox(height: 20),

            // ── Заказчик ──────────────────────────────────────────────────
            _sectionLabel(w.filterShopLabel),
            _pickerTile(
              icon: Icons.store_outlined,
              hint: w.filterPickShop,
              selected: _draft.shop,
              disabled: widget.shopItems.isEmpty,
              onTap: () async {
                final res = await _openPicker(
                  title: w.filterShopLabel,
                  itemsFuture: Future.value(widget.shopItems),
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
                  ? () => setState(() => _draft = _draft.copyWith(shop: null))
                  : null,
            ),

            const SizedBox(height: 28),

            // ── Применить ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => widget.onApply(_draft),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A7A3C), Color(0xFFD32F1E)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A7A3C).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    w.filterApply,
                    style: AppText.semiBold(fontSize: 15, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
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
  final AppLocalizations words; // ← добавлено

  const _FilterPickerSheet({
    required this.title,
    required this.items,
    required this.onSelect,
    required this.words, // ← добавлено
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
    final w = widget.words;
    final filtered = widget.items
        .where((i) => i.label.toLowerCase().contains(_q))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, sc) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0F3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: AppText.bold(
                    fontSize: 16,
                    color: const Color(0xFF0F1117),
                  ),
                ),
                const Spacer(),
                if (widget.onClear != null)
                  GestureDetector(
                    onTap: widget.onClear,
                    child: Text(
                      w.filterReset,
                      style: AppText.medium(
                        fontSize: 13,
                        color: const Color(0xFFD32F1E),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
              style: AppText.regular(
                fontSize: 14,
                color: const Color(0xFF0F1117),
              ),
              decoration: InputDecoration(
                hintText: w.filterSearchHint,
                hintStyle: AppText.regular(
                  fontSize: 13,
                  color: const Color(0xFF9AA3AF),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF9AA3AF),
                  size: 20,
                ),
                suffixIcon: _q.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _q = '');
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF9AA3AF),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFEEF0F3)),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      w.filterNotFound,
                      style: AppText.regular(
                        fontSize: 14,
                        color: const Color(0xFF9AA3AF),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 52,
                      color: Color(0xFFF4F5F7),
                    ),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final isActive = item.id == widget.selectedId;
                      return InkWell(
                        onTap: () => widget.onSelect(item.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(
                                          0xFF1A7A3C,
                                        ).withValues(alpha: 0.08)
                                      : const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.check_rounded
                                      : Icons.location_on_outlined,
                                  size: 16,
                                  color: isActive
                                      ? const Color(0xFF1A7A3C)
                                      : const Color(0xFF9AA3AF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: isActive
                                      ? AppText.semiBold(
                                          fontSize: 14,
                                          color: const Color(0xFF0F1117),
                                        )
                                      : AppText.regular(
                                          fontSize: 14,
                                          color: const Color(0xFF0F1117),
                                        ),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A7A3C),
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
    );
  }
}
