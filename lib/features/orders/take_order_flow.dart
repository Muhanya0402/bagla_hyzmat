import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/features/orders/widgets/confirm_take_order_dialog.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Единый flow «попытка взять заказ» для курьера/client'а.
///
/// Раньше эта цепочка if'ов жила параллельно в `OrderCard._buildActionButtons`
/// и `OrderDetailScreen._buildActionButton`. Изменение бизнес-правила
/// (например, лимит активных заказов) приходилось править в двух местах.
///
/// Использование:
/// ```dart
/// TakeOrderFlow.tryTake(
///   context,
///   dto: dto,
///   currentUserId: currentUserId,
///   courierPhone: userPhone,
///   role: role,
///   onUpdate: onUpdate,
/// );
/// ```
class TakeOrderFlow {
  TakeOrderFlow._();

  static const int _maxActiveOrders = 3;

  static Future<void> tryTake(
    BuildContext context, {
    required OrderDto dto,
    required String currentUserId,
    required String courierPhone,
    required String role,
    VoidCallback? onUpdate,
  }) async {
    final auth = context.read<AuthProvider>();
    final words = context.read<LanguageProvider>().words;
    final isRu = context.read<LanguageProvider>().isRu;
    final c = AppColors.of(context);

    // 1. Курьер в pending — показываем restricted modal.
    if (auth.isCourier && auth.isPending) {
      _showRestrictedModal(context, onUpdate);
      return;
    }

    // 2. Клиент — направляем выбрать роль.
    if (auth.isClient) {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RolePickerEmbedded(
          onClose: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ).then((_) => onUpdate?.call());
      return;
    }

    // 3. Не активный курьер — ничего не делаем (UI не должен показать кнопку).
    if (!auth.isCourier || !auth.isActive) return;

    // 4. Лимит активных заказов.
    final service = OrderService();
    final activeCount = await service.getActiveOrdersCount(currentUserId);
    if (!context.mounted) return;

    if (activeCount >= _maxActiveOrders) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            words.tooManyOrders,
            style: AppText.regular(fontSize: 13, color: c.errorMuted),
          ),
          backgroundColor: c.errorTint,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // 5. Недостаточно жетонов — открываем top-up.
    if (auth.balancePoints < dto.pointsAmount) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TopUpModal(
          userId: currentUserId,
          role: role,
          status: dto.status,
        ),
      ).then((_) => onUpdate?.call());
      return;
    }

    // 6. Premium confirm + PATCH 'active'.
    final ok = await ConfirmTakeOrderDialog.show(
      context,
      title: words.confirmTitle,
      points: dto.pointsAmount,
      deliveryAmount: dto.deliveryAmount,
      shortOrderId: dto.shortId,
      address: dto.deliveryAddress(isRu),
      words: words,
    );
    if (ok != true || !context.mounted) return;

    try {
      await service.updateStatus(
        dto.id,
        'active',
        userId: currentUserId,
        courierPhone: courierPhone,
      );
      onUpdate?.call();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            words.error,
            style: AppText.regular(fontSize: 13, color: c.errorMuted),
          ),
          backgroundColor: c.errorTint,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  static void _showRestrictedModal(BuildContext context, VoidCallback? onUpdate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              RestrictedAccessView(onActionPressed: () => Navigator.pop(ctx)),
            ],
          ),
        );
      },
    ).then((_) => onUpdate?.call());
  }
}
