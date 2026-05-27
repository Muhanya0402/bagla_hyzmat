import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/features/orders/order_service.dart';
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
    required Future<void> Function() action,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AuthColors.bg,
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
                  color: AuthColors.emerald,
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
                  color: AuthColors.inkSoft,
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
                          border: Border.all(color: AuthColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Назад',
                          style: AppText.medium(color: AuthColors.inkMuted),
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
                          color: AuthColors.emerald,
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
                style: AppText.regular(
                  fontSize: 13,
                  color: AuthColors.errorMuted,
                ),
              ),
              backgroundColor: AuthColors.errorTint,
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
        border: Border.all(color: AuthColors.border),
        boxShadow: [
          BoxShadow(
            color: AuthColors.ink.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          splashColor: AuthColors.emerald.withValues(alpha: 0.04),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Row 1: transport icon + ID + status badge ──────────
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

                // ── Row 2-3: addresses ─────────────────────────────────
                _buildAddressRow(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AuthColors.inkMuted,
                  address: langProvider.isRu
                      ? (order['shop_adress'] ?? 'Адрес магазина')
                      : (order['shop_adresstk'] ?? 'Dükan salgysy'),
                ),
                const SizedBox(height: 4),
                _buildAddressRow(
                  icon: Icons.location_on_outlined,
                  iconColor: AuthColors.emerald,
                  address: langProvider.isRu
                      ? (order['adress_of_delivery'] ?? 'Адрес доставки')
                      : (order['adress_of_deliverytk'] ??
                            'Eltip beriş salgysy'),
                ),

                const SizedBox(height: 8),

                // ── Row 4: price + action button ───────────────────────
                Divider(
                  color: AuthColors.borderSoft,
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
                      words,
                    ),
                  ],
                ),
              ],
            ),
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
              color: AuthColors.ink,
            ).copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }

  // ── Transport icon ─────────────────────────────────────────────────────────
  Widget _buildTransportIcon() {
    final String? transportType = order['transport_type']?.toString();
    final IconData icon;
    final Color color;
    switch (transportType) {
      case 'car':
        icon = Icons.directions_car_rounded;
        color = AuthColors.emerald;
      case 'truck':
        icon = Icons.local_shipping_rounded;
        color = AuthColors.errorMuted;
      default:
        icon = Icons.directions_run_rounded;
        color = AuthColors.inkSoft;
    }
    return Icon(icon, size: 15, color: color);
  }

  // ── ID pill ────────────────────────────────────────────────────────────────
  Widget _buildIdPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AuthColors.borderSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'ID: ${order['id'].toString().split('-').first.toUpperCase()}',
        style: AppText.medium(fontSize: 10, color: AuthColors.inkSoft),
      ),
    );
  }

  // ── Status badge ───────────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status, AppLocalizations words) {
    final styles = {
      'published': _BadgeStyle(
        color: AuthColors.emerald,
        label: words.statusFree,
        icon: Icons.search_rounded,
      ),
      'active': _BadgeStyle(
        color: AuthColors.emerald,
        label: words.statusActive,
        icon: Icons.local_shipping_outlined,
      ),
      'canceled': _BadgeStyle(
        color: AuthColors.inkSoft,
        label: words.statusCanceled,
        icon: Icons.cancel_outlined,
      ),
      'completed': _BadgeStyle(
        color: AuthColors.emerald,
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
          style: AppText.regular(fontSize: 10, color: AuthColors.inkSoft),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              amount.toStringAsFixed(0),
              style: AppText.semiBold(
                fontSize: 20,
                color: AuthColors.emerald,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'TMT',
              style: AppText.regular(
                fontSize: 10,
                color: AuthColors.emerald.withValues(alpha: 0.5),
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
    AppLocalizations words,
  ) {
    final OrderService service = OrderService();

    if (status == 'completed' || status == 'canceled') {
      return const SizedBox();
    }

    if (isShop && (status == 'published' || status == 'active')) {
      return _OutlineButton(
        label: words.cancelOrder,
        onTap: () => _showCancelReasonModal(context, orderId, service, words),
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

      return _ActionButton(
        label: words.takeOrder,
        points: points,
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
                  content: Text(
                    words.tooManyOrders,
                    style: AppText.regular(
                      fontSize: 13,
                      color: AuthColors.errorMuted,
                    ),
                  ),
                  backgroundColor: AuthColors.errorTint,
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
                title: words.confirmTitle,
                message: points > 0
                    ? words.confirmWithPoints.replaceAll('{points}', '$points')
                    : words.confirmNoPoints,
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
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    TopUpModal(userId: userId, role: role, status: status),
              ).then((_) => onUpdate?.call());
            }
          } else if (isClient) {
            showModalBottomSheet(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => RolePickerEmbedded(
                onClose: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              ),
            ).then((_) => onUpdate?.call());
          }
        },
      );
    }

    if (status == 'active' && role == 'courier') {
      return _ActionButton(
        label: words.finishOrder,
        onTap: () => onTap?.call(),
      );
    }

    return const SizedBox();
  }

  void _showCancelReasonModal(
    BuildContext context,
    String orderId,
    OrderService service,
    AppLocalizations words,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CancelReasonModal(
        orderId: orderId,
        currentUserId: currentUserId,
        service: service,
        onSuccess: () => onUpdate?.call(),
        words: words,
      ),
    ).then((_) => onUpdate?.call());
  }

  Widget _sheetHandle() => Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: AuthColors.border,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

// ── Filled action button with AnimatedScale press feedback ────────────────────
class _ActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final int points;

  const _ActionButton({
    required this.label,
    required this.onTap,
    this.points = 0,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: AuthColors.emerald,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  widget.label,
                  style: AppText.semiBold(fontSize: 12, color: Colors.white),
                ),
              ),
              if (widget.points > 0) _amberBlock('${widget.points}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amberBlock(String text) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AuthColors.amberTint,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.toll_rounded, size: 13, color: AuthColors.amber),
          const SizedBox(width: 3),
          Text(
            text,
            style: AppText.semiBold(fontSize: 12, color: AuthColors.amber),
          ),
        ],
      ),
    );
  }
}

// ── Outline cancel button with AnimatedScale press feedback ───────────────────
class _OutlineButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({required this.label, required this.onTap});

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: AuthColors.errorMuted.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppText.medium(fontSize: 12, color: AuthColors.errorMuted),
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
