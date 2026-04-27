import 'package:bagla/core/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ЭКРАН 1: Заглушка для пользователей на модерации
class RestrictedAccessView extends StatelessWidget {
  final VoidCallback onActionPressed;
  final String title;
  final String message;
  final String buttonText;

  const RestrictedAccessView({
    super.key,
    required this.onActionPressed,
    this.title = "Модерация аккаунта",
    this.message =
        "Пополнение баланса станет доступно сразу после подтверждения вашего профиля модератором.",
    this.buttonText = "ПОНЯТНО",
  });

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF1B3A6B);
    const Color brandGreen = Color(0xFF27AE60);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.lock_clock_rounded,
          size: 60,
          color: Color(0xFFD1D5DB),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: AppText.extraBold(
            fontSize: 20,
            color: brandBlue,
          ).copyWith(letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.regular(
            fontSize: 14,
            color: const Color(0xFF9AA3AF),
          ).copyWith(height: 1.5),
        ),
        const SizedBox(height: 32),
        _buildButton(buttonText, onActionPressed, brandGreen, true),
      ],
    );
  }
}

/// ЭКРАН 2: Активная форма пополнения
class TopUpFormView extends StatelessWidget {
  final TextEditingController controller;
  final int points;
  final int rate;
  final bool isLoading;
  final Function(String) onChanged;
  final VoidCallback onSubmit;
  final Widget summaryPanel;

  const TopUpFormView({
    super.key,
    required this.controller,
    required this.points,
    required this.rate,
    required this.isLoading,
    required this.onChanged,
    required this.onSubmit,
    required this.summaryPanel,
  });

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF1B3A6B);
    const Color brandGreen = Color(0xFF27AE60);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Пополнение баллов",
          style: AppText.extraBold(fontSize: 20, color: brandBlue),
        ),
        const SizedBox(height: 6),
        Text(
          "Курс конвертации: 1 балл = $rate TMT",
          style: AppText.regular(fontSize: 14, color: const Color(0xFF9AA3AF)),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppText.bold(fontSize: 24, color: brandBlue),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: "0",
            prefixIcon: const Icon(
              Icons.stars_rounded,
              color: Color(0xFFF1C40F),
              size: 28,
            ),
            suffixText: "баллов",
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: brandGreen, width: 2),
            ),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 24),
        summaryPanel,
        const SizedBox(height: 32),
        _buildButton(
          "ОТПРАВИТЬ ЗАЯВКУ",
          onSubmit,
          brandGreen,
          points > 0 && !isLoading,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

/// Вспомогательный метод для кнопок
Widget _buildButton(
  String text,
  VoidCallback onTap,
  Color color,
  bool isActive, {
  bool isLoading = false,
}) {
  return SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        disabledBackgroundColor: const Color(0xFFF3F4F6),
      ),
      onPressed: isActive ? onTap : null,
      child: isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(text, style: AppText.bold(fontSize: 16, color: Colors.white)),
    ),
  );
}
