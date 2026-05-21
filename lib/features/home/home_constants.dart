import 'package:flutter/material.dart';

class HomeColors {
  static const Color green = Color(0xFF1A7A3C);
  static const Color red = Color(0xFFD32F1E);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color border = Color(0xFFEEF0F3);
  static const Color grey = Color(0xFF9AA3AF);
  static const Color dark = Color(0xFF0F1117);

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

const List<StatusFilterItem> kStatusFilters = [
  StatusFilterItem(label: 'Все', value: null, color: HomeColors.grey),
  StatusFilterItem(
    label: 'Свободные',
    value: 'published',
    color: HomeColors.red,
  ),
  StatusFilterItem(label: 'В работе', value: 'active', color: HomeColors.green),
  StatusFilterItem(
    label: 'Доставлены',
    value: 'completed',
    color: HomeColors.green,
  ),
  StatusFilterItem(
    label: 'Отменены',
    value: 'canceled',
    color: HomeColors.grey,
  ),
];
