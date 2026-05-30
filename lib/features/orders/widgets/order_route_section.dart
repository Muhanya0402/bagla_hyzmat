import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Секция «Маршрут»: вертикальный timeline между точкой A (магазин) и B (доставка).
///
/// Точка A — accent (terracotta-ish) кружок, точка B — `ink`. Между ними —
/// тонкая `borderSoft` линия. Адреса берутся из `OrderDto` с учётом языка.
class OrderRouteSection extends StatelessWidget {
  final OrderDto dto;
  final bool isLocked;

  const OrderRouteSection({
    super.key,
    required this.dto,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lang = context.watch<LanguageProvider>();
    final fromAddr = dto.shopAddress(lang.isRu);
    final toAddr = dto.deliveryAddress(lang.isRu);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: c.borderSoft,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.ink,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Addresses
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoutePoint(label: lang.words.orderFrom, value: fromAddr),
                const SizedBox(height: 14),
                _RoutePoint(label: lang.words.orderTo, value: toAddr),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String label;
  final String value;
  const _RoutePoint({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.regular(fontSize: 10, color: c.inkSoft)),
        const SizedBox(height: 2),
        Text(
          value,
          style:
              AppText.medium(fontSize: 13, color: c.ink).copyWith(height: 1.4),
        ),
      ],
    );
  }
}
