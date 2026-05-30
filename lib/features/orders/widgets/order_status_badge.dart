import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Единый бейдж статуса заказа. Используется в `OrderCard` (Row) и в
/// `OrderDetailScreen` AppBar (chip рядом с ID).
///
/// Цвета строго из `AppColors` — никаких legacy `HomeColors.*`.
/// Иконка — опциональна (по умолчанию показывается).
class OrderStatusBadge extends StatelessWidget {
  final String status;
  final bool showIcon;
  final double fontSize;

  const OrderStatusBadge({
    super.key,
    required this.status,
    this.showIcon = true,
    this.fontSize = 10,
  });

  _StatusVisual _visual(AppColors c, AppLocalizations w) {
    switch (status) {
      case 'published':
        return _StatusVisual(
          color: c.amber,
          bg: c.amberTint,
          label: w.statusFree,
          icon: Icons.search_rounded,
        );
      case 'active':
        return _StatusVisual(
          color: c.ink,
          bg: c.emeraldTint,
          label: w.statusActive,
          icon: Icons.local_shipping_outlined,
        );
      case 'completed':
        return _StatusVisual(
          color: c.ink,
          bg: c.emeraldTint,
          label: w.statusDone,
          icon: Icons.check_circle_outline_rounded,
        );
      case 'canceled':
      default:
        return _StatusVisual(
          color: c.errorMuted,
          bg: c.errorTint,
          label: w.statusCanceled,
          icon: Icons.cancel_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final w = context.watch<LanguageProvider>().words;
    final v = _visual(c, w);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: v.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: v.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(v.icon, size: fontSize, color: v.color),
            const SizedBox(width: 4),
          ],
          Text(
            v.label,
            style: AppText.semiBold(fontSize: fontSize, color: v.color),
          ),
        ],
      ),
    );
  }
}

class _StatusVisual {
  final Color color;
  final Color bg;
  final String label;
  final IconData icon;
  const _StatusVisual({
    required this.color,
    required this.bg,
    required this.label,
    required this.icon,
  });
}
