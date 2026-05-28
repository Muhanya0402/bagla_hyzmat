import 'package:flutter/material.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/app_localizations.dart';

class HomeSegmentedFilter extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final int filterActiveCount;
  final VoidCallback onFilterTap;
  final AppLocalizations words;
  final bool showFilter;

  const HomeSegmentedFilter({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.filterActiveCount,
    required this.onFilterTap,
    required this.words,
    this.showFilter = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.borderSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _FilterTab(
                  index: 0,
                  label: words.availiblorders,
                  selectedIndex: selectedIndex,
                  onTap: onChanged,
                ),
                _FilterTab(
                  index: 1,
                  label: words.myOrders,
                  selectedIndex: selectedIndex,
                  onTap: onChanged,
                ),
              ],
            ),
          ),
        ),
        if (showFilter) ...[
          const SizedBox(width: 8),
          _FilterIconButton(activeCount: filterActiveCount, onTap: onFilterTap),
        ],
      ],
    );
  }
}

// ── Single tab segment ────────────────────────────────────────────────────────

class _FilterTab extends StatefulWidget {
  final int index;
  final String label;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FilterTab({
    required this.index,
    required this.label,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<_FilterTab> createState() => _FilterTabState();
}

class _FilterTabState extends State<_FilterTab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bool sel = widget.selectedIndex == widget.index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap(widget.index);
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? c.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: c.ink.withValues(alpha: 0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              style: sel
                  ? AppText.semiBold(fontSize: 13, color: c.ink)
                  : AppText.medium(fontSize: 13, color: c.inkSoft),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter icon button ────────────────────────────────────────────────────────

class _FilterIconButton extends StatefulWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterIconButton({
    required this.activeCount,
    required this.onTap,
  });

  @override
  State<_FilterIconButton> createState() => _FilterIconButtonState();
}

class _FilterIconButtonState extends State<_FilterIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bool has = widget.activeCount > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: has ? c.emeraldTint : c.borderSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: has
                  ? c.emerald.withValues(alpha: 0.3)
                  : c.border,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: has ? c.emerald : c.inkSoft,
              ),
              if (has)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: c.emerald,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.activeCount}',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
