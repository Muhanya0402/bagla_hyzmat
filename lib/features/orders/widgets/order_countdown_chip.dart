import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/countdown_ticker.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Компактный обратный отсчёт для карточки заказа в ленте.
///
/// То же, что крупная карточка отсчёта в деталях заказа, но в одну строку —
/// и без собственного таймера: секунды приходят от общего тикера, один на всё
/// приложение.
///
/// Что сделано ради плавности в длинном списке:
///   * `AnimatedBuilder` слушает общий тикер и перестраивает **только** эту
///     строку, а не карточку целиком;
///   * `RepaintBoundary` держит перерисовку внутри своих границ — соседние
///     карточки не трогаются;
///   * дата разбирается один раз при создании, а не каждую секунду;
///   * цифры моноширинные, поэтому строка не «дышит» по ширине и не заставляет
///     пересчитывать раскладку на каждом тике.
class OrderCountdownChip extends StatefulWidget {
  final String? timeOfDelivery;
  final AppLocalizations words;

  const OrderCountdownChip({
    super.key,
    required this.timeOfDelivery,
    required this.words,
  });

  @override
  State<OrderCountdownChip> createState() => _OrderCountdownChipState();
}

class _OrderCountdownChipState extends State<OrderCountdownChip> {
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(OrderCountdownChip old) {
    super.didUpdateWidget(old);
    if (old.timeOfDelivery != widget.timeOfDelivery) _parse();
  }

  void _parse() {
    final t = widget.timeOfDelivery;
    if (t == null || t.isEmpty) {
      _deadline = null;
      return;
    }
    _deadline = DateTime.tryParse(t)?.toLocal();
  }

  /// `1:05:09` для длинных сроков и `05:09` для последнего часа.
  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final deadline = _deadline;
    if (deadline == null) return const SizedBox.shrink();

    final c = AppColors.of(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: CountdownTicker.instance,
        builder: (context, _) {
          final left = deadline.difference(DateTime.now());
          final expired = left.isNegative;

          // Последние пять минут подсвечиваем: в ленте это единственный
          // способ заметить, что заказ вот-вот протухнет.
          final urgent = !expired && left.inMinutes < 5;
          final color =
              expired ? c.errorMuted : (urgent ? c.errorMuted : c.inkMuted);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                expired ? Icons.timer_off_rounded : Icons.timer_outlined,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                expired ? widget.words.timerExpired : _fmt(left),
                style: AppText.semiBold(fontSize: 12, color: color).copyWith(
                  // Моноширинные цифры: ширина строки не скачет на каждом
                  // тике, значит раскладка карточки не пересчитывается.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
