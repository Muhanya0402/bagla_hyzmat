import 'package:flutter/material.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/l10n/app_localizations.dart';

class HomeSegmentedFilter extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final int filterActiveCount;
  final VoidCallback onFilterTap;
  final AppLocalizations words;

  const HomeSegmentedFilter({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.filterActiveCount,
    required this.onFilterTap,
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HomeColors.border),
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
        const SizedBox(width: 8),
        _FilterIconButton(activeCount: filterActiveCount, onTap: onFilterTap),
      ],
    );
  }
}

class _FilterTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bool sel = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: sel ? HomeColors.gradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppText.medium(
              fontSize: 13,
              color: sel ? Colors.white : HomeColors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterIconButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activeCount > 0
                    ? HomeColors.green.withValues(alpha: 0.4)
                    : HomeColors.border,
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 20,
              color: activeCount > 0 ? HomeColors.green : HomeColors.grey,
            ),
          ),
          if (activeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: HomeColors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$activeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
