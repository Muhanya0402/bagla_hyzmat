import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';

/// Большая нижняя CTA-кнопка для деталей заказа.
///
/// Поддерживает два режима — `filled: true` (залитая) и `filled: false`
/// (outline), а также `isLoading: true` для disabled-state со спиннером.
///
/// Использование:
/// ```dart
/// OrderPrimaryButton(
///   label: words.takeOrder,
///   color: c.ink,
///   filled: true,
///   onTap: () => ...,
/// )
/// ```
class OrderPrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final bool isLoading;
  final VoidCallback onTap;

  const OrderPrimaryButton({
    super.key,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      // Disabled state — onTap=null отключает таппы.
      onTap: isLoading ? null : onTap,
      curve: Curves.easeOutBack,
      haptic: HapticFeedbackType.medium, // главное действие заказа

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: filled
              ? (isLoading ? color.withValues(alpha: 0.4) : color)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: filled && !isLoading
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: AppText.semiBold(
                  fontSize: 14,
                  color: filled ? Colors.white : color,
                ),
              ),
      ),
    );
  }
}
