import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/point_icon.dart';
import 'package:bagla/core/widgets/pressable_scale.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PointsCard extends StatelessWidget {
  final double balance;
  final VoidCallback onTopUp;
  final bool isLoading;

  /// Опциональный ключ для тур-анкера на кнопке «Пополнить».
  final Key? topUpKey;

  const PointsCard({
    super.key,
    required this.balance,
    required this.onTopUp,
    this.isLoading = false,
    this.topUpKey,
  });

  /// Форматируем баланс без лишних нулей: 5 → "5", 5.5 → "5.5", 5.25 → "5.25".
  String _formatted(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(
          RegExp(r'\.$'),
          '',
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.amberTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.amber.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const PointIcon(size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      words.profileMyTokens,
                      style: AppText.regular(fontSize: 11, color: c.inkMuted),
                    ),
                    const SizedBox(height: 1),
                    isLoading
                        ? Container(
                            height: 24,
                            width: 64,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: c.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          )
                        : Text(
                            _formatted(balance),
                            style: AppText.bold(fontSize: 22, color: c.ink)
                                .copyWith(letterSpacing: -0.5, height: 1.1),
                          ),
                  ],
                ),
              ),
              PressableScale(
                key: topUpKey,
                onTap: onTopUp,
                scale: 0.94,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: c.emeraldTint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.ink.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: c.ink),
                      const SizedBox(width: 5),
                      Text(
                        words.profileTopUp,
                        style: AppText.semiBold(fontSize: 12, color: c.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 11, color: c.inkSoft),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  words.profileTokensHint,
                  style: AppText.regular(fontSize: 11, color: c.inkSoft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
