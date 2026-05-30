import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/orders/widgets/order_primary_button.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Premium-диалог успеха: «Заказ доставлен» + награды (жетоны + XP).
///
/// Открывается через `showDialog(barrierDismissible: false)` —
/// пользователь должен явно нажать кнопку, чтобы продолжить.
///
/// Использование:
/// ```dart
/// CashbackSuccessDialog.show(
///   context,
///   points: 5.0,
///   xpEarned: 50,
///   words: words,
///   onClose: () => Navigator.pop(parentContext),
/// );
/// ```
class CashbackSuccessDialog extends StatelessWidget {
  final double points;
  final int xpEarned;
  final AppLocalizations words;
  final VoidCallback onClose;

  const CashbackSuccessDialog({
    super.key,
    required this.points,
    required this.xpEarned,
    required this.words,
    required this.onClose,
  });

  static Future<void> show(
    BuildContext context, {
    required double points,
    required int xpEarned,
    required AppLocalizations words,
    required VoidCallback onClose,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CashbackSuccessDialog(
        points: points,
        xpEarned: xpEarned,
        words: words,
        onClose: () {
          Navigator.pop(ctx);
          onClose();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.emeraldTint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: c.ink, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              words.orderDone,
              style: AppText.serif(fontSize: 20, color: c.ink),
            ),
            const SizedBox(height: 8),
            Text(
              words.deliveredOnTime,
              style: AppText.regular(fontSize: 13, color: c.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Tokens reward
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: c.amberTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/point_icon.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.toll_rounded, color: c.amber, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${points.toDouble()} ${words.tokens}',
                    style: AppText.semiBold(fontSize: 20, color: c.amber),
                  ),
                ],
              ),
            ),
            // XP reward (если есть)
            if (xpEarned > 0) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, color: c.accent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '+$xpEarned XP',
                      style: AppText.semiBold(fontSize: 20, color: c.accent),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              words.deliveryOnTimeSub,
              style: AppText.regular(fontSize: 12, color: c.inkSoft),
            ),
            const SizedBox(height: 20),
            OrderPrimaryButton(
              label: words.great,
              color: c.ink,
              filled: true,
              onTap: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
