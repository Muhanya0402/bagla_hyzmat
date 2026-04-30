import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
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

  static const Color brandBlue = Color(0xFF1B3A6B);
  static const Color brandGreen = Color(0xFF27AE60);
  static const Color brandGrey = Color(0xFFF6F6F6);

  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();

  // Локация
  List<Province> _provinces = [];
  List<Etrap> _etraps = [];
  List<District> _districts = [];

  Province? _selectedProvince;
  Etrap? _selectedEtrap;
  District? _selectedDistrict;

  bool _loadingProvinces = false;
  bool _loadingEtraps = false;
  bool _loadingDistricts = false;

  // Текущий шаг выбора локации: 0=велаят, 1=этрап, 2=район
  int _locationStep = 0;

  // Поиск
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

  // ─── Загрузка данных ───────────────────────────────────────────────────────

  Future<void> _loadProvinces() async {
    setState(() => _loadingProvinces = true);
    try {
      final list = await _authRepo.getProvinces();
      setState(() => _provinces = list);
    } catch (e) {
      _showSnack("Ошибка загрузки велаятов: $e");
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
      _searchController.clear();
      _loadingEtraps = true;
    });
    try {
      final list = await _authRepo.getEtrapsByProvince(p.id);
      setState(() => _etraps = list);
    } catch (e) {
      _showSnack("Ошибка загрузки этрапов: $e");
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
      _searchController.clear();
      _loadingDistricts = true;
    });
    try {
      final list = await _authRepo.getDistrictsByEtrap(e.id);
      setState(() => _districts = list);
    } catch (e) {
      _showSnack("Ошибка загрузки районов: $e");
    } finally {
      setState(() => _loadingDistricts = false);
    }
  }

  void _selectDistrict(District d) {
    setState(() {
      _selectedDistrict = d;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _resetLocationStep(int step) {
    setState(() {
      _locationStep = step;
      _searchQuery = '';
      _searchController.clear();
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

  // ─── Фото ──────────────────────────────────────────────────────────────────

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

  // ─── Отправка ──────────────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDistrict == null) {
      _showSnack("Пожалуйста, выберите район");
      return;
    }

    if (widget.role == 'courier' &&
        (_passportFile == null || _addressFile == null)) {
      _showSnack("Пожалуйста, загрузите оба фото паспорта");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) throw "ID пользователя не найден";

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
        });
      } else {
        updateData.addAll({
          'organization_name': _c1.text.trim(),
          'address': _c2.text.trim(),
          'name': _c1.text.trim(),
          'status': 'pending',
        });
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
          "Данные отправлены. Ожидайте подтверждения",
          color: brandGreen,
        );

        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    } catch (e) {
      _showSnack("Ошибка: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sizes = AppSizes.of(context);
    final isCourier = widget.role == 'courier';
    final langProvider = context.watch<LanguageProvider>();
    final isRu = langProvider.isRu;
    final words = langProvider.words;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: brandBlue,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          words.confirmBtn.toUpperCase(),
          style: AppText.bold(fontSize: 16),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: sizes.spacing(6)),
        children: [
          const SizedBox(height: 10),
          _buildHeader(isCourier),
          const SizedBox(height: 30),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Поля ввода ─────────────────────────────────────────────
                if (!isCourier) ...[
                  _InputField(
                    label: "Наименование организации",
                    controller: _c1,
                  ),
                  const SizedBox(height: 20),
                  _InputField(label: "Юридический адрес", controller: _c2),
                ],
                if (isCourier) ...[
                  _InputField(label: "Имя", controller: _c1),
                  const SizedBox(height: 20),
                  _InputField(label: "Фамилия", controller: _c2),
                  const SizedBox(height: 20),
                  _InputField(label: "Отчество", controller: _c3),
                ],

                const SizedBox(height: 28),

                // ── Выбор локации (степпер) ────────────────────────────────
                _buildLocationStepper(isRu),

                // ── Фото паспорта ──────────────────────────────────────────
                if (isCourier) ...[
                  const SizedBox(height: 30),
                  _buildSectionLabel("ФОТО ПАСПОРТА"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _PhotoBox(
                        text: "Главная",
                        file: _passportFile,
                        onTap: () => _pickImage(true),
                      ),
                      const SizedBox(width: 12),
                      _PhotoBox(
                        text: "Прописка",
                        file: _addressFile,
                        onTap: () => _pickImage(false),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 40),
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: brandGreen),
                      )
                    : _SubmitButton(
                        text: words.saveBtn,
                        onPressed: _handleSubmit,
                      ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Степпер локации ───────────────────────────────────────────────────────

  Widget _buildLocationStepper(bool isRu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("МЕСТОПОЛОЖЕНИЕ"),
        const SizedBox(height: 12),

        // Прогресс-бар шагов
        _buildStepIndicator(),
        const SizedBox(height: 16),

        // Хлебные крошки выбранных значений
        if (_selectedProvince != null ||
            _selectedEtrap != null ||
            _selectedDistrict != null)
          _buildBreadcrumb(isRu),

        const SizedBox(height: 12),

        // Поиск (только для этрапа и района)
        if (_locationStep > 0 && _selectedDistrict == null) _buildSearchField(),

        const SizedBox(height: 8),

        // Список текущего шага
        if (_selectedDistrict == null)
          _buildCurrentStepList(isRu)
        else
          _buildLocationDone(isRu),
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
              // Можно тапнуть назад на уже выбранный шаг
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
                          color: isDone || isActive
                              ? brandGreen
                              : const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isDone || isActive ? brandBlue : Colors.grey,
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
    return Wrap(
      spacing: 4,
      runSpacing: 4,
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
    );
  }

  Widget _buildSearchField() {
    final hints = ['', 'Поиск этрапа...', 'Поиск района...'];
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: hints[_locationStep],
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: brandGrey,
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
      onTap: (p) => _selectProvince(p),
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
      onTap: (e) => _selectEtrap(e),
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
      onTap: (d) => _selectDistrict(d),
    );
  }

  /// Сетка 2×N — для велаятов (их мало, красиво смотрится)
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
              color: brandGrey,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.transparent),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              labelFn(item),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: brandBlue,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  /// Вертикальный список — для этрапов и районов
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
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: brandGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFEEEEEE),
          ),
          itemBuilder: (_, i) {
            final item = items[i];
            return InkWell(
              onTap: () => onTap(item),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: brandBlue,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.grey,
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

  /// Финальное состояние — район выбран
  Widget _buildLocationDone(bool isRu) {
    return GestureDetector(
      onTap: () => _resetLocationStep(0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: brandGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandGreen.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: brandGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDistrict!.label(isRu),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: brandBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedProvince?.label(isRu) ?? ''} · ${_selectedEtrap?.label(isRu) ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCourier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 6,
          decoration: BoxDecoration(
            color: brandGreen,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isCourier ? "Анкета курьера" : "Детали профиля",
          style: AppText.bold(fontSize: 24, color: brandBlue),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: brandBlue,
        letterSpacing: 1,
      ),
    );
  }
}

// ─── ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ───────────────────────────────────────────────

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
              ? const Color(0xFF27AE60)
              : const Color(0xFF1B3A6B).withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1B3A6B),
              ),
            ),
            if (!isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 12, color: Color(0xFF1B3A6B)),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _InputField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B3A6B),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF6F6F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (v) => (v == null || v.isEmpty) ? "Заполните поле" : null,
        ),
      ],
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String text;
  final File? file;
  final VoidCallback onTap;

  const _PhotoBox({required this.text, this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: file != null
                  ? Colors.green
                  : Colors.black.withOpacity(0.05),
            ),
            image: file != null
                ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover)
                : null,
          ),
          child: file == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_rounded,
                      color: Color(0xFF27AE60),
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B3A6B),
                      ),
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black26,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _SubmitButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF27AE60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
