import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Чип фильтра локации (велаят / этрап / район)
class LocationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isFixed; // велаят — некликабельный
  final bool isActive; // значение выбрано
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const LocationChip({
    super.key,
    required this.icon,
    required this.label,
    this.isFixed = false,
    this.isActive = false,
    this.isLoading = false,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isFixed
        ? const Color(0xFFF0F2F7)
        : isActive
        ? HomeColors.green.withValues(alpha: 0.08)
        : Colors.white;
    final Color border = isFixed
        ? HomeColors.border
        : isActive
        ? HomeColors.green.withValues(alpha: 0.3)
        : HomeColors.border;
    final Color textColor = isFixed
        ? HomeColors.grey
        : isActive
        ? HomeColors.green
        : HomeColors.dark;

    return GestureDetector(
      onTap: isFixed ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: isLoading
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: textColor,
                      ),
                    )
                  : Text(
                      label,
                      style: AppText.semiBold(fontSize: 12, color: textColor),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
            ),
            if (!isFixed && !isLoading) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: textColor,
              ),
            ],
            if (onClear != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 13, color: textColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Элемент для picker'а
class PickerItem {
  final String id;
  final String label;
  const PickerItem({required this.id, required this.label});
}

/// Боттом-шит выбора этрапа или района
class LocationPickerSheet extends StatefulWidget {
  final String title;
  final bool isLoading;
  final List<PickerItem> items;
  final String? selectedId;
  final void Function(String id) onSelect;
  final VoidCallback? onClear;

  const LocationPickerSheet({
    super.key,
    required this.title,
    required this.isLoading,
    required this.items,
    required this.onSelect,
    this.selectedId,
    this.onClear,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    final filtered = widget.items
        .where((i) => i.label.toLowerCase().contains(_q))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, sc) => Column(
        children: [
          const SizedBox(height: 10),
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: HomeColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: AppText.bold(fontSize: 16, color: HomeColors.dark),
                ),
                const Spacer(),
                if (widget.onClear != null)
                  GestureDetector(
                    onTap: widget.onClear,
                    child: Text(
                      words.filterReset,
                      style: AppText.medium(
                        fontSize: 13,
                        color: HomeColors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Поиск
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
              style: AppText.regular(fontSize: 14, color: HomeColors.dark),
              decoration: InputDecoration(
                hintText: words.filterSearchHint,
                hintStyle: AppText.regular(
                  fontSize: 14,
                  color: HomeColors.grey,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: HomeColors.grey,
                  size: 20,
                ),
                suffixIcon: _q.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _q = '');
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: HomeColors.grey,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: HomeColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: HomeColors.border),
          // Список
          Expanded(
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: HomeColors.green,
                      strokeWidth: 2,
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      words.filterNotFound,
                      style: AppText.regular(
                        fontSize: 14,
                        color: HomeColors.grey,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 52,
                      color: Color(0xFFF4F5F7),
                    ),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final isActive = item.id == widget.selectedId;
                      return InkWell(
                        onTap: () => widget.onSelect(item.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? HomeColors.green.withValues(alpha: 0.08)
                                      : HomeColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.check_rounded
                                      : Icons.location_on_outlined,
                                  size: 16,
                                  color: isActive
                                      ? HomeColors.green
                                      : HomeColors.grey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: isActive
                                      ? AppText.semiBold(
                                          fontSize: 14,
                                          color: HomeColors.dark,
                                        )
                                      : AppText.regular(
                                          fontSize: 14,
                                          color: HomeColors.dark,
                                        ),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: HomeColors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
