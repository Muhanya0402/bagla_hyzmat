import 'dart:async';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/point_icon.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Карточка обратного отсчёта до дедлайна доставки (для курьера).
///
/// Изолированный StatefulWidget со своим `Timer.periodic(1s)` и
/// `RepaintBoundary` снаружи — только эта карточка перерисовывается
/// каждую секунду, а не весь экран деталей заказа.
///
/// `onExpired` вызывается **ровно один раз**, когда дедлайн пройден.
class OrderCountdownCard extends StatefulWidget {
  final String? timeOfDelivery;
  final double cashback;
  final AppLocalizations words;
  final VoidCallback onExpired;

  const OrderCountdownCard({
    super.key,
    required this.timeOfDelivery,
    required this.cashback,
    required this.words,
    required this.onExpired,
  });

  @override
  State<OrderCountdownCard> createState() => _OrderCountdownCardState();
}

class _OrderCountdownCardState extends State<OrderCountdownCard> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    final t = widget.timeOfDelivery;
    if (t == null || t.isEmpty) return;
    final deadline = DateTime.parse(t).toLocal();
    // Вычисляем начальное состояние СИНХРОННО (без setState — мы ещё
    // в initState, виджет ещё не смонтирован).
    final diff = deadline.difference(DateTime.now());
    _timeLeft = diff.isNegative ? Duration.zero : diff;
    _isExpired = diff.isNegative;
    if (_isExpired) {
      // Если уже просрочен — нотифицируем parent ПОСЛЕ build'а.
      // Иначе `widget.onExpired()` вызовет parent.setState() прямо во
      // время билда parent'а → "setState called during build" exception.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExpired();
      });
      return; // таймер не нужен — уже просрочено
    }
    // Не просрочен — запускаем периодический tick.
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tick(deadline),
    );
  }

  void _tick(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (!mounted) return;
    final expired = diff.isNegative;
    setState(() {
      _timeLeft = expired ? Duration.zero : diff;
      _isExpired = expired;
    });
    if (expired) {
      _timer?.cancel();
      widget.onExpired();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = _isExpired ? c.errorMuted : c.ink;
    final bg = _isExpired ? c.errorTint : c.emeraldTint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            _isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isExpired
                      ? widget.words.timerExpired
                      : widget.words.timerLabel,
                  style: AppText.regular(fontSize: 10, color: color),
                ),
                Text(
                  _isExpired
                      ? widget.words.cashbackNone
                      : _fmt(_timeLeft),
                  style: AppText.semiBold(fontSize: 16, color: color),
                ),
              ],
            ),
          ),
          if (!_isExpired && widget.cashback > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.amberTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PointIcon(size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '+${widget.cashback}',
                    style: AppText.semiBold(fontSize: 13, color: c.amber),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
