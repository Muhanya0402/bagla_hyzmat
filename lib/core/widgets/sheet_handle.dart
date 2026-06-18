import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Единый «грабёр» (drag-handle) для bottom-sheet'ов.
///
/// Раньше каждая модалка рисовала свой: 32×3.5, 36×4, 32×4 — визуальный
/// разнобой. Этот компонент — единый источник правды.
///
/// По умолчанию сам добавляет верхний отступ 10 и центрирование, чтобы
/// вставлять одной строкой: `const SheetHandle()`.
class SheetHandle extends StatelessWidget {
  /// Верхний отступ над грабёром. По умолчанию 10.
  final double topPadding;

  /// Нижний отступ под грабёром. По умолчанию 0 (контент сам задаёт).
  final double bottomPadding;

  const SheetHandle({super.key, this.topPadding = 10, this.bottomPadding = 0});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: c.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
