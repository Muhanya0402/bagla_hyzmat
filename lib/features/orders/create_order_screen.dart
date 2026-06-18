import 'dart:io';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/image_compression.dart';
import 'package:bagla/core/image_picker_presets.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/core/widgets/point_icon.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/models/district.dart';
import 'package:bagla/models/etrap.dart';
import 'package:bagla/models/points_rule.dart';
import 'package:bagla/models/province.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen>
    with AppTourMixin<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authRepo = AuthRepository();
  bool _isLoading = false;
  bool _locationSelected = false;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();
  final _priceController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _dateTimeController = TextEditingController();

  // ── Focus nodes for seamless keyboard flow ─────────────────────────────────
  final _phoneFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _deliveryFocus = FocusNode();

  // ── Section keys для прокрутки к ошибке валидации ──────────────────────────
  final _photoKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _submitKey = GlobalKey();
  final _scrollController = ScrollController();

  // Маска номера клиента — формат совпадает с phone_screen.
  final _phoneMask = MaskTextInputFormatter(
    mask: '## ## ## ##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  DateTime? _selectedDateTime;
  List<XFile> _images = [];
  String _transportType = 'any';
  bool _multipleItems = false;

  // Только (value, icon) — лейблы локализованные, берём через AppLocalizations.
  static const _transportOptions = [
    ('any', Icons.directions_run_rounded),
    ('car', Icons.directions_car_rounded),
    ('truck', Icons.local_shipping_rounded),
  ];

  String _transportLabel(String value, AppLocalizations words) {
    switch (value) {
      case 'car':
        return words.transportCar;
      case 'truck':
        return words.transportTruck;
      default:
        return words.transportAny;
    }
  }
  final _picker = ImagePicker();

  // ── Location ───────────────────────────────────────────────────────────────
  List<Province> _provinces = [];
  List<Etrap> _etraps = [];
  List<District> _districts = [];

  Province? _selectedProvince;
  Etrap? _selectedEtrap;
  District? _selectedDistrict;

  bool _loadingProvinces = false;
  bool _loadingEtraps = false;
  bool _loadingDistricts = false;

  int _locationStep = 0;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<PointsRule> _pointsRules = [];
  final _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _loadProvinces(context.read<LanguageProvider>().words);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
    // Прогресс-бар реагирует на ввод цены/доставки/телефона.
    _priceController.addListener(_onAnyFieldChanged);
    _deliveryController.addListener(_onAnyFieldChanged);
    _phoneController.addListener(_onAnyFieldChanged);
    _orderService.fetchPointsRules().then((rules) {
      setState(() => _pointsRules = rules);
    });
    startTourIfNeeded(
      screenKey: TourKeys.createOrder,
      targetsBuilder: _buildTourTargets,
      shouldSkip: () => context.read<AuthProvider>().shouldSkipTour,
    );
  }

  void _onAnyFieldChanged() {
    if (mounted) setState(() {});
  }

  /// Доля заполнения формы создания заказа 0..1 (O1).
  /// Фото + телефон + дата + локация + цена + доставка = 6 пунктов.
  double _completionFraction() {
    int done = 0;
    if (_images.isNotEmpty) done++;
    if (_phoneController.text.trim().isNotEmpty) done++;
    if (_selectedDateTime != null) done++;
    if (_locationSelected) done++;
    if (_priceController.text.trim().isNotEmpty) done++;
    if (_deliveryController.text.trim().isNotEmpty) done++;
    return (done / 6).clamp(0.0, 1.0);
  }

  List<TargetFocus> _buildTourTargets() {
    final words = context.read<LanguageProvider>().words;
    return [
      TourTarget.build(
        id: 'create_order_0',
        key: _photoKey,
        title: words.tourCreateOrderPhotoTitle,
        body: words.tourCreateOrderPhotoBody,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        id: 'create_order_1',
        key: _dateKey,
        title: words.tourCreateOrderRecipientTitle,
        body: words.tourCreateOrderRecipientBody,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        id: 'create_order_2',
        key: _locationKey,
        title: words.tourCreateOrderLocationTitle,
        body: words.tourCreateOrderLocationBody,
        align: ContentAlign.top,
      ),
      TourTarget.build(
        id: 'create_order_3',
        key: _submitKey,
        title: words.tourCreateOrderSubmitTitle,
        body: words.tourCreateOrderSubmitBody,
        align: ContentAlign.top,
        isLast: true,
      ),
    ];
  }

  @override
  void dispose() {
    _descController.dispose();
    _phoneController
      ..removeListener(_onAnyFieldChanged)
      ..dispose();
    _priceController
      ..removeListener(_onAnyFieldChanged)
      ..dispose();
    _deliveryController
      ..removeListener(_onAnyFieldChanged)
      ..dispose();
    _dateTimeController.dispose();
    _searchCtrl.dispose();
    _phoneFocus.dispose();
    _priceFocus.dispose();
    _deliveryFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Location loaders ───────────────────────────────────────────────────────

  Future<void> _loadProvinces(AppLocalizations words) async {
    setState(() => _loadingProvinces = true);
    try {
      final list = await _authRepo.getProvinces();
      setState(() => _provinces = list);
    } catch (e) {
      _msg('${words.errorLoadProvinces}: $e', isError: true);
    } finally {
      setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _selectProvince(Province p, AppLocalizations words) async {
    setState(() {
      _selectedProvince = p;
      _selectedEtrap = null;
      _selectedDistrict = null;
      _etraps = [];
      _districts = [];
      _locationStep = 1;
      _searchQuery = '';
      _loadingEtraps = true;
      _locationSelected = false;
    });
    _searchCtrl.clear();
    try {
      final list = await _authRepo.getEtrapsByProvince(p.id);
      setState(() {
        _etraps = list;
        if (list.isEmpty) {
          _locationSelected = true;
          _locationStep = 0;
        }
      });
    } catch (e) {
      _msg('${words.errorLoadEtraps}: $e', isError: true);
    } finally {
      setState(() => _loadingEtraps = false);
    }
  }

  Future<void> _selectEtrap(Etrap e, AppLocalizations words) async {
    setState(() {
      _selectedEtrap = e;
      _selectedDistrict = null;
      _districts = [];
      _locationStep = 2;
      _searchQuery = '';
      _loadingDistricts = true;
      _locationSelected = false;
    });
    _searchCtrl.clear();
    try {
      final list = await _authRepo.getDistrictsByEtrap(e.id);
      setState(() {
        _districts = list;
        if (list.isEmpty) {
          _locationSelected = true;
          _locationStep = 1;
        }
      });
    } catch (e) {
      _msg('${words.errorLoadDistricts}: $e', isError: true);
    } finally {
      setState(() => _loadingDistricts = false);
    }
  }

  void _selectDistrict(District d) {
    setState(() {
      _selectedDistrict = d;
      _searchQuery = '';
      _locationSelected = true;
    });
    _searchCtrl.clear();
  }

  void _resetLocationStep(int step) {
    setState(() {
      _locationStep = step;
      _searchQuery = '';
      _searchCtrl.clear();
      _locationSelected = false;
      if (step == 0) {
        _selectedProvince = null;
        _selectedEtrap = null;
        _selectedDistrict = null;
      } else if (step == 1) {
        _selectedEtrap = null;
        _selectedDistrict = null;
      }
    });
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  /// Округлить минуты вниз до ближайшего шага (требование CupertinoDatePicker).
  DateTime _roundDownToInterval(DateTime dt, int interval) {
    final rounded = dt.minute - (dt.minute % interval);
    return DateTime(dt.year, dt.month, dt.day, dt.hour, rounded);
  }

  /// Двушаговый iOS-style picker:
  /// 1. Выбор даты (CupertinoDatePicker.date — карусель день/месяц/год)
  /// 2. Сразу после — выбор времени (CupertinoDatePicker.time — карусель ч:м)
  /// Результат пишется в `_selectedDateTime` + контроллер.
  Future<void> _pickDateTime() async {
    final words = context.read<LanguageProvider>().words;
    final now = DateTime.now();
    // Инициал должен быть кратен minuteInterval (5), иначе Cupertino падает.
    final initial = _roundDownToInterval(_selectedDateTime ?? now, 5);

    final date = await _showCupertinoWheel(
      mode: CupertinoDatePickerMode.date,
      initial: initial,
      minimum: DateTime(now.year, now.month, now.day),
      maximum: now.add(const Duration(days: 14)),
      title: words.deliveryPickDate,
    );
    if (!mounted || date == null) return;

    // Время — без даты в карусели, только часы:минуты.
    final time = await _showCupertinoWheel(
      mode: CupertinoDatePickerMode.time,
      initial: _roundDownToInterval(
        DateTime(
          date.year,
          date.month,
          date.day,
          initial.hour,
          initial.minute,
        ),
        5,
      ),
      title: words.deliveryPickTime,
    );
    if (!mounted || time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _dateTimeController.text = DateFormat(
        'dd.MM.yyyy HH:mm',
      ).format(_selectedDateTime!);
    });
  }

  /// Универсальный Cupertino-wheel в нижнем модальном листе.
  /// Возвращает выбранную DateTime или null если пользователь отменил.
  Future<DateTime?> _showCupertinoWheel({
    required CupertinoDatePickerMode mode,
    required DateTime initial,
    required String title,
    DateTime? minimum,
    DateTime? maximum,
  }) {
    final words = context.read<LanguageProvider>().words;
    final c = AppColors.of(context);
    DateTime temp = initial;

    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) {
        // Cupertino-popup ставит дефолтный TextStyle с yellow underline
        // как debug-сигнал «текст без DefaultTextStyle предка». Явно задаём
        // нормальный стиль для всех Text внутри + transparent Material для
        // ripple-эффектов (если когда-то добавим).
        return DefaultTextStyle(
          style: AppText.regular(fontSize: 14, color: c.ink)
              .copyWith(decoration: TextDecoration.none),
          child: Material(
          type: MaterialType.transparency,
          child: Container(
          height: 320,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────────
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: c.borderSoft, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Text(
                          words.cancelOrder,
                          style: AppText.medium(
                            fontSize: 14,
                            color: c.inkSoft,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            title,
                            style: AppText.semiBold(fontSize: 15, color: c.ink),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, temp),
                        child: Text(
                          words.done,
                          style: AppText.semiBold(fontSize: 14, color: c.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Wheel ───────────────────────────────────────────────
                Expanded(
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: AppText.medium(
                          fontSize: 18,
                          color: c.ink,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: mode,
                      initialDateTime: initial,
                      minimumDate: minimum,
                      maximumDate: maximum,
                      use24hFormat: true,
                      minuteInterval: 5,
                      onDateTimeChanged: (dt) => temp = dt,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          ),
        );
      },
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _scrollToKey(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.15,
    );
  }

  Future<void> _submitOrder(AppLocalizations words) async {
    final title = words.regToastFixTitle;

    // ── 1. Фото обязательны ────────────────────────────────────────────────
    if (_images.isEmpty) {
      await _scrollToKey(_photoKey);
      _showErrorToast(title, words.addPhotoError);
      return;
    }

    // ── 2. Текстовые поля по порядку (телефон → цена → доставка) ───────────
    // Маска кладёт в controller пробелы — для валидации нужны только цифры.
    final phoneDigits = _phoneMask.getUnmaskedText();
    if (phoneDigits.length < 8) {
      _phoneFocus.requestFocus();
      _showErrorToast(title, words.phoneShort);
      return;
    }

    // ── 3. Дата/время ──────────────────────────────────────────────────────
    if (_selectedDateTime == null) {
      await _scrollToKey(_dateKey);
      _showErrorToast(title, words.selectTimeError);
      return;
    }

    final price = _priceController.text.trim();
    if (price.isEmpty || price == '0') {
      _priceFocus.requestFocus();
      _showErrorToast(title, words.specifyPrice);
      return;
    }

    final delivery = _deliveryController.text.trim();
    if (delivery.isEmpty || delivery == '0') {
      _deliveryFocus.requestFocus();
      _showErrorToast(title, words.specifyDelivery);
      return;
    }

    // ── 4. Локация ─────────────────────────────────────────────────────────
    if (!_locationSelected) {
      await _scrollToKey(_locationKey);
      _showErrorToast(title, words.selectDistrictError);
      return;
    }

    // Form-level validate — для двойной перестраховки (errorBorder на полях).
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    try {
      final double itemPrice = double.parse(_priceController.text);
      final double deliveryFee = double.parse(_deliveryController.text);

      await OrderService().createOrder(
        address: _selectedDistrict != null
            ? "${_selectedEtrap!.ru} - ${_selectedDistrict!.ru}"
            : _selectedEtrap != null
            ? _selectedEtrap!.ru
            : _selectedProvince!.ru,
        addresstk: _selectedDistrict != null
            ? "${_selectedEtrap!.tk} - ${_selectedDistrict!.tk}"
            : _selectedEtrap != null
            ? _selectedEtrap!.tk
            : _selectedProvince!.tk,
        // Адрес магазина (RU/TK) строится по тому же принципу, что
        // delivery-адрес выше — из province/etrap/district магазина,
        // которые AuthProvider подгружает из prefs (туда их пишет
        // AuthRepository при логине/refresh профиля). Раньше тут было
        // `auth.address` в оба поля → TK-версия совпадала с RU и
        // фронт у курьера показывал русский адрес при туркменском UI.
        // Если все три уровня пусты — оба геттера возвращают `_address`
        // как fallback, поведение legacy сохраняется.
        shopAddress: auth.shopAddressRu,
        shopAddressTk: auth.shopAddressTk,
        transportType: _transportType,
        phone: _phoneController.text,
        comment: '',
        deliveryTime: _selectedDateTime,
        itemPrice: itemPrice,
        deliveryFee: deliveryFee,
        pointsAmount: _orderService.calculatePoints(deliveryFee, _pointsRules),
        images: _images,
        userId: auth.userId,
        shopPhone: auth.phone,
        districtId: _selectedDistrict?.id,
        etrapId: _selectedEtrap?.id,
        provinceId: _selectedProvince!.id,
        shopDistrictId: auth.districtId.isNotEmpty ? auth.districtId : null,
        shopEtrapId: auth.etraptId.isNotEmpty ? auth.etraptId : null,
        shopProvinceId: auth.provinceId.isNotEmpty ? auth.provinceId : null,
        category: auth.category.isNotEmpty ? auth.category : null,
        multipleItems: _multipleItems,
      );

      _msg(words.orderCreated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _msg('${words.error}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Anthropic-стиль: warning toast с заголовком + подзаголовком.
  void _showErrorToast(String title, String subtitle) {
    final c = AppColors.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: c.amberTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.priority_high_rounded, size: 18, color: c.amber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppText.semiBold(fontSize: 14, color: c.ink)
                        .copyWith(letterSpacing: 0.1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.regular(fontSize: 12.5, color: c.inkMuted)
                        .copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: c.surface,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.amber.withValues(alpha: 0.35), width: 1),
        ),
      ),
    );
  }

  void _msg(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: AppText.regular(fontSize: 13)),
        backgroundColor: isError
            ? AppColors.of(context).errorMuted
            : AppColors.of(context).ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final isRu = lang.isRu;
    final double deliveryFee = double.tryParse(_deliveryController.text) ?? 0;
    final double itemPrice = double.tryParse(_priceController.text) ?? 0;
    final double total = itemPrice + deliveryFee;
    final int points = _orderService.calculatePoints(deliveryFee, _pointsRules);

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        elevation: 0,
        centerTitle: false,
        leading: Semantics(
          button: true,
          label: words.a11yBack,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.of(context).borderSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.of(context).inkMuted,
                size: 16,
              ),
            ),
          ),
        ),
        title: Text(
          words.newOrder,
          style: AppText.serif(fontSize: 20, color: AppColors.of(context).ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          // Прогресс заполнения заказа (O1).
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _completionFraction()),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: AppColors.of(context).borderSoft,
              valueColor: AlwaysStoppedAnimation(AppColors.of(context).ink),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        // Тап по пустому месту body — закрывает клавиатуру.
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    // Скролл вниз/вверх — закрывает клавиатуру.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      KeyedSubtree(
                        key: _photoKey,
                        child: _section(
                          icon: Icons.camera_alt_outlined,
                          title: words.orderPhoto,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _imagePickerWidget(words),
                              const SizedBox(height: 12),
                              _multipleItemsCheckbox(words),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      KeyedSubtree(
                        key: _dateKey,
                        child: _section(
                          icon: Icons.person_outline_rounded,
                          title: words.orderRecipient,
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              _phoneField(words),
                              const SizedBox(height: 8),
                              _dateField(words),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _section(
                        icon: Icons.inventory_2_outlined,
                        title: words.orderDetails,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            _priceField(words),
                            const SizedBox(height: 8),
                            _deliveryField(words),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _section(
                        icon: Icons.local_shipping_outlined,
                        title: words.transportSection,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _transportField(words),
                        ),
                      ),
                      const SizedBox(height: 10),
                      KeyedSubtree(
                        key: _locationKey,
                        child: _section(
                          icon: Icons.map_outlined,
                          title: words.orderDeliveryArea,
                          child: _buildLocationStepper(isRu, words),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                _buildBottomPanel(deliveryFee, total, points, words),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.12),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.of(context).ink,
                  strokeWidth: 2.5,
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  // ── Section wrapper ────────────────────────────────────────────────────────

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).ink.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.of(context).ink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 13, color: AppColors.of(context).inkSoft),
              const SizedBox(width: 5),
              Text(
                title.toUpperCase(),
                style: AppText.semiBold(
                  fontSize: 10,
                  color: AppColors.of(context).inkSoft,
                ).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Image picker ───────────────────────────────────────────────────────────

  /// Чекбокс «Несколько товаров на выбор» — даёт магазину сказать курьеру,
  /// что нужно сфотать каждую вариацию, чтобы клиент выбрал.
  Widget _multipleItemsCheckbox(AppLocalizations words) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _multipleItems = !_multipleItems),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: _multipleItems ? c.emeraldTint : c.borderSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _multipleItems
                ? c.ink.withValues(alpha: 0.35)
                : c.border,
            width: _multipleItems ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _multipleItems ? c.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _multipleItems ? c.ink : c.border,
                  width: 1.5,
                ),
              ),
              child: _multipleItems
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    words.orderMultipleItemsLabel,
                    style: AppText.semiBold(fontSize: 13.5, color: c.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    words.orderMultipleItemsHint,
                    style:
                        AppText.regular(fontSize: 11.5, color: c.inkMuted)
                            .copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerWidget(AppLocalizations words) {
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + (_images.length < 3 ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _images.length) {
            return GestureDetector(
              onTap: () async {
                // image_picker даёт «как есть» (raw), потом сжимаем в WebP.
                final selected = await _picker.pickMultiImage();
                if (selected.isEmpty || !mounted) return;
                // Параллельное сжатие — 3 фото обычно ~1-2 сек на средних телефонах.
                final compressed = await Future.wait(
                  selected.map((x) => ImageCompression.compress(
                        File(x.path),
                        ImagePresets.orderItem,
                      )),
                );
                if (!mounted) return;
                // image_picker отдаёт XFile — после сжатия XFile из File-пути.
                final asXFiles = compressed.map((f) => XFile(f.path)).toList();
                setState(() => _images =
                    [..._images, ...asXFiles].take(3).toList());
              },
              child: Container(
                width: 84,
                height: 84,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.of(context).bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.of(context).ink.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.of(context).ink.withValues(alpha: 0.6),
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      words.addPhoto,
                      style: AppText.regular(
                        fontSize: 10,
                        color: AppColors.of(context).inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_images[index].path),
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(index)),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Shared input decoration ────────────────────────────────────────────────

  InputDecoration _fieldDecor({
    required String hint,
    Widget? prefix,
    String? suffixText,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: AppText.regular(
      fontSize: 14,
      color: AppColors.of(context).inkSoft,
    ),
    prefixIcon: prefix,
    suffixText: suffixText,
    suffixStyle: AppText.regular(
      fontSize: 13,
      color: AppColors.of(context).inkSoft,
    ),
    filled: true,
    fillColor: AppColors.of(context).borderSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.of(context).border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.of(context).ink.withValues(alpha: 0.55),
        width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.of(context).errorMuted.withValues(alpha: 0.4),
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.of(context).errorMuted.withValues(alpha: 0.6),
        width: 1.5,
      ),
    ),
    errorStyle: AppText.regular(
      fontSize: 11,
      color: AppColors.of(context).errorMuted,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );

  // ── Fields ─────────────────────────────────────────────────────────────────

  /// Phone input — визуально совпадает с PhoneScreen: 🇹🇲 +993 | mask `__ __ __ __`.
  /// Контроллер хранит маскированный текст; на сервер уходит цифровая часть.
  Widget _phoneField(AppLocalizations words) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Country pill: флаг + +993 ───────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
            height: 56,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: c.borderSoft, width: 1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🇹🇲', style: TextStyle(fontSize: 17)),
                const SizedBox(width: 8),
                Text(
                  '+993',
                  style: AppText.semiBold(fontSize: 14, color: c.ink),
                ),
              ],
            ),
          ),
          // ── Mask-формат `__ __ __ __` ───────────────────────────────────
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [_phoneMask],
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_priceFocus),
              style: AppText.medium(fontSize: 16, color: c.ink)
                  .copyWith(letterSpacing: 0.4),
              cursorColor: c.ink,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                hintText: '__ __ __ __',
                hintStyle: AppText.regular(fontSize: 16, color: c.inkSoft)
                    .copyWith(letterSpacing: 0.4),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
              ),
              validator: (v) {
                // _phoneMask.getUnmaskedText() даёт чистые цифры; всего должно
                // быть 8 (туркменский локальный номер без префикса).
                final digits = _phoneMask.getUnmaskedText();
                if (digits.length < 8) return words.phoneShort;
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(AppLocalizations words) {
    return GestureDetector(
      onTap: _pickDateTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.of(context).borderSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.of(context).border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _selectedDateTime != null
                    ? AppColors.of(context).ink.withValues(alpha: 0.1)
                    : AppColors.of(context).border,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: _selectedDateTime != null
                    ? AppColors.of(context).ink
                    : AppColors.of(context).inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    words.deliveryTime,
                    style: AppText.regular(
                      fontSize: 11,
                      color: AppColors.of(context).inkSoft,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedDateTime != null
                        ? DateFormat(
                            'dd MMMM, HH:mm',
                            'ru',
                          ).format(_selectedDateTime!)
                        : words.deliveryTimeNone,
                    style: AppText.semiBold(
                      fontSize: 14,
                      color: _selectedDateTime != null
                          ? AppColors.of(context).ink
                          : AppColors.of(context).inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedDateTime != null)
              GestureDetector(
                onTap: () => setState(() {
                  _selectedDateTime = null;
                  _dateTimeController.clear();
                }),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.of(
                      context,
                    ).errorMuted.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.of(context).errorMuted,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.of(context).inkSoft,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _priceField(AppLocalizations words) {
    return TextFormField(
      controller: _priceController,
      focusNode: _priceFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      onFieldSubmitted: (_) =>
          FocusScope.of(context).requestFocus(_deliveryFocus),
      style: AppText.semiBold(fontSize: 16, color: AppColors.of(context).ink),
      decoration: _fieldDecor(
        hint: words.itemPriceHint,
        prefix: Icon(
          Icons.payments_outlined,
          color: AppColors.of(context).ink,
          size: 18,
        ),
        suffixText: 'TMT',
      ),
      validator: (v) =>
          (v == null || v.isEmpty || v == '0') ? words.specifyPrice : null,
    );
  }

  Widget _deliveryField(AppLocalizations words) {
    return TextFormField(
      controller: _deliveryController,
      focusNode: _deliveryFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      style: AppText.semiBold(fontSize: 16, color: AppColors.of(context).ink),
      decoration: _fieldDecor(
        hint: words.deliveryPriceHint,
        prefix: Icon(
          Icons.delivery_dining_outlined,
          color: AppColors.of(context).ink,
          size: 18,
        ),
        suffixText: 'TMT',
      ),
      validator: (v) =>
          (v == null || v.isEmpty || v == '0') ? words.specifyDelivery : null,
    );
  }

  Widget _transportField(AppLocalizations words) {
    return Column(
      children: _transportOptions.map((opt) {
        final (value, icon) = opt;
        final label = _transportLabel(value, words);
        final isSelected = _transportType == value;
        return GestureDetector(
          onTap: () => setState(() => _transportType = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.of(context).emeraldTint
                  : AppColors.of(context).borderSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.of(context).ink.withValues(alpha: 0.4)
                    : AppColors.of(context).border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.of(context).ink.withValues(alpha: 0.12)
                        : AppColors.of(context).border,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: isSelected
                        ? AppColors.of(context).ink
                        : AppColors.of(context).inkSoft,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.medium(
                      fontSize: 14,
                      color: isSelected
                          ? AppColors.of(context).ink
                          : AppColors.of(context).inkMuted,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.of(context).ink
                        : Colors.transparent,
                    border: isSelected
                        ? null
                        : Border.all(
                            color: AppColors.of(context).border,
                            width: 1.5,
                          ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check_rounded, color: Colors.white, size: 12)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Location stepper ───────────────────────────────────────────────────────

  Widget _buildLocationStepper(bool isRu, AppLocalizations words) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(words),
        const SizedBox(height: 12),
        if (_selectedProvince != null ||
            _selectedEtrap != null ||
            _selectedDistrict != null)
          _buildBreadcrumb(isRu),
        if (_locationStep > 0 && !_locationSelected) ...[
          const SizedBox(height: 8),
          _buildSearchField(words),
        ],
        const SizedBox(height: 8),
        _locationSelected
            ? _buildLocationDone(isRu)
            : _buildCurrentStepList(isRu, words),
      ],
    );
  }

  Widget _buildStepIndicator(AppLocalizations words) {
    final steps = [words.stepProvince, words.stepEtrap, words.stepDistrict];
    return Row(
      children: List.generate(3, (i) {
        final isDone =
            i < _locationStep || (i == 2 && _selectedDistrict != null);
        final isActive = i == _locationStep && _selectedDistrict == null;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (i < _locationStep) _resetLocationStep(i);
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3,
                        decoration: BoxDecoration(
                          color: (isDone || isActive)
                              ? AppColors.of(context).ink
                              : AppColors.of(context).border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        steps[i],
                        style:
                            AppText.medium(
                              fontSize: 10,
                              color: (isDone || isActive)
                                  ? AppColors.of(context).ink
                                  : AppColors.of(context).inkSoft,
                            ).copyWith(
                              fontWeight: isActive ? FontWeight.w700 : null,
                            ),
                      ),
                    ],
                  ),
                ),
                if (i < 2) const SizedBox(width: 6),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBreadcrumb(bool isRu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (_selectedProvince != null)
            _BreadcrumbChip(
              label: _selectedProvince!.label(isRu),
              onTap: () => _resetLocationStep(0),
            ),
          if (_selectedEtrap != null && !_locationSelected)
            _BreadcrumbChip(
              label: _selectedEtrap!.label(isRu),
              onTap: () => _resetLocationStep(1),
            ),
          if (_selectedDistrict != null && !_locationSelected)
            _BreadcrumbChip(
              label: _selectedDistrict!.label(isRu),
              isSelected: true,
              onTap: () => _resetLocationStep(1),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations words) {
    final hints = ['', words.searchEtrap, words.searchDistrict];
    return TextField(
      controller: _searchCtrl,
      style: AppText.regular(fontSize: 14, color: AppColors.of(context).ink),
      decoration: InputDecoration(
        hintText: hints[_locationStep],
        hintStyle: AppText.regular(
          fontSize: 14,
          color: AppColors.of(context).inkSoft,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.of(context).inkSoft,
          size: 20,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.of(context).inkSoft,
                ),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.of(context).borderSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.of(context).border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.of(context).ink.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildCurrentStepList(bool isRu, AppLocalizations words) {
    if (_locationStep == 0) return _buildProvinceGrid(isRu, words);
    if (_locationStep == 1) return _buildEtrapList(isRu, words);
    return _buildDistrictList(isRu, words);
  }

  Widget _buildProvinceGrid(bool isRu, AppLocalizations words) {
    if (_loadingProvinces) return _loader();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.8,
      ),
      itemCount: _provinces.length,
      itemBuilder: (_, i) {
        final p = _provinces[i];
        return GestureDetector(
          onTap: () => _selectProvince(p, words),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.of(context).borderSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.of(context).border),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              p.label(isRu),
              textAlign: TextAlign.center,
              style: AppText.semiBold(
                fontSize: 13,
                color: AppColors.of(context).ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEtrapList(bool isRu, AppLocalizations words) {
    if (_loadingEtraps) return _loader();
    final filtered = _etraps
        .where((e) => e.label(isRu).toLowerCase().contains(_searchQuery))
        .toList();
    return _itemList(
      items: filtered,
      labelFn: (e) => e.label(isRu),
      onTap: (e) => _selectEtrap(e, words),
      words: words,
    );
  }

  Widget _buildDistrictList(bool isRu, AppLocalizations words) {
    if (_loadingDistricts) return _loader();
    final filtered = _districts
        .where((d) => d.label(isRu).toLowerCase().contains(_searchQuery))
        .toList();
    return _itemList(
      items: filtered,
      labelFn: (d) => d.label(isRu),
      onTap: (d) => _selectDistrict(d),
      words: words,
    );
  }

  Widget _itemList<T>({
    required List<T> items,
    required String Function(T) labelFn,
    required void Function(T) onTap,
    required AppLocalizations words,
  }) {
    if (items.isEmpty) {
      return Container(
        height: 64,
        alignment: Alignment.center,
        child: Text(
          _searchQuery.isEmpty ? words.noData : words.filterNotFound,
          style: AppText.regular(
            fontSize: 14,
            color: AppColors.of(context).inkSoft,
          ),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: AppColors.of(context).borderSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, _) => Container(
            height: 0.5,
            margin: const EdgeInsets.only(left: 16),
            color: AppColors.of(context).border,
          ),
          itemBuilder: (_, i) {
            final item = items[i];
            return InkWell(
              onTap: () => onTap(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        labelFn(item),
                        style: AppText.medium(
                          fontSize: 14,
                          color: AppColors.of(context).ink,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: AppColors.of(context).inkSoft,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationDone(bool isRu) {
    return GestureDetector(
      onTap: () => _resetLocationStep(0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.of(context).emeraldTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.of(context).ink.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.of(context).ink,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.check, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDistrict?.label(isRu) ??
                        _selectedEtrap?.label(isRu) ??
                        _selectedProvince?.label(isRu) ??
                        '',
                    style: AppText.semiBold(
                      fontSize: 14,
                      color: AppColors.of(context).ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      _selectedProvince?.label(isRu),
                      if (_selectedEtrap != null) _selectedEtrap!.label(isRu),
                    ].whereType<String>().join(' · '),
                    style: AppText.regular(
                      fontSize: 12,
                      color: AppColors.of(context).inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 15,
              color: AppColors.of(context).inkSoft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _loader() {
    return Container(
      height: 64,
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        color: AppColors.of(context).ink,
        strokeWidth: 2,
      ),
    );
  }

  // ── Bottom panel ───────────────────────────────────────────────────────────

  Widget _buildBottomPanel(
    double delivery,
    double total,
    int points,
    AppLocalizations words,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        border: Border(top: BorderSide(color: AppColors.of(context).border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (points > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.of(context).amberTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.of(context).border),
              ),
              child: Row(
                children: [
                  PointIcon(size: 16, tintColor: AppColors.of(context).amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      words.createOrderTokensInfo
                          .replaceAll('{n}', '$points'),
                      style: AppText.medium(
                        fontSize: 12,
                        color: AppColors.of(context).ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${words.courierPays}: ${delivery.toStringAsFixed(0)} TMT',
                      style: AppText.regular(
                        fontSize: 11,
                        color: AppColors.of(context).inkSoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          total.toStringAsFixed(0),
                          style: AppText.semiBold(
                            fontSize: 22,
                            color: total > 0
                                ? AppColors.of(context).ink
                                : AppColors.of(context).inkSoft,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'TMT',
                          style: AppText.regular(
                            fontSize: 12,
                            color: AppColors.of(context).inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              KeyedSubtree(
                key: _submitKey,
                child: _SubmitButton(
                  label: words.placeOrder,
                  isLoading: _isLoading,
                  onTap: () => _submitOrder(words),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Submit button — spring press + emerald fill ───────────────────────────────

class _SubmitButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: widget.isLoading
                ? AppColors.of(context).inkSoft.withValues(alpha: 0.22)
                : AppColors.of(context).ink,
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isLoading
                ? null
                : [
                    BoxShadow(
                      color: AppColors.of(context).ink.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  widget.label,
                  style: AppText.semiBold(fontSize: 14, color: Colors.white),
                ),
        ),
      ),
    );
  }
}

// ── Breadcrumb chip ───────────────────────────────────────────────────────────

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _BreadcrumbChip({
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.of(context).ink
              : AppColors.of(context).borderSoft,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: AppColors.of(context).border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.semiBold(
                fontSize: 12,
                color: isSelected ? Colors.white : AppColors.of(context).ink,
              ),
            ),
            if (!isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.close, size: 12, color: AppColors.of(context).inkSoft),
            ],
          ],
        ),
      ),
    );
  }
}
