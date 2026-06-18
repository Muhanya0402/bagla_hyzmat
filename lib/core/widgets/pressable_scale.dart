import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Универсальный "сжимающийся" wrapper для тач-фидбека.
///
/// Заменяет повсеместный паттерн:
/// ```
/// bool _pressed = false;
/// GestureDetector(
///   onTapDown:   (_) => setState(() => _pressed = true),
///   onTapUp:     (_) { setState(() => _pressed = false); onTap(); },
///   onTapCancel: () => setState(() => _pressed = false),
///   child: AnimatedScale(scale: _pressed ? 0.97 : 1.0, duration: 120ms, child: ...),
/// )
/// ```
///
/// Использование:
/// ```
/// PressableScale(
///   onTap: _doSomething,
///   scale: 0.97,            // опционально
///   child: MyButton(...),
/// )
/// ```
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final Curve curve;
  final HitTestBehavior behavior;

  /// Тактильный фидбек при тапе. По умолчанию выключен (чтобы не вибрировать
  /// на каждой мелкой кнопке). Включай для значимых действий — «Взять заказ»,
  /// «Завершить», «Отменить».
  final HapticFeedbackType? haptic;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 120),
    this.curve = Curves.easeOut,
    this.behavior = HitTestBehavior.opaque,
    this.haptic,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

/// Тип тактильного фидбека для [PressableScale].
enum HapticFeedbackType { light, medium, heavy, selection }

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _fireHaptic() {
    switch (widget.haptic) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              _fireHaptic();
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}
