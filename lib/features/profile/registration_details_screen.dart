import 'dart:io';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/language_provider.dart';
import '../../models/district.dart';
import '../../models/province.dart';
import '../../models/etrap.dart';
import '../auth/auth_repository.dart';

class RegistrationDetailsScreen extends StatefulWidget {
  final String role;
  const RegistrationDetailsScreen({super.key, required this.role});

  @override
  State<RegistrationDetailsScreen> createState() =>
      _RegistrationDetailsScreenState();
}

class _RegistrationDetailsScreenState extends State<RegistrationDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authRepo = AuthRepository();
  final _picker = ImagePicker();

  bool _isLoading = false;

  File? _passportFile;
  File? _addressFile;

  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();

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

  static const _transportOptions = [
    ('any', 'Пешком / Любой', Icons.directions_walk_rounded),
    ('car', 'Легковой авто', Icons.directions_car_rounded),
    ('truck', 'Грузовой авто', Icons.local_shipping_rounded),
  ];

  int _locationStep = 0;

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadProvinces() async {
    setState(() => _loadingProvinces = true);
    try {
      final list = await _authRepo.getProvinces();
      setState(() => _provinces = list);
    } catch (e) {
      _showToast('Ошибка загрузки велаятов: $e');
    } finally {
      setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _selectProvince(Province p) async {
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
      _showToast('Ошибка загрузки этрапов: $e');
    } finally {
      setState(() => _loadingEtraps = false);
    }
  }

  Future<void> _selectEtrap(Etrap e) async {
    setState(() {
      _selectedEtrap = e;
      _selectedDistrict = null;
      _districts = [];
      _locationStep = 2;
      _searchQuery = '';
      _loadingDistricts = true;
      _locationSelected = false;
    });
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
      _showToast('Ошибка загрузки районов: $e');
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
  }

  void _resetLocationStep(int step) {
    setState(() {
      _locationStep = step;
      _searchQuery = '';
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

  Future<void> _pickImage(bool isPassport) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) {
      setState(() {
        if (isPassport) {
          _passportFile = File(image.path);
        } else {
          _addressFile = File(image.path);
        }
      });
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_locationSelected) {
      _showToast('Пожалуйста, выберите район');
      return;
    }

    if (widget.role == 'courier' &&
        (_passportFile == null || _addressFile == null)) {
      _showToast('Пожалуйста, загрузите оба фото паспорта');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) throw 'ID пользователя не найден';

      String? passportId;
      String? addressId;
      if (_passportFile != null) {
        passportId = await _authRepo.uploadFile(_passportFile!.path);
      }
      if (_addressFile != null) {
        addressId = await _authRepo.uploadFile(_addressFile!.path);
      }

      Map<String, dynamic> updateData = {
        'role': widget.role,
        'passport_scan': passportId,
        'adress_scan': addressId,
        'district': _selectedDistrict!.id,
        'etrap': _selectedEtrap!.id,
        'province': _selectedProvince!.id,
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
        final shopAddress = _selectedDistrict != null
            ? "${_selectedEtrap!.ru}, ${_selectedDistrict!.ru}"
            : _selectedEtrap != null
            ? _selectedEtrap!.ru
            : _selectedProvince!.ru;

        updateData.addAll({
          'organization_name': _c1.text.trim(),
          'address': shopAddress,
          'name': _c1.text.trim(),
          'status': 'pending',
          'district': _selectedDistrict?.id,
          'etrap': _selectedEtrap?.id,
          'province': _selectedProvince!.id,
        });

        if (mounted) {
          context.read<AuthProvider>().updateShopAddress(shopAddress);
        }
      }

      final success = await _authRepo.updateProfile(
        userId: userId,
        data: updateData,
      );

      if (!success) {
        _showToast(
          'Не удалось сохранить данные. Попробуйте ещё раз через мгновение.',
        );
        return;
      }

      if (!mounted) return;
      if (widget.role != 'courier') {
        context.read<AuthProvider>().updateShopAddress(_c2.text.trim());
      }
      try {
        await context.read<AuthProvider>().refreshProfile();
      } catch (_) {}
      if (!mounted) return;
      _showToast('Данные отправлены. Ожидайте подтверждения', isSuccess: true);
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/home', (r) => false);
    } catch (e) {
      _showToast(
        'Не удалось сохранить данные. Попробуйте ещё раз через мгновение.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.info_outline,
              size: 17,
              color: isSuccess
                  ? AppColors.of(context).ink
                  : AppColors.of(context).errorMuted,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: AppText.regular(
                  fontSize: 13,
                  color: isSuccess
                      ? AppColors.of(context).ink
                      : AppColors.of(context).ink,
                ).copyWith(height: 1.4),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? AppColors.of(context).emeraldTint
            : AppColors.of(context).errorTint,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSuccess
                ? AppColors.of(context).ink.withValues(alpha: 0.25)
                : AppColors.of(context).errorMuted.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
    );
  }

  // ── Transport picker ───────────────────────────────────────────────────────

  Widget _buildTransportPicker() {
    return Column(
      children: _transportOptions.map((opt) {
        final (value, label, icon) = opt;
        final isSelected = _transportType == value;
        return GestureDetector(
          onTap: () => setState(() => _transportType = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.of(context).emeraldTint
                  : AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.of(context).ink.withValues(alpha: 0.45)
                    : AppColors.of(context).border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.of(context).ink.withValues(alpha: 0.12)
                        : AppColors.of(context).surface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? AppColors.of(context).ink
                        : AppColors.of(context).inkSoft,
                  ),
                ),
                SizedBox(width: 14),
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
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.of(context).ink
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.of(context).ink
                          : AppColors.of(context).border,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check_rounded, color: Colors.white, size: 13)
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

  Widget _buildLocationStepper(bool isRu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(),
        SizedBox(height: 14),
        if (_selectedProvince != null ||
            _selectedEtrap != null ||
            _selectedDistrict != null)
          _buildBreadcrumb(isRu),
        if (_locationStep > 0 && !_locationSelected) ...[
          SizedBox(height: 10),
          _buildSearchField(),
        ],
        SizedBox(height: 10),
        _locationSelected
            ? _buildLocationDone(isRu)
            : _buildCurrentStepList(isRu),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Велаят', 'Этрап', 'Район'];
    return Row(
      children: List.generate(3, (i) {
        final isDone =
            i < _locationStep || (i == 2 && _selectedDistrict != null);
        final isActive = i == _locationStep && !_locationSelected;
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
                      SizedBox(height: 6),
                      Text(
                        steps[i],
                        style: AppText.medium(
                          fontSize: 10.5,
                          color: isDone || isActive
                              ? AppColors.of(context).ink
                              : AppColors.of(context).inkSoft,
                        ).copyWith(letterSpacing: 0.2),
                      ),
                    ],
                  ),
                ),
                if (i < 2) SizedBox(width: 8),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBreadcrumb(bool isRu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (_selectedProvince != null)
            _Chip(
              label: _selectedProvince!.label(isRu),
              onTap: () => _resetLocationStep(0),
              isSelected: _selectedEtrap == null && _locationSelected,
            ),
          if (_selectedEtrap != null)
            _Chip(
              label: _selectedEtrap!.label(isRu),
              onTap: () => _resetLocationStep(1),
              isSelected: _selectedDistrict == null && _locationSelected,
            ),
          if (_selectedDistrict != null)
            _Chip(
              label: _selectedDistrict!.label(isRu),
              isSelected: true,
              onTap: () => _resetLocationStep(1),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final hints = ['', 'Поиск этрапа...', 'Поиск района...'];
    return TextField(
      controller: _searchController,
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
            ? GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.of(context).ink,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.of(context).surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.of(context).border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.of(context).ink, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildCurrentStepList(bool isRu) {
    if (_locationStep == 0) return _buildProvinceList(isRu);
    if (_locationStep == 1) return _buildEtrapList(isRu);
    return _buildDistrictList(isRu);
  }

  Widget _buildProvinceList(bool isRu) {
    if (_loadingProvinces) return _buildLoader();
    return _buildItemGrid(
      items: _provinces,
      labelFn: (p) => p.label(isRu),
      onTap: _selectProvince,
    );
  }

  Widget _buildEtrapList(bool isRu) {
    if (_loadingEtraps) return _buildLoader();
    final filtered = _etraps
        .where((e) => e.label(isRu).toLowerCase().contains(_searchQuery))
        .toList();
    return _buildItemList(
      items: filtered,
      labelFn: (e) => e.label(isRu),
      onTap: _selectEtrap,
    );
  }

  Widget _buildDistrictList(bool isRu) {
    if (_loadingDistricts) return _buildLoader();
    final filtered = _districts
        .where((d) => d.label(isRu).toLowerCase().contains(_searchQuery))
        .toList();
    return _buildItemList(
      items: filtered,
      labelFn: (d) => d.label(isRu),
      onTap: _selectDistrict,
    );
  }

  Widget _buildItemGrid<T>({
    required List<T> items,
    required String Function(T) labelFn,
    required void Function(T) onTap,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.of(context).border),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              labelFn(item),
              textAlign: TextAlign.center,
              style: AppText.medium(
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

  Widget _buildItemList<T>({
    required List<T> items,
    required String Function(T) labelFn,
    required void Function(T) onTap,
  }) {
    if (items.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: Text(
          _searchQuery.isEmpty ? 'Нет данных' : 'Ничего не найдено',
          style: AppText.regular(
            fontSize: 14,
            color: AppColors.of(context).inkSoft,
          ),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.of(context).borderSoft,
          ),
          itemBuilder: (_, i) {
            final item = items[i];
            return InkWell(
              onTap: () => onTap(item),
              splashColor: AppColors.of(context).ink.withValues(alpha: 0.05),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
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
                      size: 13,
                      color: AppColors.of(context).border,
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

  Widget _buildLoader() {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          color: AppColors.of(context).ink,
          strokeWidth: 1.5,
        ),
      ),
    );
  }

  Widget _buildLocationDone(bool isRu) {
    return GestureDetector(
      onTap: () => _resetLocationStep(0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.of(context).emeraldTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.of(context).ink.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.of(context).ink,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.check_rounded, color: Colors.white, size: 18),
            ),
            SizedBox(width: 14),
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
                      fontSize: 15,
                      color: AppColors.of(context).ink,
                    ),
                  ),
                  SizedBox(height: 2),
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
              size: 16,
              color: AppColors.of(context).ink.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isCourier = widget.role == 'courier';
    final langProvider = context.watch<LanguageProvider>();
    final isRu = langProvider.isRu;
    final words = langProvider.words;

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.of(context).ink,
              size: 16,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.of(context).borderSoft),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 52),
          children: [
            // ── Роль-чип + заголовок ───────────────────────────────────
            _RoleChip(isCourier: isCourier),
            SizedBox(height: 18),
            Text(
              isCourier ? 'Расскажите о себе' : 'Ваша организация',
              style: AppText.serif(fontSize: 32, letterSpacing: -0.5),
            ),
            SizedBox(height: 10),
            Text(
              isCourier
                  ? 'Эти данные необходимы для оформления документов '
                        'и связи с магазинами-партнёрами.'
                  : 'Эти данные помогут курьерам найти вас '
                        'и правильно оформить доставку.',
              style: AppText.regular(
                fontSize: 14.5,
                color: AppColors.of(context).inkMuted,
              ).copyWith(height: 1.55, letterSpacing: 0.1),
            ),

            SizedBox(height: 36),

            // ── Личные данные / Организация ────────────────────────────
            _SectionLabel(
              icon: Icons.person_outline_rounded,
              label: isCourier ? 'ЛИЧНЫЕ ДАННЫЕ' : 'ОБ ОРГАНИЗАЦИИ',
            ),
            SizedBox(height: 16),

            if (!isCourier) ...[
              _InputField(
                label: 'Наименование организации',
                hint: 'Например: ИП «Хасанов»',
                errorHint:
                    'Пожалуйста, укажите название, чтобы курьеры могли найти вас.',
                controller: _c1,
                icon: Icons.business_outlined,
              ),
            ],
            if (isCourier) ...[
              _InputField(
                label: 'Имя',
                hint: 'Ваше имя',
                errorHint: 'Пожалуйста, укажите ваше имя.',
                controller: _c1,
                icon: Icons.badge_outlined,
              ),
              SizedBox(height: 12),
              _InputField(
                label: 'Фамилия',
                hint: 'Ваша фамилия',
                errorHint: 'Пожалуйста, укажите фамилию.',
                controller: _c2,
                icon: Icons.badge_outlined,
              ),
              SizedBox(height: 12),
              _InputField(
                label: 'Отчество',
                hint: 'Ваше отчество',
                errorHint: 'Пожалуйста, укажите отчество.',
                controller: _c3,
                icon: Icons.badge_outlined,
              ),
            ],

            SizedBox(height: 32),

            // ── Местоположение ─────────────────────────────────────────
            _SectionLabel(
              icon: Icons.location_on_outlined,
              label: 'МЕСТОПОЛОЖЕНИЕ',
            ),
            SizedBox(height: 16),
            _buildLocationStepper(isRu),

            if (isCourier) ...[
              SizedBox(height: 32),

              // ── Вид транспорта ─────────────────────────────────────
              _SectionLabel(
                icon: Icons.local_shipping_outlined,
                label: 'ВИД ТРАНСПОРТА',
              ),
              SizedBox(height: 16),
              _buildTransportPicker(),

              SizedBox(height: 32),

              // ── Фото паспорта ──────────────────────────────────────
              _SectionLabel(
                icon: Icons.document_scanner_outlined,
                label: 'ФОТО ПАСПОРТА',
              ),
              SizedBox(height: 8),
              Text(
                'Главная страница и страница с пропиской.',
                style: AppText.regular(
                  fontSize: 13,
                  color: AppColors.of(context).inkSoft,
                ).copyWith(height: 1.4),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  _PhotoBox(
                    label: 'Главная\nстраница',
                    file: _passportFile,
                    onTap: () => _pickImage(true),
                  ),
                  SizedBox(width: 12),
                  _PhotoBox(
                    label: 'Прописка',
                    file: _addressFile,
                    onTap: () => _pickImage(false),
                  ),
                ],
              ),
            ],

            SizedBox(height: 44),

            // ── Кнопка ─────────────────────────────────────────────────
            _SubmitButton(
              label: words.saveBtn,
              isLoading: _isLoading,
              onPressed: _handleSubmit,
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
  const _RoleChip({required this.isCourier});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.of(context).emeraldTint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.of(context).ink.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCourier
                    ? Icons.electric_bike_outlined
                    : Icons.shopping_bag_outlined,
                color: AppColors.of(context).ink,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                isCourier ? 'Курьер' : 'Магазин',
                style: AppText.semiBold(
                  fontSize: 12.5,
                  color: AppColors.of(context).ink,
                ).copyWith(letterSpacing: 0.1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.of(context).ink,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 10),
        Icon(icon, size: 15, color: AppColors.of(context).inkMuted),
        SizedBox(width: 7),
        Text(
          label,
          style: AppText.bold(
            fontSize: 11,
            color: AppColors.of(context).ink,
          ).copyWith(letterSpacing: 1.1),
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

  const _InputField({
    required this.label,
    required this.hint,
    required this.errorHint,
    required this.controller,
    required this.icon,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  final _focus = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _hasFocus = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      style: AppText.regular(fontSize: 15, color: AppColors.of(context).ink),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        hintStyle: AppText.regular(
          fontSize: 14,
          color: AppColors.of(context).inkSoft,
        ),
        labelStyle: AppText.regular(
          fontSize: 13.5,
          color: _hasFocus
              ? AppColors.of(context).ink
              : AppColors.of(context).inkSoft,
        ),
        prefixIcon: Icon(
          widget.icon,
          size: 18,
          color: _hasFocus
              ? AppColors.of(context).ink
              : AppColors.of(context).inkSoft,
        ),
        filled: true,
        fillColor: AppColors.of(context).surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.of(context).border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.of(context).ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.of(context).errorMuted,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.of(context).errorMuted,
            width: 1.5,
          ),
        ),
        errorStyle: AppText.regular(
          fontSize: 12,
          color: AppColors.of(context).errorMuted,
        ).copyWith(height: 1.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? widget.errorHint : null,
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;

  const _PhotoBox({required this.label, this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 148,
          decoration: BoxDecoration(
            color: file == null ? AppColors.of(context).surface : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: file != null
                  ? AppColors.of(context).ink.withValues(alpha: 0.5)
                  : AppColors.of(context).border,
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
                        color: AppColors.of(
                          context,
                        ).ink.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.of(context).ink,
                        size: 19,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppText.medium(
                        fontSize: 12.5,
                        color: AppColors.of(context).inkMuted,
                      ).copyWith(height: 1.35),
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
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.of(context).ink,
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Загружено',
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

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _Chip({
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
              ? AppColors.of(context).emeraldTint
              : AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.of(context).ink.withValues(alpha: 0.4)
                : AppColors.of(context).border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.medium(
                fontSize: 12,
                color: isSelected
                    ? AppColors.of(context).ink
                    : AppColors.of(context).inkMuted,
              ),
            ),
            if (!isSelected) ...[
              SizedBox(width: 4),
              Icon(
                Icons.close_rounded,
                size: 12,
                color: AppColors.of(context).inkSoft,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Submit button with press-scale + pulsing loader ────────────────────────

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
            color: AppColors.of(context).ink,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.of(context).ink.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.of(context).ink.withValues(alpha: 0.08),
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
                  style: AppText.semiBold(
                    fontSize: 16,
                    color: Colors.white,
                  ).copyWith(letterSpacing: 0.2),
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
                decoration: BoxDecoration(
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
