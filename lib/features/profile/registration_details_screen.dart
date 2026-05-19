import 'dart:io';
import 'package:bagla/core/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
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

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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
      _showSnack('Ошибка загрузки велаятов: $e');
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
      _locationSelected = false; // сбрасываем
    });
    try {
      final list = await _authRepo.getEtrapsByProvince(p.id);
      setState(() {
        _etraps = list;
        // Если этрапов нет — велаят уже достаточно
        if (list.isEmpty) {
          _locationSelected = true;
          _locationStep = 0;
        }
      });
    } catch (e) {
      _showSnack('Ошибка загрузки этрапов: $e');
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
        // Если районов нет — этрап уже достаточно
        if (list.isEmpty) {
          _locationSelected = true;
          _locationStep = 1;
        }
      });
    } catch (e) {
      _showSnack('Ошибка загрузки районов: $e');
    } finally {
      setState(() => _loadingDistricts = false);
    }
  }

  void _selectDistrict(District d) {
    setState(() {
      _selectedDistrict = d;
      _searchQuery = '';
      _locationSelected = true; // район выбран
    });
  }

  void _resetLocationStep(int step) {
    setState(() {
      _locationStep = step;
      _searchQuery = '';
      _locationSelected = false; // сбрасываем при возврате
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

  Widget _buildTransportPicker() {
    return Column(
      children: _transportOptions.map((opt) {
        final (value, label, icon) = opt;
        final isSelected = _transportType == value;
        return GestureDetector(
          onTap: () => setState(() => _transportType = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: isSelected
                  ? brandGreen.withValues(alpha: 0.06)
                  : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? brandGreen.withValues(alpha: 0.4)
                    : const Color(0xFFEEF0F3),
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
                        ? brandGreen.withValues(alpha: 0.12)
                        : const Color(0xFFEEF0F3),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? brandGreen : const Color(0xFF9AA3AF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.medium(
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF0F1117)
                          : const Color(0xFF9AA3AF),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected ? brandGradient : null,
                    color: isSelected ? null : Colors.transparent,
                    border: isSelected
                        ? null
                        : Border.all(
                            color: const Color(0xFFDDE1E7),
                            width: 1.5,
                          ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 13,
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
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
      _showSnack('Пожалуйста, выберите район');
      return;
    }

    if (widget.role == 'courier' &&
        (_passportFile == null || _addressFile == null)) {
      _showSnack('Пожалуйста, загрузите оба фото паспорта');
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
        // Формируем адрес из выбранной локации
        final shopAddress = _selectedDistrict != null
            ? "${_selectedEtrap!.ru}, ${_selectedDistrict!.ru}"
            : _selectedEtrap != null
            ? _selectedEtrap!.ru
            : _selectedProvince!.ru;

        updateData.addAll({
          'organization_name': _c1.text.trim(),
          'address': shopAddress, // ← адрес из локации
          'name': _c1.text.trim(),
          'status': 'pending',
          'district': _selectedDistrict?.id,
          'etrap': _selectedEtrap?.id,
          'province': _selectedProvince!.id,
        });

        // Обновляем адрес в провайдере
        if (mounted) {
          context.read<AuthProvider>().updateShopAddress(shopAddress);
        }
      }

      final success = await _authRepo.updateProfile(
        userId: userId,
        data: updateData,
      );

      if (success) {
        if (!mounted) return;
        if (widget.role != 'courier') {
          context.read<AuthProvider>().updateShopAddress(_c2.text.trim());
        }
        await context.read<AuthProvider>().refreshProfile();
        _showSnack(
          'Данные отправлены. Ожидайте подтверждения',
          color: brandGreen,
        );
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    } catch (e) {
      _showSnack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: AppText.regular(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: color ?? brandRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isCourier = widget.role == 'courier';
    final langProvider = context.watch<LanguageProvider>();
    final isRu = langProvider.isRu;
    final words = langProvider.words;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brandGreen.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: brandGreen,
              size: 18,
            ),
          ),
        ),
        title: Text(
          isCourier ? words.courierFormTitle : words.profileDetailsTitle,
          style: AppText.semiBold(fontSize: 17, color: const Color(0xFF0F1117)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // ── Роль-бейдж ─────────────────────────────────────────────
            _RoleBadge(isCourier: isCourier),
            const SizedBox(height: 28),

            // ── Секция: Личные данные ───────────────────────────────────
            _SectionLabel(
              icon: Icons.person_outline_rounded,
              label: isCourier ? 'ЛИЧНЫЕ ДАННЫЕ' : 'ОБ ОРГАНИЗАЦИИ',
            ),
            const SizedBox(height: 14),

            if (!isCourier) ...[
              _BrandInputField(
                label: 'Наименование организации',
                controller: _c1,
                icon: Icons.business_outlined,
              ),
            ],
            if (isCourier) ...[
              _BrandInputField(
                label: 'Имя',
                controller: _c1,
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),
              _BrandInputField(
                label: 'Фамилия',
                controller: _c2,
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),
              _BrandInputField(
                label: 'Отчество',
                controller: _c3,
                icon: Icons.badge_outlined,
              ),
            ],

            const SizedBox(height: 28),

            // ── Секция: Местоположение ──────────────────────────────────
            _SectionLabel(
              icon: Icons.location_on_outlined,
              label: 'МЕСТОПОЛОЖЕНИЕ',
            ),
            const SizedBox(height: 14),
            _buildLocationStepper(isRu),

            // ── Секция: Фото паспорта ───────────────────────────────────
            if (isCourier) ...[
              const SizedBox(height: 28), // ← ДОБАВИТЬ
              _SectionLabel(
                // ← ДОБАВИТЬ
                icon: Icons.local_shipping_outlined,
                label: 'ВИД ТРАНСПОРТА',
              ),
              const SizedBox(height: 14), // ← ДОБАВИТЬ
              _buildTransportPicker(),
              const SizedBox(height: 28),
              _SectionLabel(
                icon: Icons.document_scanner_outlined,
                label: 'ФОТО ПАСПОРТА',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _BrandPhotoBox(
                    text: 'Главная',
                    subtitle: 'страница',
                    file: _passportFile,
                    onTap: () => _pickImage(true),
                  ),
                  const SizedBox(width: 12),
                  _BrandPhotoBox(
                    text: 'Прописка',
                    subtitle: 'страница',
                    file: _addressFile,
                    onTap: () => _pickImage(false),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 36),

            // ── Кнопка ─────────────────────────────────────────────────
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: brandGreen,
                      strokeWidth: 2,
                    ),
                  )
                : GestureDetector(
                    onTap: _handleSubmit,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: brandGreen.withValues(alpha: 0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        words.saveBtn.toUpperCase(),
                        style: AppText.bold(
                          fontSize: 14,
                          color: Colors.white,
                        ).copyWith(letterSpacing: 0.5),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ── Location stepper ───────────────────────────────────────────────────────

  Widget _buildLocationStepper(bool isRu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(),
        const SizedBox(height: 14),

        if (_selectedProvince != null ||
            _selectedEtrap != null ||
            _selectedDistrict != null)
          _buildBreadcrumb(isRu),

        if (_locationStep > 0 && !_locationSelected) ...[
          const SizedBox(height: 10),
          _buildSearchField(),
        ],
        const SizedBox(height: 10),

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
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: (isDone || isActive) ? brandGradient : null,
                          color: (isDone || isActive)
                              ? null
                              : const Color(0xFFEEF0F3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[i],
                        style: AppText.medium(
                          fontSize: 10,
                          color: isDone || isActive
                              ? const Color(0xFF0F1117)
                              : const Color(0xFF9AA3AF),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (_selectedProvince != null)
            _BreadcrumbChip(
              label: _selectedProvince!.label(isRu),
              onTap: () => _resetLocationStep(0),
            ),
          if (_selectedEtrap != null)
            _BreadcrumbChip(
              label: _selectedEtrap!.label(isRu),
              onTap: () => _resetLocationStep(1),
            ),
          if (_selectedDistrict != null)
            _BreadcrumbChip(
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
      style: AppText.regular(fontSize: 14, color: const Color(0xFF0F1117)),
      decoration: InputDecoration(
        hintText: hints[_locationStep],
        hintStyle: AppText.regular(
          fontSize: 14,
          color: const Color(0xFF9AA3AF),
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF9AA3AF),
          size: 20,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
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
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              labelFn(item),
              textAlign: TextAlign.center,
              style: AppText.semiBold(
                fontSize: 13,
                color: const Color(0xFF0F1117),
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
          style: AppText.regular(fontSize: 14, color: const Color(0xFF9AA3AF)),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFEEF0F3),
          ),
          itemBuilder: (_, i) {
            final item = items[i];
            return InkWell(
              onTap: () => onTap(item),
              splashColor: brandGreen.withValues(alpha: 0.05),
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
                          color: const Color(0xFF0F1117),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: Color(0xFFD1D5DB),
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
      child: const CircularProgressIndicator(color: brandGreen, strokeWidth: 2),
    );
  }

  Widget _buildLocationDone(bool isRu) {
    return GestureDetector(
      onTap: () => _resetLocationStep(0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandGreen.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: brandGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDistrict?.label(isRu) ??
                        _selectedEtrap?.label(isRu) ??
                        _selectedProvince?.label(isRu) ??
                        '',
                    style: AppText.bold(
                      fontSize: 15,
                      color: const Color(0xFF0F1117),
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
                      color: const Color(0xFF9AA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF9AA3AF)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _RoleBadge extends StatelessWidget {
  final bool isCourier;
  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
  );

  const _RoleBadge({required this.isCourier});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: brandGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCourier
                    ? Icons.electric_bike_outlined
                    : Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isCourier ? 'Курьер' : 'Заказчик',
                style: AppText.bold(fontSize: 13, color: Colors.white),
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
  static const Color brandGreen = Color(0xFF1A7A3C);

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: brandGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: brandGreen),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppText.bold(
            fontSize: 11,
            color: const Color(0xFF0F1117),
          ).copyWith(letterSpacing: 1),
        ),
      ],
    );
  }
}

class _BrandInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;

  static const Color brandGreen = Color(0xFF1A7A3C);

  const _BrandInputField({
    required this.label,
    required this.controller,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: AppText.regular(fontSize: 14, color: const Color(0xFF0F1117)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.regular(
          fontSize: 13,
          color: const Color(0xFF9AA3AF),
        ),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9AA3AF)),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: brandGreen.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD32F1E), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD32F1E), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Заполните поле' : null,
    );
  }
}

class _BrandPhotoBox extends StatelessWidget {
  final String text;
  final String subtitle;
  final File? file;
  final VoidCallback onTap;

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
  );

  const _BrandPhotoBox({
    required this.text,
    required this.subtitle,
    this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: file != null
                  ? brandGreen.withValues(alpha: 0.4)
                  : const Color(0xFFEEF0F3),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text,
                      style: AppText.bold(
                        fontSize: 13,
                        color: const Color(0xFF0F1117),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppText.regular(
                        fontSize: 11,
                        color: const Color(0xFF9AA3AF),
                      ),
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
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
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
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

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  static const Color brandGreen = Color(0xFF1A7A3C);

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
              ? brandGreen.withValues(alpha: 0.1)
              : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? brandGreen.withValues(alpha: 0.3)
                : const Color(0xFFEEF0F3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.semiBold(
                fontSize: 12,
                color: isSelected ? brandGreen : const Color(0xFF6B7280),
              ),
            ),
            if (!isSelected) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.close_rounded,
                size: 12,
                color: Color(0xFF9AA3AF),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
