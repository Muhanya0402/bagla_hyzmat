import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class HomeColors {
  static const Color green = Color(0xFF1A7A3C);
  static const Color red = Color(0xFFD32F1E);
  static const Color yellow = Color(0xFFFFC107);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color border = Color(0xFFEEF0F3);
  static const Color grey = Color(0xFF9AA3AF);
  static const Color dark = Color(0xFF0F1117);
  static const Color accent = Color(0xFFCC785C);

  static const LinearGradient gradient = LinearGradient(
    colors: [green, red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class StatusFilterItem {
  final String label;
  final String? value;
  final Color color;
  const StatusFilterItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

List<StatusFilterItem> getStatusFilters(AppLocalizations words) => [
  StatusFilterItem(
    label: words.statusAllFilter,
    value: null,
    color: HomeColors.grey,
  ),
  StatusFilterItem(
    label: words.statusFreeFilter,
    value: 'published',
    color: const Color.fromARGB(255, 180, 147, 47),
  ),
  StatusFilterItem(
    label: words.statusActiveFilter,
    value: 'active',
    color: HomeColors.dark,
  ),
  StatusFilterItem(
    label: words.statusDoneFilter,
    value: 'completed',
    color: HomeColors.green,
  ),
  StatusFilterItem(
    label: words.statusCanceledFilter,
    value: 'canceled',
    color: HomeColors.red,
  ),
];
