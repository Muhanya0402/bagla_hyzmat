import 'dart:io';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isLoading = false;

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();

  DateTime? _selectedDateTime;
  List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

  static const Color brandBlue = Color(0xFF1B3A6B);
  static const Color brandGreen = Color(0xFF27AE60);
  static const Color brandRed = Color(0xFFB00020);

  @override
  void dispose() {
    _descController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _priceController.dispose();
    _dateTimeController.dispose();
    super.dispose();
  }

  int calculatePoints(double orderSum) {
    if (orderSum >= 2000) return 5;
    if (orderSum >= 1000) return 4;
    if (orderSum >= 500) return 3;
    if (orderSum >= 100)
      return 2; // В условии "если 100 тогда больше", обычно это 2 балла или согласно вашей логике
    return 0;
  }

  double calculateDeliveryFee(double orderSum) {
    if (orderSum <= 0) return 0;
    if (orderSum <= 100) return 15;
    if (orderSum < 500) return 20;
    if (orderSum < 1000) return 30;
    if (orderSum <= 2000) return 50;
    return 50;
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (date == null) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      _msg("Добавьте фото товара", brandRed);
      return;
    }

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final double itemPrice = double.parse(
        _priceController.text,
      ); // Парсим один раз
      final service = OrderService();

      await service.createOrder(
        address: _addressController.text,
        shopAddress: auth.address,
        phone: _phoneController.text,
        comment: _descController.text,
        deliveryTime: _selectedDateTime,
        itemPrice: itemPrice,
        deliveryFee: calculateDeliveryFee(itemPrice),
        pointsAmount: calculatePoints(itemPrice), // <-- ДОБАВЛЕНО
        images: _images,
        userId: auth.userId,
        shopPhone: auth.phone,
      );

      _msg("Заказ успешно создан!", brandGreen);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _msg("Ошибка: $e", brandRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _msg(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double orderPrice = double.tryParse(_priceController.text) ?? 0;
    final double deliveryFee = calculateDeliveryFee(orderPrice);
    final double total = orderPrice + deliveryFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brandBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: brandBlue.withOpacity(0.1), width: 1),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: brandBlue,
              size: 16,
            ),
          ),
        ),
        title: Text(
          "Новый заказ",
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1117),
          ),
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
                      // Фото
                      _buildSection(
                        title: "Фото товара",
                        icon: Icons.camera_alt_outlined,
                        child: _imagePickerWidget(),
                      ),
                      const SizedBox(height: 12),

                      // Получатель
                      _buildSection(
                        title: "Получатель",
                        icon: Icons.person_outline_rounded,
                        child: Column(
                          children: [
                            _buildField(
                              controller: _addressController,
                              hint: "Адрес доставки",
                              icon: Icons.location_on_outlined,
                              iconColor: brandGreen,
                            ),
                            const SizedBox(height: 10),
                            _buildPhoneField(),
                            const SizedBox(height: 10),
                            _buildDateField(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Детали
                      _buildSection(
                        title: "Детали заказа",
                        icon: Icons.inventory_2_outlined,
                        child: Column(
                          children: [
                            _buildField(
                              controller: _descController,
                              hint: "Что везём?",
                              icon: Icons.inventory_2_outlined,
                              iconColor: brandBlue,
                            ),
                            const SizedBox(height: 10),
                            _buildPriceField(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBottomPanel(deliveryFee, total),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                child: CircularProgressIndicator(color: brandGreen),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF0F3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF9AA3AF)),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9AA3AF),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

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
                final List<XFile> selected = await _picker.pickMultiImage();
                if (selected.isNotEmpty) {
                  setState(
                    () => _images = [..._images, ...selected].take(3).toList(),
                  );
                }
              },
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: brandBlue.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: brandBlue.withOpacity(0.4),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Добавить",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: brandBlue.withOpacity(0.4),
                      ),
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
                        color: Colors.black.withOpacity(0.5),
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

  Widget _buildField({
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
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F1117)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF9AA3AF),
        ),
        prefixIcon: Icon(icon, color: iconColor, size: 18),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brandBlue.withOpacity(0.3), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? "Заполните поле" : null,
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F1117)),
      decoration: InputDecoration(
        hintText: "Телефон клиента",
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF9AA3AF),
        ),
        prefixIcon: const Icon(
          Icons.phone_android_outlined,
          color: brandBlue,
          size: 18,
        ),
        prefixText: "+993 ",
        prefixStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF0F1117),
        ),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brandBlue.withOpacity(0.3), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (v) =>
          (v == null || v.length < 8) ? "Номер слишком короткий" : null,
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateTimeController,
      readOnly: true,
      onTap: _pickDateTime,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F1117)),
      decoration: InputDecoration(
        hintText: "Время доставки",
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF9AA3AF),
        ),
        prefixIcon: const Icon(
          Icons.calendar_today_outlined,
          color: brandBlue,
          size: 18,
        ),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? "Выберите время" : null,
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) => setState(() {}),
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: brandBlue,
      ),
      decoration: InputDecoration(
        hintText: "Сумма товара",
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF9AA3AF),
        ),
        prefixIcon: const Icon(
          Icons.payments_outlined,
          color: brandGreen,
          size: 18,
        ),
        suffixText: "TMT",
        suffixStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF9AA3AF),
        ),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brandGreen.withOpacity(0.3), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (v) =>
          (v == null || v.isEmpty || v == "0") ? "Укажите цену" : null,
    );
  }

  Widget _buildBottomPanel(double delivery, double total) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEF0F3), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Курьеру: ${delivery.toStringAsFixed(0)} TMT",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AA3AF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      total.toStringAsFixed(0),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: brandBlue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "TMT",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: brandBlue.withOpacity(0.4),
                      ),
                    ),
                  ],
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
                color: _isLoading ? brandGreen.withOpacity(0.5) : brandGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                "Оформить",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
