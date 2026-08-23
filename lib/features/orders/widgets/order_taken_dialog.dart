import 'dart:ui';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/pressable_scale.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Диалог «этот заказ уже взят».
///
/// Показывается курьеру, который нажал «Взять» вторым: его список не успел
/// обновиться, заказ на сервере уже закреплён за другим. Раньше тут была
/// всплывающая строка внизу экрана — её легко не заметить, а человек в этот
/// момент уверен, что заказ его. Поэтому именно диалог: он требует закрыть
/// себя руками и не даёт пропустить, что заказ не достался.
///
/// Отдельно говорим про жетоны — это первый вопрос, который возникает.
class OrderTakenDialog extends StatelessWidget {
  final AppLocalizations words;

  const OrderTakenDialog({super.key, required this.words});

  static Future<void> show(BuildContext context, AppLocalizations words) {
    return showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withValues(alpha: 0.28)),
          ),
          Center(child: OrderTakenDialog(words: words)),
        ],
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.ink.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.amberTint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_off_outlined,
                  size: 24,
                  color: c.amber,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                words.orderAlreadyTaken,
                textAlign: TextAlign.center,
                style: AppText.serif(fontSize: 17, color: c.ink),
              ),
              const SizedBox(height: 8),
              Text(
                words.orderAlreadyTakenBody,
                textAlign: TextAlign.center,
                style: AppText.regular(
                  fontSize: 13,
                  color: c.inkMuted,
                ).copyWith(height: 1.45),
              ),
              const SizedBox(height: 18),
              PressableScale(
                onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                scale: 0.97,
                child: Container(
                  height: 46,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    words.gotIt,
                    style: AppText.semiBold(fontSize: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
