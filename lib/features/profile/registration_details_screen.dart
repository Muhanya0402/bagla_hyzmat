import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_sizes.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
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

  // Файлы фото
  File? _passportFile;
  File? _addressFile;

  static const Color brandBlue = Color(0xFF1B3A6B);
  static const Color brandGreen = Color(0xFF27AE60);

  final _c1 = TextEditingController(); // Имя / Организация
  final _c2 = TextEditingController(); // Фамилия / Адрес
  final _c3 = TextEditingController(); // Отчество

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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Проверка наличия фото для курьера (оставляем как есть)
    if (widget.role == 'courier' &&
        (_passportFile == null || _addressFile == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Пожалуйста, загрузите оба фото паспорта"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) throw "ID пользователя не найден";

      String? passportId;
      String? addressId;

      // 1. Загружаем файлы (оставляем без изменений)
      if (_passportFile != null)
        passportId = await _authRepo.uploadFile(_passportFile!.path);
      if (_addressFile != null)
        addressId = await _authRepo.uploadFile(_addressFile!.path);

      // 2. Формируем данные профиля
      Map<String, dynamic> updateData = {
        'role': widget.role,
        'passport_scan': passportId,
        'adress_scan': addressId,
      };

      if (widget.role == 'courier') {
        updateData.addAll({
          'name': _c1.text.trim(),
          'surname': _c2.text.trim(),
          'lastname': _c3.text.trim(),
          'status': "pending",
        });
      } else {
        updateData.addAll({
          'organization_name': _c1.text.trim(),
          'address': _c2.text.trim(), // Это поле адреса
          'name': _c1.text.trim(),
          'status': "pending",
        });
      }

      // 3. Отправляем в Directus
      final success = await _authRepo.updateProfile(
        userId: userId,
        data: updateData,
      );

      if (success) {
        if (!mounted) return;

        // 🔹 ВОТ ТУТ ГЛАВНОЕ ИЗМЕНЕНИЕ:
        // Если это не курьер, принудительно обновляем адрес в AuthProvider
        if (widget.role != 'courier') {
          final newAddr = _c2.text.trim();
          context.read<AuthProvider>().updateShopAddress(newAddr);
        }

        // Обновляем весь профиль из сервера для верности
        await context.read<AuthProvider>().refreshProfile();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Данные отправлены. Ожидайте подтверждения модератора",
            ),
            backgroundColor: brandGreen,
          ),
        );

        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = AppSizes.of(context);
    final isCourier = widget.role == 'courier';
    final words = context.watch<LanguageProvider>().words;

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
          style: GoogleFonts.montserrat(
            color: brandBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
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
              children: [
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
                  const SizedBox(height: 30),
                  // Секция фото
                  const Text(
                    "ФОТО ПАСПОРТА",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: brandBlue,
                      letterSpacing: 1,
                    ),
                  ),
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
                    ? const CircularProgressIndicator(color: brandGreen)
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
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: brandBlue,
          ),
        ),
      ],
    );
  }
}

// 🔹 Виджет выбора фото
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

// Поля ввода и Кнопка остаются такими же как были...
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
          ),
          validator: (v) => (v == null || v.isEmpty) ? "Заполните поле" : null,
        ),
      ],
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
