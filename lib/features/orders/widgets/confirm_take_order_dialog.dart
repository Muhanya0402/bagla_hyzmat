import 'dart:ui';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/point_icon.dart';
import 'package:bagla/core/widgets/pressable_scale.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Premium-диалог подтверждения «Взять заказ».
///
/// Открывается через `showGeneralDialog` с blur-barrier и scale-анимацией.
/// Возвращает `true`, если пользователь подтвердил, иначе `false`/`null`.
///
/// Использование:
/// ```dart
/// final ok = await ConfirmTakeOrderDialog.show(
///   context,
///   title: words.confirmTitle,
///   points: dto.pointsAmount,
///   deliveryAmount: dto.deliveryAmount,
///   shortOrderId: dto.shortId,
///   address: dto.deliveryAddress(isRu),
///   words: words,
/// );
/// if (ok == true) { /* действие */ }
/// ```
class ConfirmTakeOrderDialog extends StatelessWidget {
  final String title;
  final int points;
  final double deliveryAmount;
  final String shortOrderId;
  final String address;
  final AppLocalizations words;

  const ConfirmTakeOrderDialog({
    super.key,
    required this.title,
    required this.points,
    required this.deliveryAmount,
    required this.shortOrderId,
    required this.address,
    required this.words,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required int points,
    required double deliveryAmount,
    required String shortOrderId,
    required String address,
    required AppLocalizations words,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => Stack(
        children: [
          BackdropFilter(
            // sigma 2 для производительности на старых девайсах.
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withValues(alpha: 0.28)),
          ),
          Center(
            child: ConfirmTakeOrderDialog(
              title: title,
              points: points,
              deliveryAmount: deliveryAmount,
              shortOrderId: shortOrderId,
              address: address,
              words: words,
            ),
          ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.serif(fontSize: 17, color: c.ink),
                  ),
                  const SizedBox(height: 10),
                  // Delivery + points summary card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.borderSoft),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                words.deliveryFee,
                                style: AppText.regular(
                                  fontSize: 10,
                                  color: c.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '+${deliveryAmount.toStringAsFixed(0)}',
                                    style: AppText.semiBold(
                                      fontSize: 18,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'TMT',
                                    style: AppText.regular(
                                      fontSize: 10,
                                      color: c.ink.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (points > 0) ...[
                          Container(
                            width: 0.5,
                            height: 32,
                            color: c.borderSoft,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: c.amberTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PointIcon(size: 13, tintColor: c.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '-$points',
                                  style: AppText.semiBold(
                                    fontSize: 13,
                                    color: c.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Route summary
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.route_outlined,
                          size: 12,
                          color: c.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'ID: $shortOrderId • $address',
                          style: AppText.regular(
                            fontSize: 11,
                            color: c.inkMuted,
                          ).copyWith(height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: c.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  // Cancel
                  PressableScale(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: c.borderSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        words.back,
                        style: AppText.medium(fontSize: 13, color: c.inkMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Confirm
                  Expanded(
                    child: PressableScale(
                      onTap: () => Navigator.pop(context, true),
                      curve: Curves.easeOutBack,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.ink,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: c.ink.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          words.takeOrder,
                          style: AppText.semiBold(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
