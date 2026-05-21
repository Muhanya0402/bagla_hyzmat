import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: HomeColors.gradient,
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
                          style: AppText.medium(color: HomeColors.grey),
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
                          gradient: LinearGradient(
                            colors: [
                              actionColor,
                              actionColor.withValues(alpha: 0.75),
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
              backgroundColor: HomeColors.red,
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
    ).then((_) => onUpdate?.call());
  }

  // ── Main build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final words = langProvider.words;
    final status = (order['status'] ?? order['order_status'] ?? 'published')
        .toString()
        .toLowerCase();
    final isShop = role == 'shop';
    final String orderId = order['id'].toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          splashColor: HomeColors.green.withValues(alpha: 0.04),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Status strip ───────────────────────────────────────────
              _StatusStrip(status: status),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Row 1: transport icon + ID + status badge ──────
                    Row(
                      children: [
                        _buildTransportIcon(),
                        const SizedBox(width: 6),
                        _buildIdPill(),
                        const Spacer(),
                        _buildStatusBadge(status, words),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── Row 2-3: addresses ─────────────────────────────
                    _buildAddressRow(
                      icon: Icons.inventory_2_outlined,
                      iconColor: HomeColors.red,
                      address: order['shop_adress'] ?? 'Адрес магазина',
                    ),
                    const SizedBox(height: 4),
                    _buildAddressRow(
                      icon: Icons.location_on_outlined,
                      iconColor: HomeColors.green,
                      address: order['adress_of_delivery'] ?? 'Адрес доставки',
                    ),

                    const SizedBox(height: 8),

                    // ── Row 4: price + action button ───────────────────
                    const Divider(
                      color: Color(0xFFF1F4F8),
                      height: 1,
                      thickness: 1,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPriceSection(isShop, order, words),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Address row ────────────────────────────────────────────────────────────
  Widget _buildAddressRow({
    required IconData icon,
    required Color iconColor,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            address,
            style: AppText.regular(
              fontSize: 12,
              color: const Color(0xFF0F1117),
            ).copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }

  // ── Transport icon (no background container) ───────────────────────────────
  Widget _buildTransportIcon() {
    final String? transportType = order['transport_type']?.toString();
    IconData icon;
    Color color;
    switch (transportType) {
      case 'car':
        icon = Icons.directions_car_rounded;
        color = HomeColors.green;
        break;
      case 'truck':
        icon = Icons.local_shipping_rounded;
        color = HomeColors.red;
        break;
      default:
        icon = Icons.directions_run_rounded;
        color = const Color(0xFF9AA3AF);
    }
    return Icon(icon, size: 15, color: color);
  }

  // ── ID pill ────────────────────────────────────────────────────────────────
  Widget _buildIdPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'ID: ${order['id'].toString().split('-').first.toUpperCase()}',
        style: AppText.medium(fontSize: 10, color: const Color(0xFF9AA3AF)),
      ),
    );
  }

  // ── Status badge ───────────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status, AppLocalizations words) {
    final styles = {
      'published': _BadgeStyle(
        color: HomeColors.red,
        label: words.statusFree,
        icon: Icons.search_rounded,
      ),
      'active': _BadgeStyle(
        color: HomeColors.green,
        label: words.statusActive,
        icon: Icons.local_shipping_outlined,
      ),
      'canceled': _BadgeStyle(
        color: const Color(0xFF9AA3AF),
        label: words.statusCanceled,
        icon: Icons.cancel_outlined,
      ),
      'completed': _BadgeStyle(
        color: HomeColors.green,
        label: words.statusDone,
        icon: Icons.check_circle_outline_rounded,
      ),
    };
    final s = styles[status] ?? styles['canceled']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 10, color: s.color),
          const SizedBox(width: 4),
          Text(s.label, style: AppText.semiBold(fontSize: 10, color: s.color)),
        ],
      ),
    );
  }

  // ── Price section ──────────────────────────────────────────────────────────
  Widget _buildPriceSection(
    bool isShop,
    dynamic order,
    AppLocalizations words,
  ) {
    final double total = (order['total_amount'] ?? 0.0).toDouble();
    final double delivery = (order['delivery_amount'] ?? 0.0).toDouble();
    final double amount = isShop ? (total - delivery) : delivery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isShop ? words.toReceive : words.deliveryFee,
          style: AppText.regular(fontSize: 10, color: const Color(0xFF9AA3AF)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            ShaderMask(
              shaderCallback: (b) => HomeColors.gradient.createShader(b),
              child: Text(
                amount.toStringAsFixed(0),
                style: AppText.semiBold(fontSize: 20, color: Colors.white),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'TMT',
              style: AppText.regular(
                fontSize: 10,
                color: HomeColors.green.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────
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

    if (isShop && (status == 'published' || status == 'active')) {
      return _buildOutlineButton(
        label: 'Отменить',
        color: HomeColors.red,
        onTap: () => _showCancelReasonModal(context, orderId, service),
      );
    }

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
        color: HomeColors.green,
        onTap: () async {
          if (isRestricted) {
            _showRestrictedModal(context);
          } else if (isUserActive) {
            final activeCount = await service.getActiveOrdersCount(
              currentUserId,
            );
            if (!context.mounted) return;
            if (activeCount >= 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Нельзя брать больше 3 заказов одновременно',
                  ),
                  backgroundColor: HomeColors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              return;
            }
            if (balancePoints >= points) {
              _confirmAction(
                context: context,
                title: 'Принять заказ',
                message: points > 0
                    ? 'С вашего баланса будет списано $points баллов. Приступить?'
                    : 'Заказ будет закреплён за вами. Приступить?',
                actionColor: HomeColors.green,
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
              ).then((_) => onUpdate?.call());
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
            ).then((_) => onUpdate?.call());
          }
        },
      );
    }

    if (status == 'active' && role == 'courier') {
      const double cashback = 0.0;
      return _buildFilledButton(
        label: 'Завершить',
        color: HomeColors.green,
        cashback: cashback,
        onTap: () => onTap?.call(),
      );
    }

    return const SizedBox();
  }

  // ── Filled button ──────────────────────────────────────────────────────────
  Widget _buildFilledButton({
    required String label,
    required Color color,
    required void Function() onTap,
    int points = 0,
    double balancePoints = 0,
    double cashback = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.semiBold(fontSize: 12, color: Colors.white),
            ),
            if (points > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 6),
              Image.asset(
                'assets/images/point_icon.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 3),
              Text(
                '$points',
                style: AppText.regular(fontSize: 12, color: Colors.white),
              ),
            ],
            if (cashback > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 6),
              Image.asset(
                'assets/images/point_icon.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 3),
              Text(
                '+${cashback.toDouble()}',
                style: AppText.regular(fontSize: 12, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Outline button ─────────────────────────────────────────────────────────
  Widget _buildOutlineButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppText.medium(fontSize: 12, color: color)),
      ),
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
    ).then((_) => onUpdate?.call());
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

// ── Status strip ──────────────────────────────────────────────────────────────
class _StatusStrip extends StatelessWidget {
  final String status;
  const _StatusStrip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color left, right;
    switch (status) {
      case 'active':
        left = right = HomeColors.green;
        break;
      case 'canceled':
        left = right = HomeColors.grey;
        break;
      case 'completed':
        left = right = HomeColors.green;
        break;
      default:
        left = HomeColors.green;
        right = HomeColors.red;
    }
    return Container(
      height: 3,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [left, right]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
