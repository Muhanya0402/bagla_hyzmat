import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Универсальный shimmer-эффект для loading-плейсхолдеров.
///
/// Использует ровно тот же ShaderMask + LinearGradient, что и
/// `_ShimmerList` в `home_orders_list.dart` — визуально все скелетоны
/// в приложении одинаковые, разница только в форме «костей».
///
/// **Использование:**
/// ```dart
/// Shimmer(
///   child: Row(children: [
///     ShimmerBox(width: 40, height: 40, radius: 10),
///     SizedBox(width: 8),
///     ShimmerBox(width: 120, height: 14, radius: 6),
///   ]),
/// );
/// ```
///
/// **Важно:** `ShimmerBox` рендерит **белым** прямоугольник. Шейдер
/// `ShaderMask` поверх с `BlendMode.srcIn` подменяет белый на
/// градиент. Если вместо `ShimmerBox` использовать любой другой
/// цветной виджет — шейдер всё равно перекрасит его в градиент.
class Shimmer extends StatefulWidget {
  final Widget child;

  /// Скорость одного прохода блика. По умолчанию 1300мс — как в
  /// существующем `_ShimmerList`.
  final Duration period;

  /// Если задано — переопределяет базовый цвет (по умолчанию
  /// `AppColors.borderSoft`). Используется в случаях когда нужен
  /// другой контраст под фон.
  final Color? baseColor;

  /// Если задано — переопределяет цвет блика (по умолчанию интерполяция
  /// `borderSoft` → `surface` 78%).
  final Color? highlightColor;

  const Shimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1300),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final base = widget.baseColor ?? c.borderSoft;
    final highlight =
        widget.highlightColor ?? Color.lerp(c.borderSoft, c.surface, 0.78)!;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment(-1.8 + 3.6 * t, 0),
              end: Alignment(-0.8 + 3.6 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Прямоугольная «кость» скелетона. Рендерится **белым** — шейдер
/// родительского `Shimmer` подменит цвет на анимированный градиент.
///
/// `width = double.infinity` — растянуть на ширину родителя.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        // Белый, чтобы BlendMode.srcIn в Shimmer'е перекрасил в градиент.
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
