import 'package:bagla/core/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand constants (local, no external import needed)
// ─────────────────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF1A7A3C);
const _kRed = Color(0xFFD32F1E);
const _kGrey = Color(0xFF9AA3AF);
const _kBg = Color(0xFFF5F7FA);
const _kBorder = Color(0xFFEEF0F3);
const _kGradient = LinearGradient(colors: [_kGreen, _kRed]);

// ─────────────────────────────────────────────────────────────────────────────
// RestrictedAccessView — shown when account is under moderation
// ─────────────────────────────────────────────────────────────────────────────

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
        'Пополнение баланса и принятие заказов станут доступны сразу после '
        'подтверждения вашего профиля модератором.',
    this.buttonText = 'ПОНЯТНО',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon with gradient background
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_kGreen.withOpacity(0.1), _kRed.withOpacity(0.07)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.lock_clock_rounded, size: 36, color: _kGrey),
        ),
        const SizedBox(height: 20),

        // Gradient accent bar
        Container(
          height: 3,
          width: 48,
          decoration: BoxDecoration(
            gradient: _kGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          title,
          style: AppText.extraBold(
            fontSize: 20,
            color: const Color(0xFF0F1117),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Message
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.regular(
            fontSize: 13,
            color: _kGrey,
          ).copyWith(height: 1.55),
        ),
        const SizedBox(height: 24),

        // Info pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.access_time_rounded,
                color: Color(0xFFE67E22),
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                'Обычно занимает до 24 часов',
                style: AppText.medium(
                  fontSize: 12,
                  color: const Color(0xFFE67E22),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _kGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kGreen.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onActionPressed,
              child: Text(
                buttonText,
                style: AppText.bold(
                  fontSize: 14,
                  color: Colors.white,
                ).copyWith(letterSpacing: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TopUpFormView — active top-up form
// ─────────────────────────────────────────────────────────────────────────────

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
    final bool canSubmit = points > 0 && !isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // Gradient accent bar
        Container(
          height: 3,
          width: 48,
          decoration: BoxDecoration(
            gradient: _kGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        // Amount field
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppText.extraBold(
            fontSize: 28,
            color: const Color(0xFF0F1117),
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: AppText.regular(
              fontSize: 28,
              color: const Color(0xFFD1D5DB),
            ),
            prefixIcon: Image.asset(
              'assets/images/point_icon.png',
              width: 28,
              height: 28,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.toll_rounded, color: _kGreen, size: 26),
            ),
            suffixText: 'жетонов',
            suffixStyle: AppText.regular(fontSize: 14, color: _kGrey),
            filled: true,
            fillColor: _kBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _kGreen.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),

        // Rate hint
        Text(
          '1 жетон = $rate TMT',
          style: AppText.regular(fontSize: 12, color: _kGrey),
        ),
        const SizedBox(height: 20),

        // Summary panel (passed from parent)
        summaryPanel,

        const SizedBox(height: 24),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: canSubmit ? _kGradient : null,
              color: canSubmit ? null : _kBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: canSubmit
                  ? [
                      BoxShadow(
                        color: _kGreen.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: canSubmit ? onSubmit : null,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: _kGreen,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'ОТПРАВИТЬ ЗАЯВКУ',
                      style: AppText.bold(
                        fontSize: 14,
                        color: canSubmit ? Colors.white : _kGrey,
                      ).copyWith(letterSpacing: 0.5),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
