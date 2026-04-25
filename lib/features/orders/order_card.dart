import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required Color actionColor,
    required Future<void> Function() action,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF9AA3AF),
            height: 1.5,
          ),
        ),
        actions: [
          Row(
            children: [
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
                      "Назад",
                      style: GoogleFonts.inter(
                        color: const Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: actionColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Да",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
                "Ошибка сети. Попробуйте позже.",
                style: GoogleFonts.inter(fontSize: 13),
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
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            RestrictedAccessView(onActionPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

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
        border: Border.all(color: const Color(0xFFEEF0F3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          splashColor: HomeScreen.brandGreen.withOpacity(0.04),
          highlightColor: Colors.transparent,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [_buildOrderId(), _buildStatusBadge(status)],
                    ),
                    const SizedBox(height: 20),
                    _buildRouteTimeline(
                      shopAddress: order['shop_adress'] ?? 'Адрес магазина',
                      deliveryAddress:
                          order['adress_of_delivery'] ?? 'Адрес доставки',
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

  Widget _buildActionButtons(
    BuildContext context,
    String status,
    String orderId,
    bool isShop,
    String userId,
    String userPhone,
  ) {
    final OrderService service = OrderService();

    if (status == 'completed' || status == 'canceled') return const SizedBox();

    // 1. Если это МАГАЗИН и заказ еще свободен — кнопка отмены
    // СТАЛО:
    if (isShop && status == 'published') {
      return _buildOutlineButton(
        label: "Отменить",
        color: HomeScreen.brandRed,
        onTap: () => _showCancelReasonModal(context, orderId, service),
      );
    }

    // 2. Если заказ СВОБОДЕН и смотрит КУРЬЕР — кнопка "Взять"
    if (!isShop && status == 'published') {
      final int points = order['points_amount'] ?? 0;
      final authProv = context.watch<AuthProvider>();
      final balancePoints = authProv.balancePoints;

      final bool isRestricted =
          (authProv.role == 'courier' && authProv.status == 'pending');

      final bool isUserActive =
          (authProv.role == 'courier' && authProv.status == 'active');

      final bool isClient = authProv.role == 'client';

      return _buildFilledButton(
        label: "Взять",
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
                title: "Принять заказ",
                message: points > 0
                    ? "С вашего баланса будет списано $points баллов. Приступить?"
                    : "Заказ будет закреплён за вами. Приступить?",
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
                builder: (_) =>
                    TopUpModal(userId: userId, role: role, status: status),
              );
            }
          } else if (isClient) {
            showModalBottomSheet(
              context: context,
              builder: (_) =>
                  RolePickerEmbedded(onClose: () => Navigator.pop(context)),
            );
          }
        },
      );
    }

    // 3. Если заказ В РАБОТЕ (status == 'active') — кнопки "Отменить" и "Доставлено"
    if (status == 'active' && role == 'courier') {
      final double cashback = (order['cashback_amount'] ?? 0.0).toDouble();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8),
          _buildFilledButton(
            label: "Доставлено",
            color: HomeScreen.brandBlue,
            cashback: cashback,
            onTap: () => onTap
                ?.call(), // открываем OrderDetailScreen где есть полная логика
          ),
        ],
      );
    }

    return const SizedBox();
  }

  Widget _buildFilledButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    int points = 0,
    int balancePoints = 0,
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
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
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
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Text(
                "$points",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
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
                'assets/images/point_icon.png', // Используем тот же путь к ассету
                width: 26,
                height: 26,
                colorBlendMode: BlendMode
                    .srcIn, // Позволяет перекрасить иконку, сохраняя её форму
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Text(
                "+${cashback.toDouble()}",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRouteTimeline({
    required String shopAddress,
    required String deliveryAddress,
    required bool isLocked,
  }) {
    return Column(
      children: [
        _buildPoint(
          icon: Icons.inventory_2_outlined,
          label: "Откуда",
          address: shopAddress,
          iconColor: HomeScreen.brandRed,
          iconBg: HomeScreen.brandRed.withOpacity(0.08),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 17),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 2,
              height: 18,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [HomeScreen.brandRed, HomeScreen.brandGreen],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        _buildPoint(
          icon: isLocked
              ? Icons.lock_outline_rounded
              : Icons.location_on_outlined,
          label: "Куда",
          address: isLocked ? "Адрес скрыт до принятия" : deliveryAddress,
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
        currentUserId: currentUserId, // или widget.currentUserId
        service: service,
        onSuccess: () {
          if (onUpdate != null) onUpdate!(); // или widget.onUpdate
          if (context.mounted) Navigator.pop(context); // только в DetailScreen
        },
      ),
    );
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
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF9AA3AF),
                ),
              ),
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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
          isShop ? "К получению" : "За доставку",
          style: GoogleFonts.inter(
            color: const Color(0xFF9AA3AF),
            fontSize: 11,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              amount.toStringAsFixed(0),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: HomeScreen.brandBlue,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              "TMT",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: HomeScreen.brandBlue.withOpacity(0.4),
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
        "ID: ${order['id'].toString().split('-').first.toUpperCase()}",
        style: GoogleFonts.inter(
          color: const Color(0xFF9AA3AF),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Map<String, _BadgeStyle> styles = {
      'published': _BadgeStyle(
        color: HomeScreen.brandRed,
        label: "Свободный",
        icon: Icons.search_rounded,
      ),
      'active': _BadgeStyle(
        color: HomeScreen.brandBlue,
        label: "В работе",
        icon: Icons.local_shipping_outlined,
      ),
      'canceled': _BadgeStyle(
        color: const Color(0xFF9AA3AF),
        label: "Отменён",
        icon: Icons.cancel_outlined,
      ),
      'completed': _BadgeStyle(
        color: HomeScreen.brandGreen,
        label: "Доставлен",
        icon: Icons.check_circle_outline_rounded,
      ),
    };
    final style = styles[status] ?? styles['canceled']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.color),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: GoogleFonts.inter(
              color: style.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
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
