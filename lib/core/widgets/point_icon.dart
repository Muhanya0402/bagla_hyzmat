import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Иконка жетона (Bagla token) — единая точка истины для иконки «жетон» во
/// всём приложении.
///
/// Поведение:
///   - **size ≥ 18** → брендовая PNG-иконка с автопереключением темы:
///       * light theme → `point_icon_light.png` (тёмная монета на светлом UI)
///       * dark theme  → `point_icon_dark.png` (светлая монета на тёмном UI)
///   - **size < 18**  → `Icons.toll_rounded` материальный (детали PNG'и не
///       читаются на маленьком размере, всё равно превратится в кляксу).
///
/// Опциональный `tintColor` влияет ТОЛЬКО на material-fallback (для маленьких
/// размеров). У брендовой PNG свои цвета.
///
/// Использование:
/// ```dart
/// PointIcon(size: 24)             // брендовая иконка
/// PointIcon(size: 13, tintColor: c.amber)  // мелкий чип — material
/// ```
class PointIcon extends StatelessWidget {
  final double size;
  final Color? tintColor;
  const PointIcon({super.key, this.size = 24, this.tintColor});

  /// Граница между «брендовой» и «компактной» отрисовкой.
  static const double _brandedMinSize = 18;

  @override
  Widget build(BuildContext context) {
    // Маленький размер → material icon. Брендовая PNG там не читается.
    if (size < _brandedMinSize) {
      final fallbackColor = tintColor ?? AppColors.of(context).amber;
      return Icon(Icons.toll_rounded, size: size, color: fallbackColor);
    }

    // select вместо watch — этот виджет перерисуется только при смене темы,
    // не на каждый notifyListeners() провайдера.
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDark);
    final asset = isDark
        ? 'assets/images/point_icon_dark.png'
        : 'assets/images/point_icon_light.png';

    return Image.asset(
      asset,
      width: size,
      height: size,
      // На случай если файл не найден / процесс копирования не завершён —
      // не падаем, отдаём fallback на старый ассет, затем на material icon.
      errorBuilder: (_, _, _) => Image.asset(
        'assets/images/point_icon.png',
        width: size,
        height: size,
        errorBuilder: (_, _, _) => Icon(
          Icons.toll_rounded,
          size: size,
          color: tintColor ?? AppColors.of(context).amber,
        ),
      ),
    );
  }
}
