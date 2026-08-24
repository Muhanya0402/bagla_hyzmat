import 'package:bagla/core/app_settings_provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Отказ курьера от взятого заказа.
///
/// Всю проверку делает сервер: он же определяет курьера по авторизации,
/// сверяет, что заказ действительно его, и следит за суточным лимитом.
/// Приложение только показывает причины и разбирает ответ — по тем же
/// соображениям, по которым на сервер уехало взятие заказа.
class ReturnOrderFlow {
  ReturnOrderFlow._();

  static Future<void> start(
    BuildContext context, {
    required OrderDto dto,
    VoidCallback? onUpdate,
  }) async {
    final words = context.read<LanguageProvider>().words;
    final c = AppColors.of(context);
    final service = OrderService();

    // Предупреждение про жетон показываем, только когда он реально сгорит:
    // при выключенном пополнении и на бесплатных заказах терять нечего.
    final tokensLive = context.read<AppSettingsProvider>().topUpEnabled;
    final subtitle = (tokensLive && dto.pointsAmount > 0)
        ? '${words.returnOrderSubtitle}. ${words.returnOrderTokenWarning}'
        : words.returnOrderSubtitle;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => CancelReasonModal(
        words: words,
        title: words.returnOrderTitle,
        subtitle: subtitle,
        confirmLabel: words.returnOrderConfirm,
        reasons: [
          ReasonOption(id: 'breakdown',
              label: words.returnReasonBreakdown, icon: Icons.car_repair_outlined),
          ReasonOption(id: 'illness',
              label: words.returnReasonIllness, icon: Icons.sick_outlined),
          ReasonOption(id: 'no_time',
              label: words.returnReasonNoTime, icon: Icons.schedule_rounded),
          ReasonOption(id: 'other',
              label: words.cancelReasonOther, icon: Icons.more_horiz_rounded),
        ],
        onSubmit: (reasonId, comment) async {
          final (outcome, left) = await service.returnOrder(
            orderId: dto.id, reason: reasonId, comment: comment);
          if (!sheetCtx.mounted) return outcome == ReturnOutcome.returned;

          final messenger = ScaffoldMessenger.of(sheetCtx);
          switch (outcome) {
            case ReturnOutcome.returned:
              messenger.showSnackBar(SnackBar(
                content: Text('${words.returnOrderDone}. '
                    '${words.returnsLeft.replaceAll('{n}', '$left')}',
                    style: AppText.regular(fontSize: 13)),
                behavior: SnackBarBehavior.floating,
              ));
              onUpdate?.call();
              return true;
            case ReturnOutcome.limitReached:
              _err(messenger, words.returnLimitReached, c);
              return false;
            case ReturnOutcome.notYourOrder:
              _err(messenger, words.returnNotYourOrder, c);
              onUpdate?.call();
              return false;
            case ReturnOutcome.error:
              _err(messenger, words.error, c);
              return false;
          }
        },
      ),
    );
  }

  static void _err(ScaffoldMessengerState m, String text, AppColors c) {
    m.showSnackBar(SnackBar(
      content: Text(text, style: AppText.regular(fontSize: 13, color: c.errorMuted)),
      backgroundColor: c.errorTint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}
