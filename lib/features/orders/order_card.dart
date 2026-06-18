import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/point_icon.dart';
import 'package:bagla/core/widgets/pressable_scale.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/profile/widgets/shop_categories.dart';
import 'package:bagla/features/orders/take_order_flow.dart';
import 'package:bagla/features/orders/widgets/order_status_badge.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrderCard extends StatefulWidget {
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

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  // DTO мемоизируется: парсится один раз и переисчисляется только когда
  // `widget.order` поменялся по identity. Без этого каждый rebuild карточки
  // (а их много — language toggle, parent setState) создавал новый Map-копию
  // и новый OrderDto. Для списка из 30 карточек это были тысячи мусорных
  // объектов в секунду.
  late OrderDto _dto;

  @override
  void initState() {
    super.initState();
    _dto = OrderDto.fromMap(Map<String, dynamic>.from(widget.order as Map));
  }

  @override
  void didUpdateWidget(OrderCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.order, widget.order)) {
      _dto = OrderDto.fromMap(Map<String, dynamic>.from(widget.order as Map));
    }
  }

  // ── Shortcuts to widget fields — чтобы build() не таскал `widget.X` ──
  String get role => widget.role;
  String get currentUserId => widget.currentUserId;
  String get userPhone => widget.userPhone;
  VoidCallback? get onUpdate => widget.onUpdate;
  VoidCallback? get onTap => widget.onTap;

  // ── Main build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isRu = context.select<LanguageProvider, bool>((p) => p.isRu);
    final words = Provider.of<LanguageProvider>(context, listen: false).words;

    final dto = _dto;
    final isShop = role == 'shop';

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
                // ── Row 1: transport icon + category chip + ID + status badge ──
                Row(
                  children: [
                    _buildTransportIcon(dto.transportType, c),
                    if (dto.category.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildCategoryChip(dto.category, c),
                    ],
                    const SizedBox(width: 6),
                    _buildIdPill(dto.shortId, c),
                    const Spacer(),
                    OrderStatusBadge(status: dto.status),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Row 2-3: addresses ─────────────────────────────────
                _buildAddressRow(
                  icon: Icons.inventory_2_outlined,
                  iconColor: c.inkMuted,
                  address: dto.shopAddress(isRu),
                  c: c,
                ),
                const SizedBox(height: 4),
                _buildAddressRow(
                  icon: Icons.location_on_outlined,
                  iconColor: c.ink,
                  address: dto.deliveryAddress(isRu),
                  c: c,
                ),

                const SizedBox(height: 8),

                // ── Row 4: price + action button ───────────────────────
                Divider(color: c.borderSoft, height: 1, thickness: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPriceSection(isShop, dto, words, c),
                    _buildActionButtons(
                      context,
                      dto,
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
  Widget _buildTransportIcon(String? transportType, AppColors c) {
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

  // ── Category chip — иконка категории магазина ──────────────────────────────
  Widget _buildCategoryChip(String slug, AppColors c) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: c.emeraldTint,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Icon(iconForSlug(slug), size: 13, color: c.ink),
    );
  }

  // ── ID pill ────────────────────────────────────────────────────────────────
  Widget _buildIdPill(String shortId, AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.borderSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'ID: $shortId',
        style: AppText.medium(fontSize: 10, color: c.inkSoft),
      ),
    );
  }

  // ── Price section ──────────────────────────────────────────────────────────
  Widget _buildPriceSection(
    bool isShop,
    OrderDto dto,
    AppLocalizations words,
    AppColors c,
  ) {
    final amount = dto.amountFor(isShop: isShop);

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
    OrderDto dto,
    bool isShop,
    String userId,
    String userPhone,
    AppLocalizations words,
  ) {
    final status = dto.status;

    if (status == 'completed' || status == 'canceled') {
      return const SizedBox();
    }

    if (isShop && (status == 'published' || status == 'active')) {
      return _OutlineButton(
        label: words.cancelOrder,
        onTap: () => _showCancelReasonModal(
          context,
          dto.id,
          OrderService(),
          words,
        ),
      );
    }

    if (!isShop && status == 'published') {
      return _ActionButton(
        label: words.takeOrder,
        points: dto.pointsAmount,
        onTap: () => TakeOrderFlow.tryTake(
          context,
          dto: dto,
          currentUserId: currentUserId,
          courierPhone: userPhone,
          role: role,
          onUpdate: onUpdate,
        ),
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
}

// ── Filled action button — «Взять заказ» / «Завершить» ──────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final int points;

  const _ActionButton({
    required this.label,
    required this.onTap,
    this.points = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PressableScale(
      onTap: onTap,
      scale: 0.95,
      haptic: HapticFeedbackType.medium, // «Взять заказ»/«Завершить» — значимое действие
      child: Container(
        height: 40,
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
                label,
                style: AppText.semiBold(fontSize: 12, color: Colors.white),
              ),
            ),
            if (points > 0)
              Container(
                height: 40,
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
                    PointIcon(size: 13, tintColor: c.amber),
                    const SizedBox(width: 3),
                    Text(
                      '$points',
                      style: AppText.semiBold(fontSize: 12, color: c.amber),
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

// ── Outline cancel button ───────────────────────────────────────────────────
class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PressableScale(
      onTap: onTap,
      scale: 0.95,
      haptic: HapticFeedbackType.medium, // «Отменить заказ»
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: c.errorMuted.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.medium(fontSize: 12, color: c.errorMuted),
        ),
      ),
    );
  }
}

