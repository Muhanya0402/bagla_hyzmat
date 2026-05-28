import 'dart:io';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/models/district.dart';
import 'package:bagla/models/etrap.dart';
import 'package:bagla/models/points_rule.dart';
import 'package:bagla/models/province.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/features/orders/order_service.dart';
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

  DateTime? _selectedDateTime;
  List<XFile> _images = [];
  String _transportType = 'any';

  static const _transportOptions = [
    ('any', 'Авто необязательно', Icons.directions_run_rounded),
    ('car', 'Легковой авто', Icons.directions_car_rounded),
    ('truck', 'Грузовой авто', Icons.local_shipping_rounded),
  ];
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
    _orderService.fetchPointsRules().then((rules) {
      setState(() => _pointsRules = rules);
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
    _phoneFocus.dispose();
    _priceFocus.dispose();
    _deliveryFocus.dispose();
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

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.of(context).ink),
        ),
        child: child!,
      ),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.of(context).ink),
        ),
        child: child!,
      ),
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

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submitOrder(AppLocalizations words) async {
    if (!_formKey.currentState!.validate()) return;

    if (_images.isEmpty) {
      _msg(words.addPhotoError, isError: true);
      return;
    }
    if (!_locationSelected) {
      _msg(words.selectDistrictError, isError: true);
      return;
    }
    if (_selectedDateTime == null) {
      _msg(words.selectTimeError, isError: true);
      return;
    }

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
        shopAddress: auth.address,
        shopAddressTk: auth.address,
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
      );

      _msg(words.orderCreated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _msg('${words.error}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        leading: GestureDetector(
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
        title: Text(
          words.newOrder,
          style: AppText.serif(fontSize: 20, color: AppColors.of(context).ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.of(context).border),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      _section(
                        icon: Icons.camera_alt_outlined,
                        title: words.orderPhoto,
                        child: _imagePickerWidget(words),
                      ),
                      const SizedBox(height: 10),
                      _section(
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
                          child: _transportField(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _section(
                        icon: Icons.map_outlined,
                        title: words.orderDeliveryArea,
                        child: _buildLocationStepper(isRu, words),
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
                final selected = await _picker.pickMultiImage();
                if (selected.isNotEmpty) {
                  setState(
                    () => _images = [..._images, ...selected].take(3).toList(),
                  );
                }
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

  Widget _phoneField(AppLocalizations words) {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_priceFocus),
      style: AppText.regular(fontSize: 14, color: AppColors.of(context).ink),
      decoration:
          _fieldDecor(
            hint: words.clientPhone,
            prefix: Icon(
              Icons.phone_android_outlined,
              color: AppColors.of(context).ink,
              size: 18,
            ),
          ).copyWith(
            prefixText: '+993 ',
            prefixStyle: AppText.regular(
              fontSize: 14,
              color: AppColors.of(context).ink,
            ),
          ),
      validator: (v) => (v == null || v.length < 8) ? words.phoneShort : null,
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

  Widget _transportField() {
    return Column(
      children: _transportOptions.map((opt) {
        final (value, label, icon) = opt;
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
                  Icon(
                    Icons.toll_rounded,
                    size: 16,
                    color: AppColors.of(context).amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Публикация заказа: $points жетонов. Будут списаны после принятия курьером',
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
              _SubmitButton(
                label: words.placeOrder,
                isLoading: _isLoading,
                onTap: () => _submitOrder(words),
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
