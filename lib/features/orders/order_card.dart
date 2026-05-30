import 'dart:ui';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/home/home_constants.dart';
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
    required int points,
    required double deliveryAmount,
    required String shortOrderId,
    required String address,
    required AppLocalizations words,
    required Future<void> Function() action,
  }) async {
    final bool? confirmed = await showGeneralDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(color: Colors.black.withValues(alpha: 0.28)),
          ),
          Center(
            child: _ConfirmDialog(
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
          scale: Tween<double>(
            begin: 0.94,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await action();
        if (onUpdate != null) onUpdate!();
      } catch (_) {
        if (context.mounted) {
          final c = AppColors.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ошибка сети. Попробуйте позже.',
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
    }
  }

  void _showRestrictedModal(BuildContext context) {
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
              _sheetHandle(c),
              const SizedBox(height: 24),
              RestrictedAccessView(onActionPressed: () => Navigator.pop(ctx)),
            ],
          ),
        );
      },
    ).then((_) => onUpdate?.call());
  }

  // ── Main build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
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
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          splashColor: c.ink.withValues(alpha: 0.04),
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
                    _buildTransportIcon(c),
                    const SizedBox(width: 6),
                    _buildIdPill(c),
                    const Spacer(),
                    _buildStatusBadge(status, words),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Row 2-3: addresses ─────────────────────────────────
                _buildAddressRow(
                  icon: Icons.inventory_2_outlined,
                  iconColor: c.inkMuted,
                  address: langProvider.isRu
                      ? (order['shop_adress'] ?? 'Адрес магазина')
                      : (order['shop_adresstk'] ?? 'Dükan salgysy'),
                  c: c,
                ),
                const SizedBox(height: 4),
                _buildAddressRow(
                  icon: Icons.location_on_outlined,
                  iconColor: c.ink,
                  address: langProvider.isRu
                      ? (order['adress_of_delivery'] ?? 'Адрес доставки')
                      : (order['adress_of_deliverytk'] ??
                            'Eltip beriş salgysy'),
                  c: c,
                ),

                const SizedBox(height: 8),

                // ── Row 4: price + action button ───────────────────────
                Divider(color: c.borderSoft, height: 1, thickness: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPriceSection(isShop, order, words, c),
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
    required AppColors c,
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
              color: c.ink,
            ).copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }

  // ── Transport icon ─────────────────────────────────────────────────────────
  Widget _buildTransportIcon(AppColors c) {
    final String? transportType = order['transport_type']?.toString();
    final IconData icon;
    final Color color;
    switch (transportType) {
      case 'car':
        icon = Icons.directions_car_rounded;
        color = c.ink;
      case 'truck':
        icon = Icons.local_shipping_rounded;
        color = c.errorMuted;
      default:
        icon = Icons.directions_run_rounded;
        color = c.inkSoft;
    }
    return Icon(icon, size: 15, color: color);
  }

  // ── ID pill ────────────────────────────────────────────────────────────────
  Widget _buildIdPill(AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.borderSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'ID: ${order['id'].toString().split('-').first.toUpperCase()}',
        style: AppText.medium(fontSize: 10, color: c.inkSoft),
      ),
    );
  }

  // ── Status badge ───────────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status, AppLocalizations words) {
    final styles = {
      'published': _BadgeStyle(
        color: HomeColors.yellow,
        label: words.statusFree,
        icon: Icons.search_rounded,
      ),
      'active': _BadgeStyle(
        color: HomeColors.dark,
        label: words.statusActive,
        icon: Icons.local_shipping_outlined,
      ),
      'canceled': _BadgeStyle(
        color: HomeColors.dark,
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
    AppColors c,
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
          style: AppText.regular(fontSize: 10, color: c.inkSoft),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              amount.toStringAsFixed(0),
              style: AppText.semiBold(fontSize: 20, color: c.ink),
            ),
            const SizedBox(width: 3),
            Text(
              'TMT',
              style: AppText.regular(
                fontSize: 10,
                color: c.ink.withValues(alpha: 0.5),
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
              final c = AppColors.of(context);
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
            if (balancePoints >= points) {
              final langProv = context.read<LanguageProvider>();
              _confirmAction(
                context: context,
                title: words.confirmTitle,
                points: points,
                deliveryAmount: (order['delivery_amount'] ?? 0.0).toDouble(),
                shortOrderId: orderId.split('-').first.toUpperCase(),
                address: langProv.isRu
                    ? (order['adress_of_delivery'] ?? '').toString()
                    : (order['adress_of_deliverytk'] ?? '').toString(),
                words: words,
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
                onClose: () => Navigator.of(context, rootNavigator: true).pop(),
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
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => CancelReasonModal(
        orderId: orderId,
        currentUserId: currentUserId,
        service: service,
        onSuccess: () => onUpdate?.call(),
        words: words,
      ),
    ).then((_) => onUpdate?.call());
  }

  Widget _sheetHandle(AppColors c) => Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: c.border,
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
    final c = AppColors.of(context);
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
            color: c.ink.withValues(alpha: 0.8),
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
              if (widget.points > 0) _amberBlock('${widget.points}', c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amberBlock(String text, AppColors c) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.amberTint,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.toll_rounded, size: 13, color: c.amber),
          const SizedBox(width: 3),
          Text(text, style: AppText.semiBold(fontSize: 12, color: c.amber)),
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
    final c = AppColors.of(context);
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
            border: Border.all(color: c.errorMuted.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppText.medium(fontSize: 12, color: c.errorMuted),
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

// ── Confirm dialog ────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatefulWidget {
  final String title;
  final int points;
  final double deliveryAmount;
  final String shortOrderId;
  final String address;
  final AppLocalizations words;

  const _ConfirmDialog({
    required this.title,
    required this.points,
    required this.deliveryAmount,
    required this.shortOrderId,
    required this.address,
    required this.words,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _confirmPressed = false;
  bool _cancelPressed = false;

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
                    widget.title,
                    style: AppText.serif(fontSize: 17, color: c.ink),
                  ),
                  const SizedBox(height: 10),
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
                                widget.words.deliveryFee,
                                style: AppText.regular(
                                  fontSize: 10,
                                  color: c.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '+${widget.deliveryAmount.toStringAsFixed(0)}',
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
                        if (widget.points > 0) ...[
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
                                Icon(
                                  Icons.toll_rounded,
                                  size: 13,
                                  color: c.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '-${widget.points}',
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
                          'ID: ${widget.shortOrderId} • ${widget.address}',
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _cancelPressed = true),
                    onTapUp: (_) {
                      setState(() => _cancelPressed = false);
                      Navigator.pop(context, false);
                    },
                    onTapCancel: () => setState(() => _cancelPressed = false),
                    child: AnimatedScale(
                      scale: _cancelPressed ? 0.97 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: c.borderSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.words.back,
                          style: AppText.medium(
                            fontSize: 13,
                            color: c.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => setState(() => _confirmPressed = true),
                      onTapUp: (_) {
                        setState(() => _confirmPressed = false);
                        Navigator.pop(context, true);
                      },
                      onTapCancel: () =>
                          setState(() => _confirmPressed = false),
                      child: AnimatedScale(
                        scale: _confirmPressed ? 0.97 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOutBack,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          height: 44,
                          decoration: BoxDecoration(
                            color: _confirmPressed
                                ? c.ink.withValues(alpha: 0.85)
                                : c.ink,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _confirmPressed
                                ? null
                                : [
                                    BoxShadow(
                                      color: c.ink.withValues(alpha: 0.22),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.words.takeOrder,
                            style: AppText.semiBold(
                              fontSize: 13,
                              color: Colors.white,
                            ),
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
