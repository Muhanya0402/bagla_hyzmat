import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:provider/provider.dart';

class HomeStatusFilter extends StatelessWidget {
  final String? selectedStatus;
  final ValueChanged<String?> onChanged;
  final Map<String?, int> counts;

  const HomeStatusFilter({
    super.key,
    required this.selectedStatus,
    required this.onChanged,
    this.counts = const {},
  });

  // HomeColors.dark (0xFF0F1117) is the "active" status colour — nearly black.
  // In dark mode it becomes invisible, so we swap it for the theme's ink colour.
  Color _resolveColor(Color raw, BuildContext context) {
    if (raw == HomeColors.dark) return AppColors.of(context).ink;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    final filters = getStatusFilters(words);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: filters.map((f) {
          final bool sel = selectedStatus == f.value;
          final int? count = counts[f.value];
          final Color color = _resolveColor(f.color, context);

          return GestureDetector(
            onTap: () => onChanged(f.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel
                    ? color.withValues(alpha: 0.1)
                    : AppColors.of(context).surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? color.withValues(alpha: 0.4)
                      : AppColors.of(context).border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sel) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    f.label,
                    style: sel
                        ? AppText.semiBold(fontSize: 12, color: color)
                        : AppText.medium(
                            fontSize: 12,
                            color: AppColors.of(context).inkSoft,
                          ),
                  ),
                  // ← счётчик
                  if (count != null && count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? color.withValues(alpha: 0.15)
                            : AppColors.of(context).border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: AppText.semiBold(
                          fontSize: 11,
                          color: sel ? color : AppColors.of(context).inkSoft,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
