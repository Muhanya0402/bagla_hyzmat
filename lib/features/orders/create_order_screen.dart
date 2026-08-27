import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/image_compression.dart';
import 'package:bagla/core/image_picker_presets.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/core/widgets/photo_picker_sheet.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/models/district.dart';
import 'package:bagla/models/points_rule.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/features/profile/trusted_couriers_service.dart';
import 'package:bagla/core/app_settings_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Срок доставки проставлен автоматически, а не выбран заказчиком.
  /// Нужен, чтобы не отчитывать человека за значение, которое подставило
  /// само приложение: если форма провисела открытой и «сейчас + 40 минут»
  /// уже прошло, такой срок молча сдвигается, а не отвергается с ошибкой.
  bool _deliveryTimeAuto = false;

  /// Сколько курьеров у магазина в списке надёжных. Ноль означает, что режим
  /// «только для своих» включать НЕЛЬЗЯ: заказ не открывается всем никогда,
  /// и с пустым списком он стал бы невидим вообще для всех.
  int _trustedCount = 0;

  /// Заказчик снял пометку вручную на этом заказе.
  bool _trustedOptedOut = false;

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
  // ── Location ───────────────────────────────────────────────────────────────
  //
  // Выбирается только район. Велаят берётся из профиля магазина, этрап —
  // из выбранного района. Раньше здесь был мастер из трёх шагов, но магазин
  // всегда создаёт заказы в своём же велаяте, а этрап однозначно определяется
  // районом — два шага из трёх были лишними нажатиями.
  List<District> _districts = [];
  District? _selectedDistrict;
  bool _loadingDistricts = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<PointsRule> _pointsRules = [];
  final _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _loadDistricts(context.read<LanguageProvider>().words);
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
    // Список надёжных курьеров нужен, чтобы решить, прятать ли дорогой заказ.
    TrustedCouriersService()
        .list(context.read<AuthProvider>().userId)
        .then((list) {
      if (mounted) setState(() => _trustedCount = list.length);
    });
    startTourIfNeeded(
      screenKey: TourKeys.createOrder,
      targetsBuilder: _buildTourTargets,
      shouldSkip: () => context.read<AuthProvider>().shouldSkipTour,
    );
    // Срок доставки по умолчанию — ближайший допустимый (сегодня, через
    // 40 минут). Раньше поле было пустым, и заказчику приходилось лезть в
    // карусель даже когда его устраивало ближайшее время.
    _prefillDeliveryTime();
    // Восстанавливаем незаконченный черновик заказа (если был).
    _draftUserId = context.read<AuthProvider>().userId;
    _restoreDraft();
  }

  void _onAnyFieldChanged() {
    if (mounted) setState(() {});
    _scheduleDraftSave();
  }

  // ── Черновик заказа ────────────────────────────────────────────────────────
  // Автосохранение формы в SharedPreferences (debounced), чтобы при выходе из
  // приложения на полпути заказчик мог продолжить с того же места. Очищается
  // после успешного создания заказа.
  Timer? _draftDebounce;

  // Кешируем в initState — чтобы async-методы черновика не читали context
  // после await (виджет мог размонтироваться).
  String _draftUserId = '';
  String get _draftKey => 'order_draft_$_draftUserId';

  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = <String, dynamic>{
        'phone': _phoneController.text,
        'price': _priceController.text,
        'delivery': _deliveryController.text,
        'transport': _transportType,
        'multiple': _multipleItems,
        'dateTime': _selectedDateTime?.toIso8601String(),
        'locationSelected': _locationSelected,
        'images': _images.map((x) => x.path).toList(),
        // Этрап храним вместе с районом: он нужен для адреса заказа, а
        // отдельного выбора этрапа больше нет.
        if (_selectedDistrict != null)
          'district': {
            'district_id': _selectedDistrict!.id,
            'district_ru': _selectedDistrict!.ru,
            'district_tk': _selectedDistrict!.tk,
            'etrap_id': _selectedDistrict!.etrapId,
            'etrap_ru': _selectedDistrict!.etrapRu,
            'etrap_tk': _selectedDistrict!.etrapTk,
          },
      };
      await prefs.setString(_draftKey, jsonEncode(draft));
    } catch (_) {
      // best-effort — на ошибку молчим
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;

      // Фото: оставляем только те, чьи файлы ещё существуют (ОС могла очистить
      // временные файлы при перезапуске).
      final imgs = <XFile>[];
      for (final p in (d['images'] as List? ?? const [])) {
        final path = p.toString();
        if (path.isNotEmpty && File(path).existsSync()) imgs.add(XFile(path));
      }

      setState(() {
        // Телефон прогоняем через маску, иначе _phoneMask.getUnmaskedText()
        // вернёт пусто и валидация отвергнет восстановленный номер.
        final phoneDigits =
            (d['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        if (phoneDigits.isNotEmpty) {
          _phoneController.value = _phoneMask.formatEditUpdate(
            const TextEditingValue(),
            TextEditingValue(
              text: phoneDigits,
              selection: TextSelection.collapsed(offset: phoneDigits.length),
            ),
          );
        }
        _priceController.text = (d['price'] ?? '').toString();
        _deliveryController.text = (d['delivery'] ?? '').toString();
        _transportType = (d['transport'] ?? 'any').toString();
        _multipleItems = d['multiple'] == true;
        // Пустое значение в черновике не должно затирать подставленный по
        // умолчанию срок — иначе после возврата к черновику поле оказывалось
        // пустым, хотя на свежей форме оно заполнено.
        final dt = d['dateTime'];
        final restoredAt = dt != null ? DateTime.tryParse(dt.toString()) : null;
        if (restoredAt != null) {
          _selectedDateTime = restoredAt;
          _deliveryTimeAuto = false;
          _dateTimeController.text = DateFormat(
            'dd.MM.yyyy HH:mm',
          ).format(restoredAt);
        }
        _images = imgs.take(3).toList();

        final dist = d['district'];
        if (dist is Map) {
          _selectedDistrict = District(
            id: (dist['district_id'] ?? '').toString(),
            ru: (dist['district_ru'] ?? '').toString(),
            tk: (dist['district_tk'] ?? '').toString(),
            etrapId: (dist['etrap_id'] ?? '').toString(),
            etrapRu: (dist['etrap_ru'] ?? '').toString(),
            etrapTk: (dist['etrap_tk'] ?? '').toString(),
          );
        }
        _locationSelected =
            d['locationSelected'] == true && _selectedDistrict != null;
      });
    } catch (_) {
      // повреждённый черновик — игнорируем
    }
  }

  Future<void> _clearDraft() async {
    _draftDebounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  /// Нужны ли фото товара. У кафе/ресторана заказ — готовая еда,
  /// фотографировать нечего: секция скрывается и не валидируется.
  bool get _photosRequired => !context.read<AuthProvider>().isCafe;

  /// Доля заполнения формы создания заказа 0..1 (O1).
  /// Телефон + дата + локация + цена + доставка (+ фото, если нужны).
  double _completionFraction() {
    int done = 0;
    if (_photosRequired && _images.isNotEmpty) done++;
    if (_phoneController.text.trim().isNotEmpty) done++;
    if (_selectedDateTime != null) done++;
    if (_locationSelected) done++;
    if (_priceController.text.trim().isNotEmpty) done++;
    if (_deliveryController.text.trim().isNotEmpty) done++;
    return (done / (_photosRequired ? 6 : 5)).clamp(0.0, 1.0);
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
        // Секция локации — предпоследняя в форме, поэтому доскроллить её до
        // центра нельзя (упирается в конец скролла) и она остаётся в НИЖНЕЙ
        // части экрана. Карточка у низа (bottom) её перекрывала. Пиним карточку
        // у ВЕРХА — там свободно, секция видна целиком, а «Далее» всегда на
        // экране (в отличие от align top, где карточка могла уехать за край).
        customPosition: CustomTargetContentPosition(top: 8),
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
    _draftDebounce?.cancel();
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

  /// Районы велаята, указанного в профиле магазина.
  ///
  /// Велаят не спрашиваем: магазин создаёт заказы в своём же велаяте, а
  /// список районов однозначно из него следует. Если велаят в профиле не
  /// заполнен, список окажется пустым — экран честно скажет об этом, а не
  /// покажет чужие районы.
  Future<void> _loadDistricts(AppLocalizations words) async {
    final provinceId = context.read<AuthProvider>().provinceId;
    setState(() => _loadingDistricts = true);
    try {
      final list = await _authRepo.getDistrictsByProvince(provinceId);
      if (!mounted) return;
      setState(() => _districts = list);
    } catch (e) {
      _msg('${words.errorLoadDistricts}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  void _selectDistrict(District d) {
    setState(() {
      _selectedDistrict = d;
      _searchQuery = '';
      _locationSelected = true;
    });
    _searchCtrl.clear();
    _scheduleDraftSave();
  }

  /// Сбросить выбранный район и вернуться к списку.
  void _resetLocation() {
    setState(() {
      _searchQuery = '';
      _searchCtrl.clear();
      _locationSelected = false;
      _selectedDistrict = null;
    });
    _scheduleDraftSave();
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  /// Минимальный запас между созданием заказа и сроком доставки.
  /// Раньше срок можно было поставить в прошлом — карусель времени шла без
  /// нижней границы, и заказ создавался с уже истёкшим дедлайном.
  static const Duration _minDeliveryLeadTime = Duration(minutes: 40);

  /// Самый ранний допустимый срок доставки, округлённый ВВЕРХ до шага
  /// карусели (5 минут). Вверх — потому что округление вниз дало бы время
  /// раньше положенных 40 минут.
  DateTime get _earliestDelivery {
    final raw = DateTime.now().add(_minDeliveryLeadTime);
    final rest = raw.minute % 5;
    final up = rest == 0 ? raw : raw.add(Duration(minutes: 5 - rest));
    return DateTime(up.year, up.month, up.day, up.hour, up.minute);
  }

  /// Подставить срок доставки по умолчанию: ближайший допустимый момент,
  /// то есть текущая дата плюс 40 минут (округлённые вверх до шага карусели).
  void _prefillDeliveryTime() {
    _selectedDateTime = _earliestDelivery;
    _deliveryTimeAuto = true;
    _dateTimeController.text = DateFormat(
      'dd.MM.yyyy HH:mm',
    ).format(_selectedDateTime!);
  }

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
    final earliest = _earliestDelivery;

    // Стартуем от уже выбранного значения, но не раньше допустимого.
    // Так дата по умолчанию — текущий день (а если до конца суток осталось
    // меньше 40 минут, то следующий), и лишний раз её крутить не нужно.
    final current = _selectedDateTime;
    final initial = (current == null || current.isBefore(earliest))
        ? earliest
        : _roundDownToInterval(current, 5);

    final date = await _showCupertinoWheel(
      mode: CupertinoDatePickerMode.date,
      initial: initial,
      // Нижняя граница — день самого раннего допустимого срока.
      minimum: DateTime(earliest.year, earliest.month, earliest.day),
      maximum: earliest.add(const Duration(days: 14)),
      title: words.deliveryPickDate,
    );
    if (!mounted || date == null) return;

    // Если выбран день самого раннего срока — время нельзя ставить раньше
    // него. На следующие дни ограничение не нужно: там любое время подходит.
    final sameDay = date.year == earliest.year &&
        date.month == earliest.month &&
        date.day == earliest.day;

    var timeInitial = DateTime(
      date.year,
      date.month,
      date.day,
      initial.hour,
      initial.minute,
    );
    if (sameDay && timeInitial.isBefore(earliest)) timeInitial = earliest;

    // Время — без даты в карусели, только часы:минуты.
    final time = await _showCupertinoWheel(
      mode: CupertinoDatePickerMode.time,
      initial: _roundDownToInterval(timeInitial, 5),
      minimum: sameDay ? earliest : null,
      title: words.deliveryPickTime,
    );
    if (!mounted || time == null) return;

    setState(() {
      _deliveryTimeAuto = false;
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
    _scheduleDraftSave();
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

  /// Порог суммы из настроек Directus. Ноль — режим выключен целиком.
  int get _trustedThreshold =>
      context.read<AppSettingsProvider>().trustedAmountThreshold;

  /// Сумма дотягивает до порога — независимо от того, есть ли кому отдать.
  /// Нужно отдельно от [_trustedOnly], чтобы показать магазину подсказку,
  /// когда заказ дорогой, а список надёжных пуст.
  bool _amountReachesThreshold(double total) =>
      _trustedThreshold > 0 && total >= _trustedThreshold;

  /// Итоговое решение по этому заказу.
  bool _trustedOnly(double total) =>
      !_trustedOptedOut &&
      OrderService.shouldBeTrustedOnly(
        totalAmount: total,
        threshold: _trustedThreshold,
        trustedCount: _trustedCount,
      );

  /// Пометка над кнопкой отправки: заказчик должен понимать, что дорогой
  /// заказ увидят не все, и иметь возможность это отменить.
  Widget _buildTrustedNotice(double total, AppLocalizations words) {
    if (!_amountReachesThreshold(total)) return const SizedBox.shrink();
    final c = AppColors.of(context);

    // Список пуст — режим не включится. Молчать нельзя: магазин отправляет
    // дорогой товар и вправе знать, что защита не работает.
    if (_trustedCount == 0) {
      return _noticeBox(
        icon: Icons.info_outline,
        tint: c.amberTint,
        border: c.amber,
        text: words.trustedCreateEmptyHint,
        action: GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/trusted-couriers'),
          child: Text(
            words.trustedCreateEmptyAction,
            style: AppText.semiBold(fontSize: 12, color: c.ink),
          ),
        ),
      );
    }

    final on = _trustedOnly(total);
    return _noticeBox(
      icon: on ? Icons.verified_user_outlined : Icons.public,
      tint: on ? c.emeraldTint : c.bannerBg,
      border: on ? c.accent : c.bannerBorder,
      text: on
          ? words.trustedCreateOn.replaceAll('{n}', '$_trustedCount')
          : words.trustedCreateOff,
      action: Switch.adaptive(
        value: on,
        onChanged: (v) => setState(() => _trustedOptedOut = !v),
      ),
    );
  }

  Widget _noticeBox({
    required IconData icon,
    required Color tint,
    required Color border,
    required String text,
    required Widget action,
  }) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.regular(
                fontSize: 12,
                color: c.ink,
              ).copyWith(height: 1.35),
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }

  Future<void> _submitOrder(AppLocalizations words) async {
    final title = words.regToastFixTitle;

    // ── 1. Фото обязательны (кроме кафе — там фотографировать нечего) ─────
    if (_photosRequired && _images.isEmpty) {
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
    // Форма или черновик могли пролежать так долго, что срок уже прошёл —
    // карусель тут не помогает, проверяем перед отправкой.
    if (_selectedDateTime!.isBefore(_earliestDelivery)) {
      if (_deliveryTimeAuto) {
        // Значение подставили мы сами, человек его не выбирал — молча
        // сдвигаем на ближайший допустимый, а не показываем ошибку.
        setState(_prefillDeliveryTime);
      } else {
        await _scrollToKey(_dateKey);
        _showErrorToast(title, words.deliveryTimeTooSoon);
        return;
      }
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
    // Проверяем и сам район: ниже он берётся без проверки на null, а велаят
    // больше не участвует — гарантию даёт только выбранный район.
    if (!_locationSelected || _selectedDistrict == null) {
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
        // Адрес доставки: «этрап - район». Этрап берётся из самого района,
        // отдельно его больше не выбирают. Если связь не развернулась,
        // остаётся один район — пустого адреса не будет.
        address: _selectedDistrict!.etrapRu.isNotEmpty
            ? "${_selectedDistrict!.etrapRu} - ${_selectedDistrict!.ru}"
            : _selectedDistrict!.ru,
        addresstk: _selectedDistrict!.etrapTk.isNotEmpty
            ? "${_selectedDistrict!.etrapTk} - ${_selectedDistrict!.tk}"
            : _selectedDistrict!.tk,
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
        districtId: _selectedDistrict!.id,
        // Этрап следует из района, велаят — из профиля магазина.
        etrapId: _selectedDistrict!.etrapId.isNotEmpty
            ? _selectedDistrict!.etrapId
            : null,
        provinceId: auth.provinceId,
        shopDistrictId: auth.districtId.isNotEmpty ? auth.districtId : null,
        shopEtrapId: auth.etraptId.isNotEmpty ? auth.etraptId : null,
        shopProvinceId: auth.provinceId.isNotEmpty ? auth.provinceId : null,
        category: auth.category.isNotEmpty ? auth.category : null,
        multipleItems: _multipleItems,
        // Дорогой заказ уходит только надёжным курьерам магазина.
        // Решение принимается здесь, а не на сервере: рассылка пушей
        // срабатывает на создание заказа немедленно.
        trustedOnly: _trustedOnly(itemPrice + deliveryFee),
      );

      // Заказ создан — черновик больше не нужен.
      await _clearDraft();
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
                      // У кафе/ресторана фото не нужны — секцию (вместе с
                      // отметкой «несколько товаров», она тоже про фото)
                      // не показываем. Шаг гида с этим якорем отфильтруется
                      // сам: у ключа не будет context.
                      if (_photosRequired)
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
                      if (_photosRequired) const SizedBox(height: 10),
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
                _buildBottomPanel(deliveryFee, total, words),
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
      onTap: () {
        setState(() => _multipleItems = !_multipleItems);
        _scheduleDraftSave();
      },
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
                // Единый «2-в-1» пикер (камера + сетка галереи), мультивыбор
                // в пределах оставшихся слотов (всего до 3 фото).
                final remaining = 3 - _images.length;
                if (remaining <= 0) return;
                final files = await PhotoPickerSheet.show(
                  context,
                  maxAssets: remaining,
                );
                if (files.isEmpty || !mounted) return;
                // Параллельное сжатие в WebP + EXIF strip.
                final compressed = await Future.wait(
                  files.map((f) =>
                      ImageCompression.compress(f, ImagePresets.orderItem)),
                );
                if (!mounted) return;
                setState(() => _images = [
                      ..._images,
                      ...compressed.map((f) => XFile(f.path)),
                    ].take(3).toList());
                _scheduleDraftSave();
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
                    onTap: () {
                      setState(() => _images.removeAt(index));
                      _scheduleDraftSave();
                    },
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
                onTap: () {
                  setState(() {
                    _selectedDateTime = null;
                    _deliveryTimeAuto = false;
                    _dateTimeController.clear();
                  });
                  _scheduleDraftSave();
                },
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
          onTap: () {
            setState(() => _transportType = value);
            _scheduleDraftSave();
          },
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
        // Индикатора шагов больше нет: шаг остался один — выбор района.
        if (!_locationSelected) _buildSearchField(words),
        const SizedBox(height: 8),
        _locationSelected
            ? _buildLocationDone(isRu)
            : _buildDistrictList(isRu, words),
      ],
    );
  }

  Widget _buildSearchField(AppLocalizations words) {
    return TextField(
      controller: _searchCtrl,
      style: AppText.regular(fontSize: 14, color: AppColors.of(context).ink),
      decoration: InputDecoration(
        hintText: words.searchDistrict,
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
      onTap: _resetLocation,
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
                    _selectedDistrict?.label(isRu) ?? '',
                    style: AppText.semiBold(
                      fontSize: 14,
                      color: AppColors.of(context).ink,
                    ),
                  ),
                  // Второй строкой — этрап выбранного района: он уходит в
                  // адрес заказа, и человек должен видеть, что именно уйдёт.
                  if ((isRu
                          ? _selectedDistrict?.etrapRu
                          : _selectedDistrict?.etrapTk)
                      ?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 2),
                    Text(
                      isRu
                          ? _selectedDistrict!.etrapRu
                          : _selectedDistrict!.etrapTk,
                      style: AppText.regular(
                        fontSize: 12,
                        color: AppColors.of(context).inkMuted,
                      ),
                    ),
                  ],
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
          _buildTrustedNotice(total, words),
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

