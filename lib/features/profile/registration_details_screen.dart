import 'dart:async';
import 'dart:io';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/image_compression.dart';
import 'package:bagla/core/image_picker_presets.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:bagla/core/widgets/photo_picker_sheet.dart';
import 'package:bagla/features/profile/widgets/shop_categories.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/models/district.dart';
import 'package:bagla/models/etrap.dart';
import 'package:bagla/models/province.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// ─── Какое фото грузим ────────────────────────────────────────────────────────
enum _PhotoSlot { passportMain, passportAddress, passportFace, selfie }

class RegistrationDetailsScreen extends StatefulWidget {
  final String role;
  const RegistrationDetailsScreen({super.key, required this.role});

  @override
  State<RegistrationDetailsScreen> createState() =>
      _RegistrationDetailsScreenState();
}

class _RegistrationDetailsScreenState
    extends State<RegistrationDetailsScreen>
    with AppTourMixin<RegistrationDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authRepo = AuthRepository();
  final _picker = ImagePicker();

  bool _isLoading = false;

  // 4 файла у курьера (раньше было 2).
  final Map<_PhotoSlot, File?> _photos = {
    _PhotoSlot.passportMain: null,
    _PhotoSlot.passportAddress: null,
    _PhotoSlot.passportFace: null,
    _PhotoSlot.selfie: null,
  };

  // Ввод имени/фамилии/отчества (курьер) или названия (магазин).
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();

  // Фокусы — нужны чтобы прыгать на пустое поле при валидации.
  final _f1 = FocusNode();
  final _f2 = FocusNode();
  final _f3 = FocusNode();

  // GlobalKey'и секций — для scrollToEnsureVisible на не-text полях
  // и одновременно для тура (подсветка).
  final _locationKey = GlobalKey();
  final _categoryKey = GlobalKey();
  final _transportKey = GlobalKey();
  final _photosKey = GlobalKey();
  final _submitKey = GlobalKey();

  final _scrollController = ScrollController();

  List<Province> _provinces = [];
  List<Etrap> _etraps = [];
  List<District> _districts = [];

  Province? _selectedProvince;
  Etrap? _selectedEtrap;
  District? _selectedDistrict;

  bool _loadingProvinces = false;
  bool _loadingEtraps = false;
  bool _loadingDistricts = false;
  bool _locationSelected = false;
  String _transportType = 'any';

  // Категория магазина (для role == shop).
  ShopCategory? _selectedCategory;
  // null пока грузим, после — серверные категории или fallback.
  List<ShopCategory>? _categories;

  int _locationStep = 0;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Кэшируем messenger — нужен в dispose() где context недоступен.
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    if (widget.role == 'shop') _loadCategories();
    _searchController.addListener(_onSearchChanged);
    // Прогресс-бар реагирует на ввод имени/названия — обновляем при печати.
    _c1.addListener(_onAnyFieldChanged);
    _c2.addListener(_onAnyFieldChanged);
    _c3.addListener(_onAnyFieldChanged);
    _restoreDraft(); // A3 — восстановить незаконченный черновик
    startTourIfNeeded(
      screenKey: TourKeys.regDetails,
      targetsBuilder: _buildTourTargets,
    );
  }

  /// Лёгкий ребилд для обновления прогресс-бара при вводе текста + сохранение
  /// черновика (debounced).
  void _onAnyFieldChanged() {
    if (mounted) setState(() {});
    _scheduleDraftSave();
  }

  // ── Draft (A3) ───────────────────────────────────────────────────────────
  // Сохраняем ТОЛЬКО безопасно-сериализуемое: текстовые поля, транспорт,
  // категорию. Локацию и фото НЕ восстанавливаем — там async-загрузка
  // моделей с сервера и валидность файлов, авто-restore рискован.
  Timer? _draftDebounce;

  String get _draftKey => 'reg_draft_${widget.role}';

  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, String>{
        'c1': _c1.text,
        'c2': _c2.text,
        'c3': _c3.text,
        'transport': _transportType,
        'category': _selectedCategory?.id.toString() ?? '',
      };
      // Простая сериализация key=value через -разделитель.
      final encoded = map.entries.map((e) => '${e.key}${e.value}').join('');
      await prefs.setString(_draftKey, encoded);
    } catch (_) {
      // Сохранение черновика — best-effort, на ошибку молчим.
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return;
      final map = <String, String>{};
      for (final pair in raw.split('')) {
        final i = pair.indexOf('');
        if (i > 0) map[pair.substring(0, i)] = pair.substring(i + 1);
      }
      if (!mounted) return;
      setState(() {
        if ((map['c1'] ?? '').isNotEmpty) _c1.text = map['c1']!;
        if ((map['c2'] ?? '').isNotEmpty) _c2.text = map['c2']!;
        if ((map['c3'] ?? '').isNotEmpty) _c3.text = map['c3']!;
        final t = map['transport'];
        if (t != null && t.isNotEmpty) _transportType = t;
      });
      // Категорию восстанавливаем после загрузки списка (match по id).
      _pendingCategoryId = map['category'];
    } catch (_) {
      // Восстановление — best-effort.
    }
  }

  /// id категории из черновика, ждёт загрузки _categories для match'а.
  String? _pendingCategoryId;

  /// Применить отложенную категорию из черновика после загрузки списка.
  void _applyPendingCategory() {
    final id = _pendingCategoryId;
    if (id == null) return;
    final cats = _categories;
    if (cats == null) return;
    for (final cat in cats) {
      if (cat.id.toString() == id) {
        _selectedCategory = cat;
        break;
      }
    }
    _pendingCategoryId = null;
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  /// Доля заполнения формы 0..1 для прогресс-бара (A2).
  /// Курьер: имя+фамилия+отчество + локация + 4 фото = 8 пунктов.
  /// Магазин: название + локация + категория = 3 пункта.
  double _completionFraction() {
    final isCourier = widget.role == 'courier';
    int total;
    int done = 0;
    if (isCourier) {
      total = 8;
      if (_c1.text.trim().isNotEmpty) done++;
      if (_c2.text.trim().isNotEmpty) done++;
      if (_c3.text.trim().isNotEmpty) done++;
      if (_locationSelected) done++;
      done += _photos.values.where((f) => f != null).length; // 0..4
    } else {
      total = 3;
      if (_c1.text.trim().isNotEmpty) done++;
      if (_locationSelected) done++;
      if (_selectedCategory != null) done++;
    }
    return (done / total).clamp(0.0, 1.0);
  }

  /// Тур-шаги под роль:
  ///   - локация (общее)
  ///   - фото (только курьер; у магазина пропускаем — там фото не нужны)
  ///   - submit
  List<TargetFocus> _buildTourTargets() {
    final words = context.read<LanguageProvider>().words;
    final isCourier = widget.role == 'courier';
    return [
      TourTarget.build(
        id: 'reg_details_location',
        key: _locationKey,
        title: words.tourRegLocationTitle,
        body: words.tourRegLocationBody,
        align: ContentAlign.bottom,
      ),
      if (isCourier)
        TourTarget.build(
          id: 'reg_details_photos',
          key: _photosKey,
          title: words.tourRegPhotosTitle,
          body: words.tourRegPhotosBody,
          align: ContentAlign.top,
        ),
      TourTarget.build(
        id: 'reg_details_submit',
        key: _submitKey,
        title: words.tourRegSubmitTitle,
        body: words.tourRegSubmitBody,
        align: ContentAlign.top,
        isLast: true,
      ),
    ];
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _authRepo.getShopCategories();
      if (!mounted) return;
      setState(() {
        _categories = list.isNotEmpty ? list : kLocalShopCategories;
        _applyPendingCategory();
      });
    } catch (_) {
      // Сеть/сервер недоступны — даём пользователю продолжить с локальным
      // списком. На submit Directus всё равно проверит m2o-связь.
      if (mounted) setState(() => _categories = kLocalShopCategories);
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _messenger?.clearSnackBars();
    _searchDebounce?.cancel();
    _draftDebounce?.cancel();
    _c1
      ..removeListener(_onAnyFieldChanged)
      ..dispose();
    _c2
      ..removeListener(_onAnyFieldChanged)
      ..dispose();
    _c3
      ..removeListener(_onAnyFieldChanged)
      ..dispose();
    _f1.dispose();
    _f2.dispose();
    _f3.dispose();
    _scrollController.dispose();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadProvinces() async {
    if (!mounted) return;
    setState(() => _loadingProvinces = true);
    try {
      final list = await _authRepo.getProvinces();
      if (!mounted) return;
      setState(() => _provinces = list);
    } catch (_) {
      if (mounted) {
        _showToast(
          context.read<LanguageProvider>().words.regErrorLoadProvinces,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _selectProvince(Province p) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedProvince = p;
      _selectedEtrap = null;
      _selectedDistrict = null;
      _etraps = [];
      _districts = [];
      _locationStep = 1;
      _searchQuery = '';
      _searchController.clear();
      _loadingEtraps = true;
      _locationSelected = false;
    });
    try {
      final list = await _authRepo.getEtrapsByProvince(p.id);
      if (!mounted) return;
      setState(() {
        _etraps = list;
        // Велаят без этрапов → достаточно только провинции.
        if (list.isEmpty) {
          _locationSelected = true;
          _locationStep = 0;
        }
      });
    } catch (_) {
      if (mounted) {
        _showToast(context.read<LanguageProvider>().words.regErrorLoadEtraps);
      }
    } finally {
      if (mounted) setState(() => _loadingEtraps = false);
    }
  }

  Future<void> _selectEtrap(Etrap e) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedEtrap = e;
      _selectedDistrict = null;
      _districts = [];
      _locationStep = 2;
      _searchQuery = '';
      _searchController.clear();
      _loadingDistricts = true;
      _locationSelected = false;
    });
    try {
      final list = await _authRepo.getDistrictsByEtrap(e.id);
      if (!mounted) return;
      setState(() {
        _districts = list;
        // Этрап без районов → достаточно велаят+этрап.
        if (list.isEmpty) {
          _locationSelected = true;
          _locationStep = 1;
        }
      });
    } catch (_) {
      if (mounted) {
        _showToast(
          context.read<LanguageProvider>().words.regErrorLoadDistricts,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  void _selectDistrict(District d) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedDistrict = d;
      _searchQuery = '';
      _searchController.clear();
      _locationSelected = true;
    });
  }

  void _resetLocationStep(int step) {
    setState(() {
      _locationStep = step;
      _searchQuery = '';
      _searchController.clear();
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

  // ── Photo ──────────────────────────────────────────────────────────────────

  /// Пресет сжатия по типу слота: паспортные — крупнее и качественнее
  /// (текст читаем), селфи/лицо — обычный «лицевой» пресет.
  ImagePreset _presetFor(_PhotoSlot slot) {
    switch (slot) {
      case _PhotoSlot.passportMain:
      case _PhotoSlot.passportAddress:
      case _PhotoSlot.passportFace:
        return ImagePresets.passportPage;
      case _PhotoSlot.selfie:
        return ImagePresets.face;
    }
  }

  Future<void> _pickImage(_PhotoSlot slot) async {
    // Единый «2-в-1» пикер: камера + инлайн-сетка галереи. Возвращает File.
    final picked = await PhotoPickerSheet.show(context);
    if (picked == null || !mounted) return;
    // Сжимаем нативно в WebP + EXIF strip.
    final compressed = await ImageCompression.compress(
      picked,
      _presetFor(slot),
    );
    if (!mounted) return;
    setState(() => _photos[slot] = compressed);
  }

  /// Фото лица — сразу фронтальная камера, без выбора источника.
  /// Результат автоматически попадает в `_PhotoSlot.selfie`.
  Future<void> _pickFacePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image == null || !mounted) return;
      final compressed = await ImageCompression.compress(
        File(image.path),
        ImagePresets.face,
      );
      if (!mounted) return;
      setState(() => _photos[_PhotoSlot.selfie] = compressed);
    } catch (_) {
      // Камера недоступна / отказ в правах — молча. Пользователь увидит,
      // что слот пустой, и попробует снова.
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  /// Прокручиваем к секции и моргаем — лёгкий визуальный hint.
  Future<void> _scrollTo(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.15, // секция чуть выше центра
    );
  }

  /// Фокус на первом пустом текстовом поле курьера / магазина.
  /// Возвращает имя поля для toast или null если всё заполнено.
  String? _firstEmptyTextField(AppLocalizations words) {
    if (widget.role == 'courier') {
      if (_c1.text.trim().isEmpty) {
        _f1.requestFocus();
        return words.regFieldName;
      }
      if (_c2.text.trim().isEmpty) {
        _f2.requestFocus();
        return words.regFieldSurname;
      }
      if (_c3.text.trim().isEmpty) {
        _f3.requestFocus();
        return words.regFieldLastname;
      }
    } else {
      if (_c1.text.trim().isEmpty) {
        _f1.requestFocus();
        return words.regFieldOrgName;
      }
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    final words = context.read<LanguageProvider>().words;
    final auth = context.read<AuthProvider>();
    final isCourier = widget.role == 'courier';

    // ── 1. Текстовые поля ──────────────────────────────────────────────────
    final emptyField = _firstEmptyTextField(words);
    if (emptyField != null) {
      _showErrorToast(words.regToastFixTitle, emptyField);
      return;
    }

    // ── 2. Локация ─────────────────────────────────────────────────────────
    if (!_locationSelected) {
      await _scrollTo(_locationKey);
      _showErrorToast(words.regToastFixTitle, words.regErrorLocationRequired);
      return;
    }

    // ── 3. Категория (только shop) ─────────────────────────────────────────
    if (!isCourier && _selectedCategory == null) {
      await _scrollTo(_categoryKey);
      _showErrorToast(words.regToastFixTitle, words.regErrorCategoryRequired);
      return;
    }

    // ── 4. Фото (только курьер: все 4) ─────────────────────────────────────
    if (isCourier && _photos.values.any((f) => f == null)) {
      await _scrollTo(_photosKey);
      _showErrorToast(words.regToastFixTitle, words.regErrorPhotosRequired);
      return;
    }

    if (auth.userId.isEmpty) {
      _showErrorToast(words.regToastFixTitle, words.regErrorUserId);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Загружаем все непустые фото.
      final passportId = _photos[_PhotoSlot.passportMain] != null
          ? await _authRepo.uploadFile(_photos[_PhotoSlot.passportMain]!.path)
          : null;
      final addressId = _photos[_PhotoSlot.passportAddress] != null
          ? await _authRepo
              .uploadFile(_photos[_PhotoSlot.passportAddress]!.path)
          : null;
      final faceId = _photos[_PhotoSlot.passportFace] != null
          ? await _authRepo.uploadFile(_photos[_PhotoSlot.passportFace]!.path)
          : null;
      final selfieId = _photos[_PhotoSlot.selfie] != null
          ? await _authRepo.uploadFile(_photos[_PhotoSlot.selfie]!.path)
          : null;

      // Базовые поля. district/etrap опциональны — у некоторых велаятов их нет.
      final Map<String, dynamic> updateData = {
        'role': widget.role,
        'province': _selectedProvince!.id,
        if (_selectedEtrap != null) 'etrap': _selectedEtrap!.id,
        if (_selectedDistrict != null) 'district': _selectedDistrict!.id,
        'passport_scan': ?passportId,
        'adress_scan': ?addressId,
        'passport_face_scan': ?faceId,
        'selfie_scan': ?selfieId,
      };

      if (widget.role == 'courier') {
        updateData.addAll({
          'name': _c1.text.trim(),
          'surname': _c2.text.trim(),
          'lastname': _c3.text.trim(),
          'status': 'pending',
          'transport_type': _transportType,
        });
      } else {
        // Адрес магазина — лучшее из доступного.
        final shopAddress = _selectedDistrict != null
            ? '${_selectedEtrap!.ru}, ${_selectedDistrict!.ru}'
            : _selectedEtrap != null
                ? _selectedEtrap!.ru
                : _selectedProvince!.ru;

        updateData.addAll({
          'organization_name': _c1.text.trim(),
          'address': shopAddress,
          'name': _c1.text.trim(),
          'status': 'pending',
          if (_selectedCategory != null) 'category': _selectedCategory!.id,
        });

        if (mounted) auth.updateShopAddress(shopAddress);
      }

      final success = await _authRepo.updateProfile(
        userId: auth.userId,
        data: updateData,
      );

      if (!mounted) return;
      if (!success) {
        _showToast(words.regErrorSubmit);
        return;
      }

      // Показываем success-toast и сразу навигируем — НЕ ждём refreshProfile.
      // Раньше ждали `await refreshProfile()` который мог зависнуть до 10 сек
      // (Dio receiveTimeout) → пользователь застрял на форме с loader'ом.
      // Теперь рефреш улетает в фон, новые данные подхватятся когда придут.
      _showToast(words.regSuccessSubmit, isSuccess: true);
      unawaited(_clearDraft()); // A3 — черновик больше не нужен
      // Fire-and-forget refresh — успешно дойдёт до home или нет, нам всё
      // равно. MainShell сам сделает refresh при mount'е.
      auth.refreshProfile().catchError((_) {});

      // pushNamedAndRemoveUntil заменяет ВЕСЬ stack новым `/home`.
      // Это правильно — registration был промежуточной формой, не должна
      // оставаться в истории «назад».
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/home', (r) => false);
    } catch (_) {
      if (mounted) _showToast(words.regErrorSubmit);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Anthropic-стиль: warning toast с заголовком + подзаголовком.
  /// Слева — мягкий amber-индикатор, нет режущей красноты.
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
              child: Icon(
                Icons.priority_high_rounded,
                size: 18,
                color: c.amber,
              ),
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: c.amber.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
    );
  }

  void _showToast(String msg, {bool isSuccess = false}) {
    final c = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.info_outline,
              size: 17,
              color: isSuccess ? c.ink : c.errorMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: AppText.regular(fontSize: 13, color: c.ink)
                    .copyWith(height: 1.4),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? c.emeraldTint : c.errorTint,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSuccess
                ? c.ink.withValues(alpha: 0.25)
                : c.errorMuted.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Transport picker
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildTransportPicker(AppColors c, AppLocalizations words) {
    final options = [
      ('any', words.regTransportAny, Icons.directions_walk_rounded),
      ('car', words.regTransportCar, Icons.directions_car_rounded),
      ('truck', words.regTransportTruck, Icons.local_shipping_rounded),
    ];

    return Column(
      children: options.map((opt) {
        final (value, label, icon) = opt;
        final isSelected = _transportType == value;
        return GestureDetector(
          onTap: () {
            setState(() => _transportType = value);
            _scheduleDraftSave();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? c.emeraldTint : c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? c.ink.withValues(alpha: 0.45)
                    : c.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? c.ink.withValues(alpha: 0.12)
                        : c.surface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? c.ink : c.inkSoft,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.medium(
                      fontSize: 14,
                      color: isSelected ? c.ink : c.inkMuted,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded, size: 18, color: c.ink),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Category picker (магазин)
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildCategoryPicker(bool isRu, AppColors c, AppLocalizations words) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          words.regCatHint,
          style: AppText.regular(fontSize: 13, color: c.inkSoft)
              .copyWith(height: 1.4),
        ),
        const SizedBox(height: 12),
        if (_categories == null)
          _buildLoader(c)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories!.map((cat) {
              final isSelected = _selectedCategory?.id == cat.id;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCategory = cat);
                  _scheduleDraftSave();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.fromLTRB(11, 8, 14, 8),
                  decoration: BoxDecoration(
                    color: isSelected ? c.emeraldTint : c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? c.ink.withValues(alpha: 0.35)
                          : c.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 15,
                        color: isSelected ? c.ink : c.inkMuted,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        cat.label(isRu),
                        style: AppText.medium(
                          fontSize: 13,
                          color: isSelected ? c.ink : c.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Location stepper
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildLocationStepper(
      bool isRu, AppColors c, AppLocalizations words) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(c, words),
        const SizedBox(height: 14),
        _buildBreadcrumb(isRu, c),
        const SizedBox(height: 10),
        if (!_locationSelected && _locationStep > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSearchField(c, words),
          ),
        _locationSelected
            ? _buildLocationDone(isRu, c)
            : _buildCurrentStepList(isRu, c),
      ],
    );
  }

  Widget _buildStepIndicator(AppColors c, AppLocalizations words) {
    final steps = [
      words.regStepProvince,
      words.regStepEtrap,
      words.regStepDistrict,
    ];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: c.borderSoft,
            ),
          );
        }
        final idx = i ~/ 2;
        final isActive = idx <= _locationStep;
        final isDone = idx < _locationStep ||
            (_locationSelected && idx <= _locationStep);
        return Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDone
                    ? c.ink
                    : isActive
                        ? c.emeraldTint
                        : c.surface,
                shape: BoxShape.circle,
                border:
                    Border.all(color: isActive ? c.ink : c.border, width: 1),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : Text(
                      '${idx + 1}',
                      style: AppText.semiBold(
                        fontSize: 11,
                        color: isActive ? c.ink : c.inkSoft,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[idx],
              style: AppText.regular(
                fontSize: 10,
                color: isActive ? c.ink : c.inkSoft,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBreadcrumb(bool isRu, AppColors c) {
    if (_selectedProvince == null) return const SizedBox.shrink();
    final parts = <String>[
      _selectedProvince!.label(isRu),
      if (_selectedEtrap != null) _selectedEtrap!.label(isRu),
      if (_selectedDistrict != null) _selectedDistrict!.label(isRu),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          GestureDetector(
            onTap: () => _resetLocationStep(i),
            child: Text(
              parts[i],
              style: AppText.medium(
                fontSize: 12,
                color: i == parts.length - 1 ? c.ink : c.inkMuted,
              ).copyWith(
                decoration: i == parts.length - 1
                    ? TextDecoration.none
                    : TextDecoration.underline,
                decorationColor: c.inkMuted,
              ),
            ),
          ),
          if (i < parts.length - 1)
            Icon(Icons.chevron_right_rounded, size: 14, color: c.inkSoft),
        ],
      ],
    );
  }

  Widget _buildSearchField(AppColors c, AppLocalizations words) {
    final hint =
        _locationStep == 1 ? words.regSearchEtrap : words.regSearchDistrict;
    return TextField(
      controller: _searchController,
      style: AppText.regular(fontSize: 14, color: c.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.regular(fontSize: 14, color: c.inkSoft),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.inkSoft),
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.ink, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCurrentStepList(bool isRu, AppColors c) {
    switch (_locationStep) {
      case 0:
        return _buildProvinceList(isRu, c);
      case 1:
        return _buildEtrapList(isRu, c);
      case 2:
        return _buildDistrictList(isRu, c);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProvinceList(bool isRu, AppColors c) {
    if (_loadingProvinces) return _buildLoader(c);
    return _buildItemGrid<Province>(
      items: _provinces,
      label: (p) => p.label(isRu),
      onTap: _selectProvince,
      c: c,
    );
  }

  Widget _buildEtrapList(bool isRu, AppColors c) {
    if (_loadingEtraps) return _buildLoader(c);
    final filtered = _etraps.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.label(isRu).toLowerCase().contains(_searchQuery);
    }).toList();
    return _buildItemList<Etrap>(
      items: filtered,
      label: (e) => e.label(isRu),
      onTap: _selectEtrap,
      c: c,
    );
  }

  Widget _buildDistrictList(bool isRu, AppColors c) {
    if (_loadingDistricts) return _buildLoader(c);
    final filtered = _districts.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.label(isRu).toLowerCase().contains(_searchQuery);
    }).toList();
    return _buildItemList<District>(
      items: filtered,
      label: (d) => d.label(isRu),
      onTap: _selectDistrict,
      c: c,
    );
  }

  Widget _buildItemGrid<T>({
    required List<T> items,
    required String Function(T) label,
    required void Function(T) onTap,
    required AppColors c,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border, width: 1),
            ),
            child: Text(
              label(item),
              style: AppText.medium(fontSize: 13, color: c.ink),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemList<T>({
    required List<T> items,
    required String Function(T) label,
    required void Function(T) onTap,
    required AppColors c,
  }) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(
          '—',
          style: AppText.regular(fontSize: 13, color: c.inkSoft),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(items[i]),
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(14))
                    : i == items.length - 1
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(14),
                          )
                        : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label(items[i]),
                          style:
                              AppText.medium(fontSize: 14, color: c.ink),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: c.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i < items.length - 1)
              Divider(height: 0.5, thickness: 0.5, color: c.borderSoft),
          ],
        ],
      ),
    );
  }

  Widget _buildLoader(AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(color: c.ink, strokeWidth: 2),
      ),
    );
  }

  Widget _buildLocationDone(bool isRu, AppColors c) {
    final label = _selectedDistrict?.label(isRu) ??
        _selectedEtrap?.label(isRu) ??
        _selectedProvince?.label(isRu) ??
        '';
    return GestureDetector(
      onTap: () => _resetLocationStep(0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.emeraldTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.ink.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.ink,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.semiBold(fontSize: 15, color: c.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      _selectedProvince?.label(isRu),
                      if (_selectedEtrap != null) _selectedEtrap!.label(isRu),
                    ].whereType<String>().join(' · '),
                    style: AppText.regular(fontSize: 12, color: c.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: c.ink.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Build
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isCourier = widget.role == 'courier';
    final langProvider = context.watch<LanguageProvider>();
    final isRu = langProvider.isRu;
    final words = langProvider.words;
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Semantics(
          button: true,
          label: words.a11yBack,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: c.ink, size: 16),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _RoleChip(isCourier: isCourier, c: c, words: words),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          // Прогресс заполнения формы (A2) — тонкая брендовая полоса.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _completionFraction()),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: c.borderSoft,
              valueColor: AlwaysStoppedAnimation(c.ink),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 110),
                children: [
                  Text(
                    isCourier
                        ? words.regCourierHeroTitle
                        : words.regShopHeroTitle,
                    style: AppText.serif(fontSize: 32, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isCourier
                        ? words.regCourierHeroSubtitle
                        : words.regShopHeroSubtitle,
                    style: AppText.regular(
                            fontSize: 14.5, color: c.inkMuted)
                        .copyWith(height: 1.55, letterSpacing: 0.1),
                  ),
                  const SizedBox(height: 36),
                  _SectionLabel(
                    icon: Icons.person_outline_rounded,
                    label: isCourier
                        ? words.regSectionPersonal
                        : words.regSectionOrganization,
                    c: c,
                  ),
                  const SizedBox(height: 16),
                  if (!isCourier)
                    _InputField(
                      label: words.regFieldOrgName,
                      hint: words.regFieldOrgNameHint,
                      errorHint: words.regFieldOrgNameError,
                      controller: _c1,
                      focusNode: _f1,
                      icon: Icons.business_outlined,
                    ),
                  if (isCourier) ...[
                    _InputField(
                      label: words.regFieldName,
                      hint: words.regFieldNameHint,
                      errorHint: words.regFieldNameError,
                      controller: _c1,
                      focusNode: _f1,
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      nextFocus: _f2,
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      label: words.regFieldSurname,
                      hint: words.regFieldSurnameHint,
                      errorHint: words.regFieldSurnameError,
                      controller: _c2,
                      focusNode: _f2,
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      nextFocus: _f3,
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      label: words.regFieldLastname,
                      hint: words.regFieldLastnameHint,
                      errorHint: words.regFieldLastnameError,
                      controller: _c3,
                      focusNode: _f3,
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                  const SizedBox(height: 32),
                  KeyedSubtree(
                    key: _locationKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(
                          icon: Icons.location_on_outlined,
                          label: words.regSectionLocation,
                          c: c,
                        ),
                        const SizedBox(height: 16),
                        _buildLocationStepper(isRu, c, words),
                      ],
                    ),
                  ),

                  // ── Категория магазина ─────────────────────────────────
                  if (!isCourier) ...[
                    const SizedBox(height: 32),
                    KeyedSubtree(
                      key: _categoryKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            icon: Icons.category_outlined,
                            label: words.regSectionCategory,
                            c: c,
                          ),
                          const SizedBox(height: 12),
                          _buildCategoryPicker(isRu, c, words),
                        ],
                      ),
                    ),
                  ],

                  if (isCourier) ...[
                    const SizedBox(height: 32),
                    KeyedSubtree(
                      key: _transportKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            icon: Icons.local_shipping_outlined,
                            label: words.regSectionTransport,
                            c: c,
                          ),
                          const SizedBox(height: 16),
                          _buildTransportPicker(c, words),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    KeyedSubtree(
                      key: _photosKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            icon: Icons.document_scanner_outlined,
                            label: words.regSectionPassport,
                            c: c,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            words.regPassportHint,
                            style:
                                AppText.regular(fontSize: 13, color: c.inkSoft)
                                    .copyWith(height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          // ── 4 фото в сетке 2×2 ──────────────────────
                          Row(
                            children: [
                              _PhotoBox(
                                label: words.regPhotoMain,
                                file: _photos[_PhotoSlot.passportMain],
                                onTap: () =>
                                    _pickImage(_PhotoSlot.passportMain),
                                uploadedLabel: words.regPhotoUploaded,
                              ),
                              const SizedBox(width: 12),
                              _PhotoBox(
                                label: words.regPhotoAddress,
                                file: _photos[_PhotoSlot.passportAddress],
                                onTap: () =>
                                    _pickImage(_PhotoSlot.passportAddress),
                                uploadedLabel: words.regPhotoUploaded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _PhotoBox(
                                label: words.regPhotoFace,
                                file: _photos[_PhotoSlot.passportFace],
                                onTap: () =>
                                    _pickImage(_PhotoSlot.passportFace),
                                uploadedLabel: words.regPhotoUploaded,
                              ),
                              const SizedBox(width: 12),
                              _PhotoBox(
                                // Слот "Фото лица" — открывает фронтальную
                                // камеру напрямую (без bottom-sheet выбора
                                // источника). Иконка тоже специальная.
                                label: words.regPhotoSelfie,
                                file: _photos[_PhotoSlot.selfie],
                                onTap: _pickFacePhoto,
                                uploadedLabel: words.regPhotoUploaded,
                                emptyIcon:
                                    Icons.face_retouching_natural_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Фиксированная кнопка ─────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c.bg.withValues(alpha: 0),
                      c.bg.withValues(alpha: 0.96),
                      c.bg,
                    ],
                    stops: const [0, 0.35, 1],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                    child: KeyedSubtree(
                      key: _submitKey,
                      child: _SubmitButton(
                        label: words.saveBtn,
                        isLoading: _isLoading,
                        onPressed: _handleSubmit,
                      ),
                    ),
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

// ═════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _RoleChip extends StatelessWidget {
  final bool isCourier;
  final AppColors c;
  final AppLocalizations words;
  const _RoleChip({
    required this.isCourier,
    required this.c,
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.emeraldTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.ink.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCourier
                ? Icons.electric_bike_outlined
                : Icons.shopping_bag_outlined,
            color: c.ink,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isCourier ? words.regRoleCourier : words.regRoleShop,
            style: AppText.semiBold(fontSize: 12.5, color: c.ink)
                .copyWith(letterSpacing: 0.1),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors c;
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 15, color: c.inkMuted),
        const SizedBox(width: 7),
        Text(
          label,
          style: AppText.bold(fontSize: 11, color: c.ink)
              .copyWith(letterSpacing: 1.1),
        ),
      ],
    );
  }
}

class _InputField extends StatefulWidget {
  final String label;
  final String hint;
  final String errorHint;
  final TextEditingController controller;
  final IconData icon;
  final FocusNode? focusNode;

  /// Кнопка действия на клавиатуре (next/done) — A8 цепочка фокуса.
  final TextInputAction? textInputAction;

  /// Куда перевести фокус по «Далее». Если null — закрыть клавиатуру.
  final FocusNode? nextFocus;

  const _InputField({
    required this.label,
    required this.hint,
    required this.errorHint,
    required this.controller,
    required this.icon,
    this.focusNode,
    this.textInputAction,
    this.nextFocus,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  FocusNode get _focus => widget.focusNode ?? _internal;
  late final FocusNode _internal = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _hasFocus = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    // Внутренний node удаляем только если он наш.
    if (widget.focusNode == null) _internal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) {
        final next = widget.nextFocus;
        if (next != null) {
          FocusScope.of(context).requestFocus(next);
        } else {
          FocusScope.of(context).unfocus();
        }
      },
      style: AppText.regular(fontSize: 15, color: c.ink),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        hintStyle: AppText.regular(fontSize: 14, color: c.inkSoft),
        labelStyle: AppText.regular(
          fontSize: 13.5,
          color: _hasFocus ? c.ink : c.inkSoft,
        ),
        prefixIcon: Icon(
          widget.icon,
          size: 18,
          color: _hasFocus ? c.ink : c.inkSoft,
        ),
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.errorMuted, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.errorMuted, width: 1.5),
        ),
        errorStyle: AppText.regular(fontSize: 12, color: c.errorMuted)
            .copyWith(height: 1.4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (v) => (v == null || v.isEmpty) ? widget.errorHint : null,
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  final String uploadedLabel;
  final IconData emptyIcon;
  const _PhotoBox({
    required this.label,
    this.file,
    required this.onTap,
    required this.uploadedLabel,
    this.emptyIcon = Icons.add_a_photo_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 148,
          decoration: BoxDecoration(
            color: file == null ? c.surface : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: file != null
                  ? c.ink.withValues(alpha: 0.5)
                  : c.border,
              width: file != null ? 1.5 : 1,
            ),
            image: file != null
                ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover)
                : null,
          ),
          child: file == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: c.ink.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        emptyIcon,
                        color: c.ink,
                        size: 19,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style:
                          AppText.medium(fontSize: 12.5, color: c.inkMuted)
                              .copyWith(height: 1.35),
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: c.ink, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        uploadedLabel,
                        style: AppText.semiBold(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const _SubmitButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: c.ink.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const _PulsingDots()
              : Text(
                  widget.label,
                  style: AppText.semiBold(fontSize: 16, color: Colors.white)
                      .copyWith(letterSpacing: 0.2),
                ),
        ),
      ),
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 960),
    )..repeat();

    _anims = List.generate(3, (i) {
      final start = i * 0.22;
      final end = (start + 0.55).clamp(0.0, 1.0);
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.3), weight: 1),
      ]).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Opacity(
              opacity: _anims[i].value,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
