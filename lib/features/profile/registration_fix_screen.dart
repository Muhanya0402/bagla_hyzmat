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
import 'package:bagla/features/profile/rejection_codes.dart';
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
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Экран исправления данных после отказа модератора.
///
/// Показывает ТОЛЬКО те поля, которые модератор отметил в
/// `customers.rejection_reasons`. После submit'а:
///   - PATCH с новыми значениями только этих полей
///   - status: 'pending' (профиль уходит на повторную проверку)
///   - rejection_reasons: [] (очищаем — модератор отметит заново если что)
///
/// Логика location/категории/фото повторяет
/// `RegistrationDetailsScreen` — намеренно дублируется чтобы не
/// перегружать большой экран условной отрисовкой. Это узкий частный
/// случай, и так читать намного проще.
class RegistrationFixScreen extends StatefulWidget {
  const RegistrationFixScreen({super.key});

  @override
  State<RegistrationFixScreen> createState() => _RegistrationFixScreenState();
}

enum _Photo { passportMain, passportAddress, passportFace, selfie }

class _RegistrationFixScreenState extends State<RegistrationFixScreen>
    with AppTourMixin<RegistrationFixScreen> {
  final _authRepo = AuthRepository();
  final _picker = ImagePicker();
  bool _isLoading = false;

  // Текстовые поля
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  final _f1 = FocusNode();
  final _f2 = FocusNode();
  final _f3 = FocusNode();

  // Location
  List<Province> _provinces = [];
  List<Etrap> _etraps = [];
  List<District> _districts = [];
  Province? _selectedProvince;
  Etrap? _selectedEtrap;
  District? _selectedDistrict;
  bool _loadingProvinces = false;
  int _locationStep = 0;
  bool _locationSelected = false;

  // Прочее
  String _transportType = 'any';
  ShopCategory? _selectedCategory;
  List<ShopCategory>? _categories;
  final Map<_Photo, File?> _photos = {
    _Photo.passportMain: null,
    _Photo.passportAddress: null,
    _Photo.passportFace: null,
    _Photo.selfie: null,
  };

  late final Set<String> _reasons;
  final _summaryKey = GlobalKey();
  final _submitKey = GlobalKey();
  late final String _role;
  bool get _isCourier => _role == 'courier';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _role = auth.role;
    _reasons = auth.rejectionReasons.toSet();

    // Подгружаем стартовые данные только для полей, которые надо править.
    if (_reasons.contains(RejectionCode.location)) {
      _loadProvinces();
    }
    if (_reasons.contains(RejectionCode.category) && !_isCourier) {
      _loadCategories();
    }
    startTourIfNeeded(
      screenKey: TourKeys.regFix,
      targetsBuilder: _buildTourTargets,
    );
  }

  List<TargetFocus> _buildTourTargets() {
    final words = context.read<LanguageProvider>().words;
    return [
      TourTarget.build(
        id: 'reg_fix_summary',
        key: _summaryKey,
        title: words.tourRegFixSummaryTitle,
        body: words.tourRegFixSummaryBody,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        id: 'reg_fix_submit',
        key: _submitKey,
        title: words.tourRegFixSubmitTitle,
        body: words.tourRegFixSubmitBody,
        align: ContentAlign.top,
        isLast: true,
      ),
    ];
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _f1.dispose();
    _f2.dispose();
    _f3.dispose();
    super.dispose();
  }

  // ── Data loaders ──────────────────────────────────────────────────────────

  Future<void> _loadProvinces() async {
    setState(() => _loadingProvinces = true);
    try {
      final list = await _authRepo.getProvinces();
      if (mounted) setState(() => _provinces = list);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _authRepo.getShopCategories();
      if (mounted) {
        setState(() =>
            _categories = list.isNotEmpty ? list : kLocalShopCategories);
      }
    } catch (_) {
      if (mounted) setState(() => _categories = kLocalShopCategories);
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
      _locationSelected = false;
    });
    try {
      final list = await _authRepo.getEtrapsByProvince(p.id);
      if (!mounted) return;
      setState(() {
        _etraps = list;
        if (list.isEmpty) {
          _locationSelected = true;
          _locationStep = 0;
        }
      });
    } catch (_) {}
  }

  Future<void> _selectEtrap(Etrap e) async {
    setState(() {
      _selectedEtrap = e;
      _selectedDistrict = null;
      _districts = [];
      _locationStep = 2;
      _locationSelected = false;
    });
    try {
      final list = await _authRepo.getDistrictsByEtrap(e.id);
      if (!mounted) return;
      setState(() {
        _districts = list;
        if (list.isEmpty) {
          _locationSelected = true;
          _locationStep = 1;
        }
      });
    } catch (_) {}
  }

  void _selectDistrict(District d) {
    setState(() {
      _selectedDistrict = d;
      _locationSelected = true;
    });
  }

  /// Паспортные слоты — большое разрешение для читаемого текста; selfie — лицо.
  ImagePreset _presetFor(_Photo slot) => switch (slot) {
        _Photo.passportMain ||
        _Photo.passportAddress ||
        _Photo.passportFace =>
          ImagePresets.passportPage,
        _Photo.selfie => ImagePresets.face,
      };

  Future<void> _pickImage(_Photo slot) async {
    // Единый «2-в-1» пикер: камера + инлайн-сетка галереи. Возвращает File.
    final picked = await PhotoPickerSheet.show(context);
    if (picked == null || !mounted) return;
    final compressed =
        await ImageCompression.compress(picked, _presetFor(slot));
    if (!mounted) return;
    setState(() => _photos[slot] = compressed);
  }

  Future<void> _pickFace() async {
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
      setState(() => _photos[_Photo.selfie] = compressed);
    } catch (_) {}
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final words = context.read<LanguageProvider>().words;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final c = AppColors.of(context);

    // Валидация — только активные поля.
    String? checkAndFocus() {
      if (_reasons.contains(RejectionCode.name) && _c1.text.trim().isEmpty) {
        _f1.requestFocus();
        return words.regFieldNameError;
      }
      if (_reasons.contains(RejectionCode.organizationName) &&
          _c1.text.trim().isEmpty) {
        _f1.requestFocus();
        return words.regFieldOrgNameError;
      }
      if (_reasons.contains(RejectionCode.surname) &&
          _c2.text.trim().isEmpty) {
        _f2.requestFocus();
        return words.regFieldSurnameError;
      }
      if (_reasons.contains(RejectionCode.lastname) &&
          _c3.text.trim().isEmpty) {
        _f3.requestFocus();
        return words.regFieldLastnameError;
      }
      if (_reasons.contains(RejectionCode.location) && !_locationSelected) {
        return words.regErrorLocationRequired;
      }
      if (_reasons.contains(RejectionCode.category) &&
          _selectedCategory == null) {
        return words.regErrorCategoryRequired;
      }
      // Фото — должны быть загружены только те, что в reasons.
      final photoChecks = <String, _Photo>{
        RejectionCode.passportMain: _Photo.passportMain,
        RejectionCode.passportAddress: _Photo.passportAddress,
        RejectionCode.passportFace: _Photo.passportFace,
        RejectionCode.selfie: _Photo.selfie,
      };
      for (final entry in photoChecks.entries) {
        if (_reasons.contains(entry.key) && _photos[entry.value] == null) {
          return words.regErrorPhotosRequired;
        }
      }
      return null;
    }

    final err = checkAndFocus();
    if (err != null) {
      _showToast(messenger, c, words.regToastFixTitle, err);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = <String, dynamic>{
        // Сбрасываем reasons + ставим pending — модератор перепроверит.
        'rejection_reasons': <String>[],
        'status': 'pending',
      };

      // Текстовые
      if (_reasons.contains(RejectionCode.name)) {
        data['name'] = _c1.text.trim();
      }
      if (_reasons.contains(RejectionCode.organizationName)) {
        data['organization_name'] = _c1.text.trim();
        data['name'] = _c1.text.trim();
      }
      if (_reasons.contains(RejectionCode.surname)) {
        data['surname'] = _c2.text.trim();
      }
      if (_reasons.contains(RejectionCode.lastname)) {
        data['lastname'] = _c3.text.trim();
      }
      if (_reasons.contains(RejectionCode.transportType)) {
        data['transport_type'] = _transportType;
      }
      if (_reasons.contains(RejectionCode.category) &&
          _selectedCategory != null) {
        data['category'] = _selectedCategory!.id;
      }
      if (_reasons.contains(RejectionCode.location)) {
        data['province'] = _selectedProvince!.id;
        if (_selectedEtrap != null) data['etrap'] = _selectedEtrap!.id;
        if (_selectedDistrict != null) data['district'] = _selectedDistrict!.id;
      }

      // Фото — отдельно загружаем, потом подкладываем id'шки.
      Future<String?> upload(_Photo slot) async {
        final f = _photos[slot];
        if (f == null) return null;
        return _authRepo.uploadFile(f.path);
      }

      if (_reasons.contains(RejectionCode.passportMain)) {
        final id = await upload(_Photo.passportMain);
        if (id != null) data['passport_scan'] = id;
      }
      if (_reasons.contains(RejectionCode.passportAddress)) {
        final id = await upload(_Photo.passportAddress);
        if (id != null) data['adress_scan'] = id;
      }
      if (_reasons.contains(RejectionCode.passportFace)) {
        final id = await upload(_Photo.passportFace);
        if (id != null) data['passport_face_scan'] = id;
      }
      if (_reasons.contains(RejectionCode.selfie)) {
        final id = await upload(_Photo.selfie);
        if (id != null) data['selfie_scan'] = id;
      }

      final ok = await _authRepo.updateProfile(
        userId: auth.userId,
        data: data,
      );
      if (!mounted) return;
      if (!ok) {
        _showToast(messenger, c, words.regToastFixTitle, words.regErrorSubmit);
        return;
      }
      await auth.refreshProfile();
      if (!mounted) return;
      _showSuccessToast(messenger, c, words.regSuccessSubmit);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        _showToast(messenger, c, words.regToastFixTitle, words.regErrorSubmit);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(ScaffoldMessengerState m, AppColors c, String title,
      String subtitle) {
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: c.surface,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.amber.withValues(alpha: 0.35), width: 1),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: AppText.semiBold(fontSize: 14, color: c.ink)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppText.regular(fontSize: 12.5, color: c.inkMuted)),
          ],
        ),
      ),
    );
  }

  void _showSuccessToast(ScaffoldMessengerState m, AppColors c, String text) {
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        backgroundColor: c.emeraldTint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(children: [
          Icon(Icons.check_circle_outline, color: c.ink, size: 17),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: AppText.medium(fontSize: 13, color: c.ink))),
        ]),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lang = context.watch<LanguageProvider>();
    final isRu = lang.isRu;
    final words = lang.words;

    // Если нет ни одной причины — нечего показывать (на всякий случай).
    if (_reasons.isEmpty) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(backgroundColor: c.bg, elevation: 0),
        body: Center(
          child: Text(words.regFixNothingToFix,
              style: AppText.regular(fontSize: 14, color: c.inkSoft)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: c.ink, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.borderSoft),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
              children: [
                Text(words.regFixTitle,
                    style: AppText.serif(fontSize: 28, letterSpacing: -0.5)),
                const SizedBox(height: 10),
                Text(words.regFixSubtitle,
                    style: AppText.regular(fontSize: 13.5, color: c.inkMuted)
                        .copyWith(height: 1.55)),
                const SizedBox(height: 24),

                // Чек-лист затронутых полей
                KeyedSubtree(
                  key: _summaryKey,
                  child: _ReasonsList(reasons: _reasons, c: c, words: words),
                ),
                const SizedBox(height: 24),

                ..._buildFieldsForReasons(c, words, isRu),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.bg.withValues(alpha: 0), c.bg],
                    stops: const [0, 0.4],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                    child: KeyedSubtree(
                      key: _submitKey,
                      child: _SubmitButton(
                        label: words.regFixSubmit,
                        isLoading: _isLoading,
                        onTap: _submit,
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

  /// Рендерит секции в порядке: текст → локация → транспорт → категория → фото.
  List<Widget> _buildFieldsForReasons(
      AppColors c, AppLocalizations words, bool isRu) {
    final widgets = <Widget>[];

    // Текстовые
    if (_reasons.contains(RejectionCode.organizationName) && !_isCourier) {
      widgets.add(_textField(
        c: c,
        controller: _c1,
        focus: _f1,
        label: words.regFieldOrgName,
        hint: words.regFieldOrgNameHint,
        icon: Icons.business_outlined,
      ));
    }
    if (_reasons.contains(RejectionCode.name) && _isCourier) {
      widgets.add(_textField(
        c: c,
        controller: _c1,
        focus: _f1,
        label: words.regFieldName,
        hint: words.regFieldNameHint,
        icon: Icons.badge_outlined,
      ));
    }
    if (_reasons.contains(RejectionCode.surname) && _isCourier) {
      widgets.add(_textField(
        c: c,
        controller: _c2,
        focus: _f2,
        label: words.regFieldSurname,
        hint: words.regFieldSurnameHint,
        icon: Icons.badge_outlined,
      ));
    }
    if (_reasons.contains(RejectionCode.lastname) && _isCourier) {
      widgets.add(_textField(
        c: c,
        controller: _c3,
        focus: _f3,
        label: words.regFieldLastname,
        hint: words.regFieldLastnameHint,
        icon: Icons.badge_outlined,
      ));
    }

    // Локация
    if (_reasons.contains(RejectionCode.location)) {
      widgets.add(_sectionLabel(c, Icons.location_on_outlined, words.regSectionLocation));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildLocation(c, words, isRu));
      widgets.add(const SizedBox(height: 24));
    }

    // Транспорт (только курьер)
    if (_reasons.contains(RejectionCode.transportType) && _isCourier) {
      widgets.add(_sectionLabel(
          c, Icons.local_shipping_outlined, words.regSectionTransport));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildTransport(c, words));
      widgets.add(const SizedBox(height: 24));
    }

    // Категория (только shop)
    if (_reasons.contains(RejectionCode.category) && !_isCourier) {
      widgets.add(_sectionLabel(c, Icons.category_outlined, words.regSectionCategory));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildCategory(c, words, isRu));
      widgets.add(const SizedBox(height: 24));
    }

    // Фото
    final photoReasons = [
      (RejectionCode.passportMain, _Photo.passportMain, words.regPhotoMain),
      (RejectionCode.passportAddress, _Photo.passportAddress, words.regPhotoAddress),
      (RejectionCode.passportFace, _Photo.passportFace, words.regPhotoFace),
      (RejectionCode.selfie, _Photo.selfie, words.regPhotoSelfie),
    ].where((t) => _reasons.contains(t.$1)).toList();

    if (photoReasons.isNotEmpty && _isCourier) {
      widgets.add(_sectionLabel(c, Icons.document_scanner_outlined, words.regSectionPassport));
      widgets.add(const SizedBox(height: 12));
      // Размещаем парами 2×N grid
      for (var i = 0; i < photoReasons.length; i += 2) {
        final a = photoReasons[i];
        final b = i + 1 < photoReasons.length ? photoReasons[i + 1] : null;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Expanded(child: _photoBox(c, a, words)),
            const SizedBox(width: 12),
            Expanded(child: b != null ? _photoBox(c, b, words) : const SizedBox()),
          ]),
        ));
      }
    }

    return widgets;
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  Widget _sectionLabel(AppColors c, IconData icon, String label) => Row(
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
          Text(label,
              style: AppText.bold(fontSize: 11, color: c.ink)
                  .copyWith(letterSpacing: 1.1)),
        ],
      );

  Widget _textField({
    required AppColors c,
    required TextEditingController controller,
    required FocusNode focus,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        focusNode: focus,
        style: AppText.regular(fontSize: 15, color: c.ink),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: AppText.regular(fontSize: 14, color: c.inkSoft),
          labelStyle: AppText.regular(fontSize: 13.5, color: c.inkSoft),
          prefixIcon: Icon(icon, size: 18, color: c.inkSoft),
          filled: true,
          fillColor: c.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.ink, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildLocation(AppColors c, AppLocalizations words, bool isRu) {
    if (_loadingProvinces) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(color: c.ink, strokeWidth: 2),
        ),
      );
    }
    if (_locationSelected) {
      final label = _selectedDistrict?.label(isRu) ??
          _selectedEtrap?.label(isRu) ??
          _selectedProvince?.label(isRu) ??
          '';
      return GestureDetector(
        onTap: () => setState(() {
          _locationSelected = false;
          _locationStep = 0;
          _selectedProvince = null;
          _selectedEtrap = null;
          _selectedDistrict = null;
        }),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.emeraldTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.ink.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_rounded, color: c.ink, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: AppText.semiBold(fontSize: 14, color: c.ink)),
              ),
              Icon(Icons.edit_outlined, size: 15, color: c.inkSoft),
            ],
          ),
        ),
      );
    }
    // Выбор по шагам — только province → etrap → district.
    final items = switch (_locationStep) {
      0 => _provinces
          .map((p) => (p.id, p.label(isRu), () => _selectProvince(p)))
          .toList(),
      1 => _etraps
          .map((e) => (e.id, e.label(isRu), () => _selectEtrap(e)))
          .toList(),
      _ => _districts
          .map((d) => (d.id, d.label(isRu), () => _selectDistrict(d)))
          .toList(),
    };
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Text('—',
            style: AppText.regular(fontSize: 13, color: c.inkSoft)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            InkWell(
              onTap: items[i].$3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(children: [
                  Expanded(
                    child: Text(items[i].$2,
                        style: AppText.medium(fontSize: 14, color: c.ink)),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: c.inkSoft),
                ]),
              ),
            ),
            if (i < items.length - 1)
              Divider(height: 0.5, thickness: 0.5, color: c.borderSoft),
          ],
        ],
      ),
    );
  }

  Widget _buildTransport(AppColors c, AppLocalizations words) {
    final opts = [
      ('any', words.regTransportAny, Icons.directions_walk_rounded),
      ('car', words.regTransportCar, Icons.directions_car_rounded),
      ('truck', words.regTransportTruck, Icons.local_shipping_rounded),
    ];
    return Column(
      children: opts.map((o) {
        final isSel = _transportType == o.$1;
        return GestureDetector(
          onTap: () => setState(() => _transportType = o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSel ? c.emeraldTint : c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isSel ? c.ink.withValues(alpha: 0.45) : c.border,
                  width: isSel ? 1.5 : 1),
            ),
            child: Row(children: [
              Icon(o.$3, size: 18, color: isSel ? c.ink : c.inkSoft),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(o.$2,
                      style: AppText.medium(
                          fontSize: 14, color: isSel ? c.ink : c.inkMuted))),
              if (isSel) Icon(Icons.check_rounded, size: 18, color: c.ink),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategory(AppColors c, AppLocalizations words, bool isRu) {
    if (_categories == null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(color: c.ink, strokeWidth: 2)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories!.map((cat) {
        final isSel = _selectedCategory?.id == cat.id;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 8, 14, 8),
            decoration: BoxDecoration(
              color: isSel ? c.emeraldTint : c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSel ? c.ink.withValues(alpha: 0.35) : c.border,
                  width: isSel ? 1.5 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(cat.icon,
                  size: 15, color: isSel ? c.ink : c.inkMuted),
              const SizedBox(width: 7),
              Text(cat.label(isRu),
                  style: AppText.medium(
                      fontSize: 13, color: isSel ? c.ink : c.inkMuted)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _photoBox(AppColors c,
      (String, _Photo, String) tuple, AppLocalizations words) {
    final slot = tuple.$2;
    final label = tuple.$3;
    final file = _photos[slot];
    return GestureDetector(
      onTap: () =>
          slot == _Photo.selfie ? _pickFace() : _pickImage(slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 148,
        decoration: BoxDecoration(
          color: file == null ? c.surface : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: file != null ? c.ink.withValues(alpha: 0.5) : c.border,
              width: file != null ? 1.5 : 1),
          image: file != null
              ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
              : null,
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      slot == _Photo.selfie
                          ? Icons.face_retouching_natural_outlined
                          : Icons.add_a_photo_outlined,
                      color: c.ink,
                      size: 22),
                  const SizedBox(height: 10),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: AppText.medium(fontSize: 12.5, color: c.inkMuted)
                          .copyWith(height: 1.35)),
                ],
              )
            : Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(words.regPhotoUploaded,
                        style: AppText.semiBold(
                            fontSize: 11, color: Colors.white)),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ReasonsList extends StatelessWidget {
  final Set<String> reasons;
  final AppColors c;
  final AppLocalizations words;
  const _ReasonsList(
      {required this.reasons, required this.c, required this.words});

  String _label(String code) {
    switch (code) {
      case RejectionCode.name:
        return words.rejectionReasonName;
      case RejectionCode.surname:
        return words.rejectionReasonSurname;
      case RejectionCode.lastname:
        return words.rejectionReasonLastname;
      case RejectionCode.location:
        return words.rejectionReasonLocation;
      case RejectionCode.transportType:
        return words.rejectionReasonTransport;
      case RejectionCode.passportMain:
        return words.rejectionReasonPassportMain;
      case RejectionCode.passportAddress:
        return words.rejectionReasonPassportAddress;
      case RejectionCode.passportFace:
        return words.rejectionReasonPassportFace;
      case RejectionCode.selfie:
        return words.rejectionReasonSelfie;
      case RejectionCode.organizationName:
        return words.rejectionReasonOrgName;
      case RejectionCode.category:
        return words.rejectionReasonCategory;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.errorTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.errorMuted.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.priority_high_rounded, size: 16, color: c.errorMuted),
            const SizedBox(width: 8),
            Text(words.accountRejected,
                style: AppText.semiBold(fontSize: 13, color: c.errorMuted)),
          ]),
          const SizedBox(height: 10),
          ...reasons.map((code) => Padding(
                padding: const EdgeInsets.only(top: 4, left: 24),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.errorMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_label(code),
                          style: AppText.regular(
                              fontSize: 12.5, color: c.errorMuted)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  const _SubmitButton(
      {required this.label, required this.isLoading, required this.onTap});

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
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(widget.label,
                  style:
                      AppText.semiBold(fontSize: 15, color: Colors.white)),
        ),
      ),
    );
  }
}
