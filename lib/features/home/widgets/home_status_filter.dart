import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:provider/provider.dart';

class HomeStatusFilter extends StatefulWidget {
  final String? selectedStatus;
  final ValueChanged<String?> onChanged;
  final Map<String?, int> counts;

  /// Значения статусов, которые НЕ показывать. Например, для курьера во
  /// вкладке «Мои заказы» прячем 'published' («Свободные») — взятый заказ
  /// не может быть свободным.
  final Set<String?> excludeValues;

  /// Желаемый порядок значений статусов. Если задан — чипы пересортируются
  /// по нему (значения вне списка уходят в конец). Например, у курьера в
  /// «Мои заказы»: «В работе» первым, «Все» последним.
  final List<String?>? order;

  const HomeStatusFilter({
    super.key,
    required this.selectedStatus,
    required this.onChanged,
    this.counts = const {},
    this.excludeValues = const {},
    this.order,
  });

  @override
  State<HomeStatusFilter> createState() => _HomeStatusFilterState();
}

class _HomeStatusFilterState extends State<HomeStatusFilter> {
  final ScrollController _scrollCtrl = ScrollController();
  // GlobalKey на каждый чип (по значению статуса) — для ensureVisible.
  final Map<String?, GlobalKey> _chipKeys = {};

  @override
  void initState() {
    super.initState();
    // Первый кадр: подвести выбранный чип в зону видимости.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(HomeStatusFilter old) {
    super.didUpdateWidget(old);
    // Статус сменился (тап/свайп) — центрируем новый активный чип.
    if (old.selectedStatus != widget.selectedStatus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!mounted) return;
    final ctx = _chipKeys[widget.selectedStatus]?.currentContext;
    if (ctx == null) return;
    // alignment 0.5 — центрируем активный чип по горизонтали.
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  // HomeColors.dark (0xFF0F1117) is the "active" status colour — nearly black.
  // In dark mode it becomes invisible, so we swap it for the theme's ink colour.
  Color _resolveColor(Color raw, BuildContext context) {
    if (raw == HomeColors.dark) return AppColors.of(context).ink;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    final filters = getStatusFilters(words)
        .where((f) => !widget.excludeValues.contains(f.value))
        .toList();
    final order = widget.order;
    if (order != null) {
      int rank(String? v) {
        final i = order.indexOf(v);
        return i < 0 ? 9999 : i;
      }

      filters.sort((a, b) => rank(a.value).compareTo(rank(b.value)));
    }
    return SingleChildScrollView(
      controller: _scrollCtrl,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: filters.map((f) {
          final bool sel = widget.selectedStatus == f.value;
          final key = _chipKeys.putIfAbsent(f.value, () => GlobalKey());
          final int? count = widget.counts[f.value];
          final Color color = _resolveColor(f.color, context);

          return GestureDetector(
            key: key,
            onTap: () => widget.onChanged(f.value),
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
