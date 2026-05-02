import 'dart:io';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:bagla/models/district.dart';
import 'package:bagla/models/etrap.dart';
import 'package:bagla/models/province.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authRepo = AuthRepository();
  bool _isLoading = false;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();
  final _priceController = TextEditingController();
  final _deliveryController = TextEditingController(); // ← ручной ввод
  final _dateTimeController = TextEditingController();

  DateTime? _selectedDateTime;
  List<XFile> _images = [];
  final _picker = ImagePicker();

  // ── Location (same pattern as RegistrationDetailsScreen) ──────────────────
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

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _dark = Color(0xFF0F1117);
  static const _grey = Color(0xFF9AA3AF);
  static const _bg = Color(0xFFF5F7FA);
  static const _gradient = LinearGradient(
    colors: [_green, _red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    _phoneController.dispose();
    _priceController.dispose();
    _deliveryController.dispose();
    _dateTimeController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Location loaders ───────────────────────────────────────────────────────

  Future<void> _loadProvinces() async {
    setState(() => _loadingProvinces = true);
    try {
      final list = await _authRepo.getProvinces();
      setState(() => _provinces = list);
    } catch (e) {
      _msg('Ошибка загрузки велаятов: $e', _red);
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
    });
    _searchCtrl.clear();
    try {
      final list = await _authRepo.getEtrapsByProvince(p.id);
      setState(() => _etraps = list);
    } catch (e) {
      _msg('Ошибка загрузки этрапов: $e', _red);
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
    });
    _searchCtrl.clear();
    try {
      final list = await _authRepo.getDistrictsByEtrap(e.id);
      setState(() => _districts = list);
    } catch (e) {
      _msg('Ошибка загрузки районов: $e', _red);
    } finally {
      setState(() => _loadingDistricts = false);
    }
  }

  void _selectDistrict(District d) {
    setState(() {
      _selectedDistrict = d;
      _searchQuery = '';
    });
    _searchCtrl.clear();
  }

  void _resetLocationStep(int step) {
    setState(() {
      _locationStep = step;
      _searchQuery = '';
      _searchCtrl.clear();
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

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (time == null) return;
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

  // ── Points calculation (preserved from original) ───────────────────────────

  int _calculatePoints(double orderSum) {
    if (orderSum >= 2000) return 5;
    if (orderSum >= 1000) return 4;
    if (orderSum >= 500) return 3;
    if (orderSum >= 100) return 2;
    return 0;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_images.isEmpty) {
      _msg('Добавьте фото товара', _red);
      return;
    }
    if (_selectedDistrict == null) {
      _msg('Выберите район доставки', _red);
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    try {
      final double itemPrice = double.parse(_priceController.text);
      final double deliveryFee = double.parse(_deliveryController.text);

      await OrderService().createOrder(
        address: "${_selectedEtrap!.ru} - ${_selectedDistrict!.ru}",
        addresstk:
            "${_selectedEtrap!.tk} - ${_selectedDistrict!.tk}", // адрес доставки (поле куда)
        shopAddress: auth.address,
        phone: _phoneController.text,
        comment: '',
        deliveryTime: _selectedDateTime,
        itemPrice: itemPrice,
        deliveryFee: deliveryFee,
        pointsAmount: _calculatePoints(itemPrice),
        images: _images,
        userId: auth.userId,
        shopPhone: auth.phone,
        districtId: _selectedDistrict!.id,
        etrapId: _selectedEtrap!.id,
        provinceId: _selectedProvince!.id,
      );

      _msg('Заказ успешно создан!', _green);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _msg('Ошибка: $e', _red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _msg(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: AppText.regular(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRu = lang.isRu;
    final double itemPrice = double.tryParse(_priceController.text) ?? 0;
    final double deliveryFee = double.tryParse(_deliveryController.text) ?? 0;
    final double total = itemPrice + deliveryFee;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _green,
              size: 16,
            ),
          ),
        ),
        title: Text(
          'Новый заказ',
          style: AppText.semiBold(fontSize: 17, color: _dark),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
        ),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      // ── Photos ─────────────────────────────────────────
                      _section(
                        icon: Icons.camera_alt_outlined,
                        title: 'Фото товара',
                        child: _imagePickerWidget(),
                      ),
                      const SizedBox(height: 12),

                      // ── Recipient ──────────────────────────────────────
                      _section(
                        icon: Icons.person_outline_rounded,
                        title: 'Получатель',
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _phoneField(),
                            const SizedBox(height: 10),
                            _dateField(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Order details ──────────────────────────────────
                      _section(
                        icon: Icons.inventory_2_outlined,
                        title: 'Детали заказа',
                        child: Column(
                          children: [
                            _priceField(),
                            const SizedBox(height: 10),
                            _deliveryField(), // ← ручной ввод суммы доставки
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Delivery address (stepper) ──────────────────────
                      _section(
                        icon: Icons.map_outlined,
                        title: 'Район доставки',
                        child: _buildLocationStepper(isRu),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                // ── Bottom panel ───────────────────────────────────────────
                _buildBottomPanel(deliveryFee, total),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                child: CircularProgressIndicator(color: _green),
              ),
            ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF0F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
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
              // Gradient mini bar
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  gradient: _gradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 14, color: _grey),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: AppText.semiBold(
                  fontSize: 10,
                  color: _grey,
                ).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── Image picker ───────────────────────────────────────────────────────────

  Widget _imagePickerWidget() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + (_images.length < 3 ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _images.length) {
            return GestureDetector(
              onTap: () async {
                final selected = await _picker.pickMultiImage();
                if (selected.isNotEmpty) {
                  setState(
                    () => _images = [..._images, ...selected].take(3).toList(),
                  );
                }
              },
              child: Container(
                width: 90,
                height: 90,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _green.withOpacity(0.25),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _green.withOpacity(0.5),
                      size: 26,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Добавить',
                      style: AppText.regular(fontSize: 10, color: _grey),
                    ),
                  ],
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(_images[index].path),
                    width: 90,
                    height: 90,
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
                      child: const Icon(
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

  // ── Fields ─────────────────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: AppText.regular(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.regular(fontSize: 14, color: _grey),
        prefixIcon: Icon(icon, color: iconColor, size: 18),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _green.withOpacity(0.4), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Заполните поле' : null,
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppText.regular(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        hintText: 'Телефон клиента',
        hintStyle: AppText.regular(fontSize: 14, color: _grey),
        prefixIcon: const Icon(
          Icons.phone_android_outlined,
          color: _green,
          size: 18,
        ),
        prefixText: '+993 ',
        prefixStyle: AppText.regular(fontSize: 14, color: _dark),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _green.withOpacity(0.4), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (v) =>
          (v == null || v.length < 8) ? 'Номер слишком короткий' : null,
    );
  }

  Widget _dateField() {
    return TextFormField(
      controller: _dateTimeController,
      readOnly: true,
      onTap: _pickDateTime,
      style: AppText.regular(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        hintText: 'Время доставки (необязательно)',
        hintStyle: AppText.regular(fontSize: 14, color: _grey),
        prefixIcon: const Icon(
          Icons.calendar_today_outlined,
          color: _grey,
          size: 18,
        ),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _priceField() {
    return TextFormField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      style: AppText.semiBold(fontSize: 18, color: _dark),
      decoration: InputDecoration(
        hintText: 'Сумма товара',
        hintStyle: AppText.regular(fontSize: 14, color: _grey),
        prefixIcon: const Icon(
          Icons.payments_outlined,
          color: _green,
          size: 18,
        ),
        suffixText: 'TMT',
        suffixStyle: AppText.regular(fontSize: 13, color: _grey),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _green.withOpacity(0.4), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (v) =>
          (v == null || v.isEmpty || v == '0') ? 'Укажите цену' : null,
    );
  }

  /// ← НОВОЕ: ручной ввод суммы доставки (обязательное поле)
  Widget _deliveryField() {
    return TextFormField(
      controller: _deliveryController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      style: AppText.semiBold(fontSize: 18, color: _dark),
      decoration: InputDecoration(
        hintText: 'Сумма доставки',
        hintStyle: AppText.regular(fontSize: 14, color: _grey),
        prefixIcon: ShaderMask(
          shaderCallback: (b) => _gradient.createShader(b),
          child: const Icon(
            Icons.delivery_dining_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
        suffixText: 'TMT',
        suffixStyle: AppText.regular(fontSize: 13, color: _grey),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _red.withOpacity(0.4), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (v) => (v == null || v.isEmpty || v == '0')
          ? 'Укажите сумму доставки'
          : null,
    );
  }

  // ── Location stepper ───────────────────────────────────────────────────────

  Widget _buildLocationStepper(bool isRu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepIndicator(),
        const SizedBox(height: 14),

        if (_selectedProvince != null || _selectedDistrict != null)
          _buildBreadcrumb(isRu),

        if (_locationStep > 0 && _selectedDistrict == null) ...[
          const SizedBox(height: 10),
          _buildSearchField(),
        ],
        const SizedBox(height: 10),

        _selectedDistrict != null
            ? _buildLocationDone(isRu)
            : _buildCurrentStepList(isRu),
      ],
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Велаят', 'Этрап', 'Район'];
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
                          gradient: (isDone || isActive) ? _gradient : null,
                          color: (isDone || isActive)
                              ? null
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
                          color: (isDone || isActive) ? _dark : _grey,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
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
      ),
    );
  }

  Widget _buildSearchField() {
    final hints = ['', 'Поиск этрапа...', 'Поиск района...'];
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: hints[_locationStep],
        hintStyle: AppText.regular(fontSize: 14, color: _grey),
        prefixIcon: const Icon(Icons.search_rounded, color: _grey, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18, color: _grey),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildCurrentStepList(bool isRu) {
    if (_locationStep == 0) return _buildProvinceGrid(isRu);
    if (_locationStep == 1) return _buildEtrapList(isRu);
    return _buildDistrictList(isRu);
  }

  Widget _buildProvinceGrid(bool isRu) {
    if (_loadingProvinces) return _loader();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: _provinces.length,
      itemBuilder: (_, i) {
        final p = _provinces[i];
        return GestureDetector(
          onTap: () => _selectProvince(p),
          child: Container(
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              p.label(isRu),
              textAlign: TextAlign.center,
              style: AppText.semiBold(fontSize: 13, color: _dark),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEtrapList(bool isRu) {
    if (_loadingEtraps) return _loader();
    final filtered = _etraps
        .where((e) => e.label(isRu).toLowerCase().contains(_searchQuery))
        .toList();
    return _itemList(
      items: filtered,
      labelFn: (e) => e.label(isRu),
      onTap: (e) => _selectEtrap(e),
    );
  }

  Widget _buildDistrictList(bool isRu) {
    if (_loadingDistricts) return _loader();
    final filtered = _districts
        .where((d) => d.label(isRu).toLowerCase().contains(_searchQuery))
        .toList();
    return _itemList(
      items: filtered,
      labelFn: (d) => d.label(isRu),
      onTap: (d) => _selectDistrict(d),
    );
  }

  Widget _itemList<T>({
    required List<T> items,
    required String Function(T) labelFn,
    required void Function(T) onTap,
  }) {
    if (items.isEmpty) {
      return Container(
        height: 72,
        alignment: Alignment.center,
        child: Text(
          _searchQuery.isEmpty ? 'Нет данных' : 'Ничего не найдено',
          style: AppText.regular(fontSize: 14, color: _grey),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFEEF0F3),
          ),
          itemBuilder: (_, i) {
            final item = items[i];
            return InkWell(
              onTap: () => onTap(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        labelFn(item),
                        style: AppText.medium(fontSize: 14, color: _dark),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: _grey,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _green.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: _gradient,
                borderRadius: BorderRadius.circular(10),
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
                    style: AppText.semiBold(fontSize: 14, color: _dark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedProvince?.label(isRu) ?? ''} · ${_selectedEtrap?.label(isRu) ?? ''}',
                    style: AppText.regular(fontSize: 12, color: _grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: _grey),
          ],
        ),
      ),
    );
  }

  Widget _loader() {
    return Container(
      height: 72,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: _green, strokeWidth: 2),
    );
  }

  // ── Bottom panel ───────────────────────────────────────────────────────────

  Widget _buildBottomPanel(double delivery, double total) {
    final hasValues = total > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEF0F3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Курьеру: ${delivery.toStringAsFixed(0)} TMT',
                  style: AppText.regular(fontSize: 12, color: _grey),
                ),
                const SizedBox(height: 2),
                ShaderMask(
                  shaderCallback: (b) =>
                      (hasValues
                              ? _gradient
                              : const LinearGradient(colors: [_grey, _grey]))
                          .createShader(b),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        total.toStringAsFixed(0),
                        style: AppText.semiBold(
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'TMT',
                        style: AppText.regular(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isLoading ? null : _submitOrder,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                gradient: _isLoading ? null : _gradient,
                color: _isLoading ? _grey.withOpacity(0.3) : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: _green.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              alignment: Alignment.center,
              child: Text(
                'Оформить',
                style: AppText.semiBold(fontSize: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Breadcrumb chip (same as RegistrationDetailsScreen) ──────────────────────

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _BreadcrumbChip({
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [_green, _red])
              : null,
          color: isSelected ? null : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFEEF0F3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF0F1117),
              ),
            ),
            if (!isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 12, color: Color(0xFF9AA3AF)),
            ],
          ],
        ),
      ),
    );
  }
}
