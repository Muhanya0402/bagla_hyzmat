import 'package:flutter/material.dart';

/// Бренд-цвета и градиент — единственный источник правды для home-модуля
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

/// Модель фильтра статуса заказа
class StatusFilter {
  final String label;
  final String? value;
  final Color color;

  const StatusFilter({
    required this.label,
    required this.value,
    required this.color,
  });
}

const List<StatusFilter> kStatusFilters = [
  StatusFilter(label: 'Все', value: null, color: HomeColors.grey),
  StatusFilter(label: 'Свободные', value: 'published', color: HomeColors.red),
  StatusFilter(label: 'В работе', value: 'active', color: HomeColors.green),
  StatusFilter(
    label: 'Доставлены',
    value: 'completed',
    color: HomeColors.green,
  ),
  StatusFilter(label: 'Отменены', value: 'canceled', color: HomeColors.grey),
];
