import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home/home_screen.dart';

class OrderCard extends StatelessWidget {
  final dynamic order;
  final String role;
  final String currentUserId;
  final VoidCallback? onUpdate;
  final VoidCallback? onTap;
  final String userPhone;

  const OrderCard({
    super.key,
    required this.order,
    required this.currentUserId,
    this.role = 'courier',
    this.onUpdate,
    this.onTap,
    required this.userPhone,
  });

  // ── Confirm dialog ─────────────────────────────────────────────────────────
  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required Color actionColor,
    required Future<void> Function() action,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient accent bar
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: HomeScreen.brandGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppText.semiBold(fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF9AA3AF),
                ).copyWith(height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Cancel
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFEEF0F3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Назад',
                          style: AppText.medium(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Confirm
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              actionColor,
                              actionColor.withOpacity(0.75),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Да',
                          style: AppText.medium(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await action();
        if (onUpdate != null) onUpdate!();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ошибка сети. Попробуйте позже.',
                style: AppText.regular(fontSize: 13, color: Colors.white),
              ),
              backgroundColor: HomeScreen.brandRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  void _showRestrictedModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
            _sheetHandle(),
            const SizedBox(height: 24),
            RestrictedAccessView(onActionPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    ).then((_) => onUpdate?.call()); // ← авто-рефреш
  }

  // ── Main build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final status = (order['status'] ?? order['order_status'] ?? 'published')
        .toString()
        .toLowerCase();
    final isShop = role == 'shop';
    final String orderId = order['id'].toString();
    final bool isDataLocked = !isShop && status == 'published';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF0F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          splashColor: HomeScreen.brandGreen.withOpacity(0.04),
          highlightColor: Colors.transparent,
          child: Column(
            children: [
              // ── Top gradient strip (status-coloured) ────────────────────
              _StatusStrip(status: status),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [_buildOrderId(), _buildStatusBadge(status)],
                    ),
                    const SizedBox(height: 18),
                    _buildRouteTimeline(
                      shopAddress: order['shop_adress'] ?? 'Адрес магазина',
                      deliveryAddress:
                          order['adress_of_delivery'] ?? 'Адрес доставки',
                      district: order['district'], // 👈 добавить
                      isLocked: isDataLocked,
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Color(0xFFF1F4F8), height: 1),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPriceSection(isShop, order),
                    _buildActionButtons(
                      context,
                      status,
                      orderId,
                      isShop,
                      currentUserId,
                      userPhone,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Action buttons (logic preserved exactly) ───────────────────────────────
  Widget _buildActionButtons(
    BuildContext context,
    String status,
    String orderId,
    bool isShop,
    String userId,
    String userPhone,
  ) {
    final OrderService service = OrderService();

    if (status == 'completed' || status == 'canceled') {
      return const SizedBox();
    }

    // Shop: cancel button
    if (isShop && (status == 'published' || status == 'active')) {
      return _buildOutlineButton(
        label: 'Отменить',
        color: HomeScreen.brandRed,
        onTap: () => _showCancelReasonModal(context, orderId, service),
      );
    }

    // Courier: take order
    if (!isShop && status == 'published') {
      final int points = order['points_amount'] ?? 0;
      final authProv = context.watch<AuthProvider>();
      final double balancePoints = authProv.balancePoints;

      final bool isRestricted =
          authProv.role == 'courier' && authProv.status == 'pending';
      final bool isUserActive =
          authProv.role == 'courier' && authProv.status == 'active';
      final bool isClient = authProv.role == 'client';

      return _buildFilledButton(
        label: 'Взять',
        points: points,
        balancePoints: balancePoints,
        color: HomeScreen.brandGreen,
        onTap: () {
          if (isRestricted) {
            _showRestrictedModal(context);
          } else if (isUserActive) {
            if (balancePoints >= points) {
              _confirmAction(
                context: context,
                title: 'Принять заказ',
                message: points > 0
                    ? 'С вашего баланса будет списано $points баллов. Приступить?'
                    : 'Заказ будет закреплён за вами. Приступить?',
                actionColor: HomeScreen.brandGreen,
                action: () => service.updateStatus(
                  orderId,
                  'active',
                  userId: currentUserId,
                  courierPhone: userPhone,
                ),
              );
            } else {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                builder: (_) =>
                    TopUpModal(userId: userId, role: role, status: status),
              ).then((_) => onUpdate?.call()); // ← авто-рефреш
            }
          } else if (isClient) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              builder: (_) =>
                  RolePickerEmbedded(onClose: () => Navigator.pop(context)),
            ).then((_) => onUpdate?.call()); // ← авто-рефреш
          }
        },
      );
    }

    // Courier: delivered button
    if (status == 'active' && role == 'courier') {
      final double cashback = (order['cashback_amount'] ?? 0.0).toDouble();
      return _buildFilledButton(
        label: 'Доставлено',
        color: HomeScreen.brandGreen,
        cashback: cashback,
        onTap: () => onTap?.call(),
      );
    }

    return const SizedBox();
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildRouteTimeline({
    required String shopAddress,
    required String deliveryAddress,
    required dynamic district, // 👈 добавить
    required bool isLocked,
  }) {
    // Формируем итоговый адрес "Куда"
    String districtName = '';
    if (district is Map) {
      districtName = district['district_ru']?.toString() ?? '';
    }
    final String fullDeliveryAddress = districtName.isNotEmpty
        ? '$districtName, $deliveryAddress'
        : deliveryAddress;

    return Column(
      children: [
        _buildPoint(
          icon: Icons.inventory_2_outlined,
          label: 'Откуда',
          address: shopAddress,
          iconColor: HomeScreen.brandRed,
          iconBg: HomeScreen.brandRed.withOpacity(0.08),
        ),
        const SizedBox(height: 12),
        _buildPoint(
          icon: isLocked
              ? Icons.lock_outline_rounded
              : Icons.location_on_outlined,
          label: 'Куда',
          address: isLocked
              ? 'Адрес скрыт до принятия'
              : fullDeliveryAddress, // 👈
          iconColor: isLocked ? const Color(0xFF9AA3AF) : HomeScreen.brandGreen,
          iconBg: isLocked
              ? const Color(0xFF9AA3AF).withOpacity(0.08)
              : HomeScreen.brandGreen.withOpacity(0.08),
          isGrey: isLocked,
        ),
      ],
    );
  }

  void _showCancelReasonModal(
    BuildContext context,
    String orderId,
    OrderService service,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CancelReasonModal(
        orderId: orderId,
        currentUserId: currentUserId,
        service: service,
        onSuccess: () => onUpdate?.call(),
      ),
    ).then((_) => onUpdate?.call()); // ← авто-рефреш
  }

  Widget _buildPoint({
    required IconData icon,
    required String label,
    required String address,
    required Color iconColor,
    required Color iconBg,
    bool isGrey = false,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.regular(
                  fontSize: 11,
                  color: const Color(0xFF9AA3AF),
                ),
              ),
              Text(
                address,
                style: AppText.medium(
                  fontSize: 14,
                  color: isGrey
                      ? const Color(0xFF9AA3AF)
                      : const Color(0xFF0F1117),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection(bool isShop, dynamic order) {
    final double total = (order['total_amount'] ?? 0.0).toDouble();
    final double delivery = (order['delivery_amount'] ?? 0.0).toDouble();
    final double amount = isShop ? (total - delivery) : delivery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isShop ? 'К получению' : 'За доставку',
          style: AppText.regular(fontSize: 11, color: const Color(0xFF9AA3AF)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            ShaderMask(
              shaderCallback: (b) => HomeScreen.brandGradient.createShader(b),
              child: Text(
                amount.toStringAsFixed(0),
                style: AppText.semiBold(fontSize: 24, color: Colors.white),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'TMT',
              style: AppText.regular(
                fontSize: 12,
                color: HomeScreen.brandGreen.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderId() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'ID: ${order['id'].toString().split('-').first.toUpperCase()}',
        style: AppText.medium(fontSize: 11, color: const Color(0xFF9AA3AF)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    const styles = {
      'published': _BadgeStyle(
        color: HomeScreen.brandRed,
        label: 'Свободный',
        icon: Icons.search_rounded,
      ),
      'active': _BadgeStyle(
        color: HomeScreen.brandGreen,
        label: 'В работе',
        icon: Icons.local_shipping_outlined,
      ),
      'canceled': _BadgeStyle(
        color: Color(0xFF9AA3AF),
        label: 'Отменён',
        icon: Icons.cancel_outlined,
      ),
      'completed': _BadgeStyle(
        color: HomeScreen.brandGreen,
        label: 'Доставлен',
        icon: Icons.check_circle_outline_rounded,
      ),
    };
    final s = styles[status] ?? styles['canceled']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 12, color: s.color),
          const SizedBox(width: 5),
          Text(s.label, style: AppText.semiBold(fontSize: 11, color: s.color)),
        ],
      ),
    );
  }

  Widget _buildFilledButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    int points = 0,
    double balancePoints = 0,
    double cashback = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.semiBold(fontSize: 13, color: Colors.white),
            ),
            if (points > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 14,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/point_icon.png',
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Text(
                '$points',
                style: AppText.regular(fontSize: 13, color: Colors.white),
              ),
            ],
            if (cashback > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 14,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/point_icon.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Text(
                '+${cashback.toDouble()}',
                style: AppText.regular(fontSize: 13, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppText.medium(fontSize: 13, color: color)),
      ),
    );
  }

  Widget _sheetHandle() => Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: const Color(0xFFEEF0F3),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

// ── Thin gradient strip at top of card ───────────────────────────────────────
class _StatusStrip extends StatelessWidget {
  final String status;
  const _StatusStrip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color left, right;
    switch (status) {
      case 'active':
        left = right = HomeScreen.brandGreen;
        break;
      case 'canceled':
        left = right = const Color(0xFF9AA3AF);
        break;
      case 'completed':
        left = right = HomeScreen.brandGreen;
        break;
      default: // published
        left = HomeScreen.brandGreen;
        right = HomeScreen.brandRed;
    }
    return Container(
      height: 3,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [left, right]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

class _BadgeStyle {
  final Color color;
  final String label;
  final IconData icon;
  const _BadgeStyle({
    required this.color,
    required this.label,
    required this.icon,
  });
}
