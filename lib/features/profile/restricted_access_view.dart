import 'package:bagla/core/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Brand constants ────────────────────────────────────────────────────────
const Color _brandGreen = Color(0xFF1A7A3C);
const Color _brandRed = Color(0xFFD32F1E);
const LinearGradient _brandGradient = LinearGradient(
  colors: [_brandGreen, _brandRed],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

/// ЭКРАН 1: Заглушка для пользователей на модерации
class RestrictedAccessView extends StatelessWidget {
  final VoidCallback onActionPressed;
  final String title;
  final String message;
  final String buttonText;

  const RestrictedAccessView({
    super.key,
    required this.onActionPressed,
    this.title = 'Модерация аккаунта',
    this.message =
        'Пополнение баланса станет доступно сразу после подтверждения вашего профиля модератором.',
    this.buttonText = 'ПОНЯТНО',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon with gradient bg
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _brandGreen.withOpacity(0.12),
                _brandRed.withOpacity(0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.lock_clock_rounded,
            size: 32,
            color: _brandGreen,
          ),
        ),
        const SizedBox(height: 20),

        ShaderMask(
          shaderCallback: (b) => _brandGradient.createShader(b),
          child: Text(
            title,
            style: AppText.extraBold(fontSize: 20, color: Colors.white),
            textAlign: TextAlign.center,
          ),
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

        _BrandButton(text: buttonText, onTap: onActionPressed, isActive: true),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),

        // Input field
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppText.bold(fontSize: 24, color: const Color(0xFF0F1117)),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: AppText.bold(
              fontSize: 24,
              color: const Color(0xFFD1D5DB),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: _brandGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.toll_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            suffixText: 'баллов',
            suffixStyle: AppText.regular(
              fontSize: 14,
              color: const Color(0xFF9AA3AF),
            ),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _brandGreen.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 20),

        summaryPanel,
        const SizedBox(height: 28),

        _BrandButton(
          text: 'ОТПРАВИТЬ ЗАЯВКУ',
          onTap: onSubmit,
          isActive: points > 0 && !isLoading,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared brand button
// ═════════════════════════════════════════════════════════════════════════════

class _BrandButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isActive;
  final bool isLoading;

  const _BrandButton({
    required this.text,
    required this.onTap,
    required this.isActive,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: isActive ? _brandGradient : null,
          color: isActive ? null : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(16),
          border: isActive ? null : Border.all(color: const Color(0xFFEEF0F3)),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _brandGreen.withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                text,
                style: AppText.bold(
                  fontSize: 14,
                  color: isActive ? Colors.white : const Color(0xFF9AA3AF),
                ).copyWith(letterSpacing: 0.5),
              ),
      ),
    );
  }
}
