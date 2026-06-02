import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PointIcon extends StatelessWidget {
  final double size;
  final Color? tintColor;
  const PointIcon({super.key, this.size = 24, this.tintColor});

  @override
  Widget build(BuildContext context) {
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
