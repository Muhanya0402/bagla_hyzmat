import 'dart:async';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/pressable_scale.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/orders/take_order_flow.dart';
import 'package:bagla/features/orders/widgets/cashback_success_dialog.dart';
import 'package:bagla/features/orders/widgets/order_countdown_card.dart';
import 'package:bagla/features/orders/widgets/order_images_section.dart';
import 'package:bagla/features/orders/widgets/order_route_section.dart';
import 'package:bagla/features/orders/widgets/order_primary_button.dart';
import 'package:bagla/features/orders/widgets/order_status_badge.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailScreen extends StatefulWidget {
  final dynamic order;
  final String role;
  final String currentUserId;
  final VoidCallback? onUpdate;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.role,
    required this.currentUserId,
    this.onUpdate,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with SingleTickerProviderStateMixin, AppTourMixin<OrderDetailScreen> {
  static const String _baseUrl = BaseUrl.url;

  final _routeKey = GlobalKey();
  final _actionKey = GlobalKey();

  // Updated at most once (when the deadline passes); never on every tick.
  bool _isExpired = false;

  late final AnimationController _animCtrl;

  // Pre-cached interval animations — avoids CurvedAnimation allocations on
  // every build() call. _a0 = countdown, _a1 = route, _a2 = details,
  // _a3 = price, _a4 = photos, _a5 = comment.
  late final Animation<double> _a0, _a1, _a2, _a3, _a4, _a5;

  List<TargetFocus> _buildTourTargets() {
    final words = context.read<LanguageProvider>().words;
    final auth = context.read<AuthProvider>();

    if (auth.shouldSkipTour) return const [];

    return [
      TourTarget.build(
        key: _routeKey,
        title: words.tourOrderRouteTitle,
        body: words.tourOrderRouteBody,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        key: _actionKey,
        title: words.tourOrderActionTitle,
        body: words.tourOrderActionBody,
        isLast: true,
        align: ContentAlign.top,
      ),
    ];
  }

  String _transportLabel(String? type, AppLocalizations words) {
    switch (type) {
      case 'car':
        return words.transportCar;
      case 'truck':
        return words.transportTruck;
      default:
        return words.transportAny;
    }
  }

  IconData _transportIcon(String? type) {
    switch (type) {
      case 'car':
        return Icons.directions_car_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      default:
        return Icons.directions_run_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // Pre-cache all animations once — build() never allocates new objects.
    final s = widget.role == 'shop';
    _a0 = _ia(0.0,          0.45);
    _a1 = _ia(s ? 0.0 : 0.1, s ? 0.45 : 0.55);
    _a2 = _ia(s ? 0.1 : 0.2, s ? 0.55 : 0.65);
    _a3 = _ia(s ? 0.2 : 0.3, s ? 0.65 : 0.75);
    _a4 = _ia(s ? 0.3 : 0.4, s ? 0.75 : 0.85);
    _a5 = _ia(s ? 0.35 : 0.45, s ? 0.8 : 0.9);
    WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
    startTourIfNeeded(
      screenKey: TourKeys.orderDetail,
      targetsBuilder: _buildTourTargets,
    );
  }

  // Called by _CountdownCard exactly once when the deadline passes.
  void _onDeadlineExpired() {
    if (!_isExpired && mounted) setState(() => _isExpired = true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // Only called during initState — never inside build().
  Animation<double> _ia(double start, double end) {
    return CurvedAnimation(
      parent: _animCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Widget _animated(Widget child, Animation<double> anim) {
    return FadeTransition(
      opacity: anim,
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, inner) => Transform.translate(
          offset: Offset(0, 14 * (1 - anim.value)),
          child: inner,
        ),
        child: child,
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dto = OrderDto.fromMap(
      Map<String, dynamic>.from(widget.order as Map),
    );
    final langProvider = context.watch<LanguageProvider>();
    final words = langProvider.words;
    final isShop = widget.role == 'shop';
    final isDataLocked = !isShop && dto.status == 'published';

    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.borderSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: c.inkMuted,
              size: 16,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${words.order} #${dto.shortId}',
                style: AppText.serif(fontSize: 18, color: c.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            OrderStatusBadge(status: dto.status, showIcon: false),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: c.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          // ── Countdown (courier) — own StatefulWidget, never triggers
          //    parent setState; calls _onDeadlineExpired() exactly once.
          if (!isShop)
            _animated(
              RepaintBoundary(
                child: OrderCountdownCard(
                  timeOfDelivery: dto.timeOfDelivery,
                  cashback: dto.cashbackAmount,
                  words: words,
                  onExpired: _onDeadlineExpired,
                ),
              ),
              _a0,
            ),
          if (!isShop) const SizedBox(height: 10),

          // ── Route timeline ───────────────────────────────────────────────
          KeyedSubtree(
            key: _routeKey,
            child: _animated(
              RepaintBoundary(
                child: _section(
                  title: words.routeSection,
                  child: OrderRouteSection(dto: dto, isLocked: isDataLocked),
                ),
              ),
              _a1,
            ),
          ),
          const SizedBox(height: 10),

          // ── Details ──────────────────────────────────────────────────────
          _animated(
            RepaintBoundary(
              child: _section(
                title: words.recipientSection,
                child: _buildDetailsBlock(dto, isDataLocked, isShop, words),
              ),
            ),
            _a2,
          ),
          const SizedBox(height: 10),

          // ── Price ────────────────────────────────────────────────────────
          _animated(
            _section(
              title: words.priceSection,
              child: _buildPriceBlock(
                isShop,
                dto.totalAmount,
                dto.deliveryAmount,
                dto.cashbackAmount,
                words,
              ),
            ),
            _a3,
          ),

          // ── Photos ───────────────────────────────────────────────────────
          if (dto.pictures.isNotEmpty) ...[
            const SizedBox(height: 10),
            _animated(
              _section(
                title: words.photoSection,
                child: OrderImagesSection(
                  pictures: dto.pictures,
                  baseUrl: _baseUrl,
                ),
              ),
              _a4,
            ),
          ],

          // ── Comment ──────────────────────────────────────────────────────
          if (dto.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            _animated(
              _section(
                title: words.commentSection,
                child: Text(
                  dto.comment,
                  style: AppText.regular(fontSize: 13, color: c.ink)
                      .copyWith(height: 1.5),
                ),
              ),
              _a5,
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          key: _actionKey,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _animated(
            _buildActionButton(context, dto, isShop, words),
            _a5,
          ),
        ),
      ),
    );
  }

  // ── Section wrapper ────────────────────────────────────────────────────────
  Widget _section({required String title, required Widget child}) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: AppText.semiBold(
                  fontSize: 10,
                  color: c.inkSoft,
                ).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Details block (transport + recipient + counterparty) ───────────────────
  Widget _buildDetailsBlock(
    OrderDto dto,
    bool isLocked,
    bool isShop,
    AppLocalizations words,
  ) {
    final c = AppColors.of(context);
    final String? transportType = dto.transportType;
    final String phone = dto.clientPhone;
    final String counterPhone = isShop ? dto.courierPhone : dto.shopPhone;
    final String courierName = dto.courierName;

    return Column(
      children: [
        // Transport row
        _detailRow(
          icon: _transportIcon(transportType),
          iconColor: transportType == 'truck' ? c.errorMuted : c.ink,
          label: words.transportRequirement,
          value: _transportLabel(transportType, words),
        ),

        const SizedBox(height: 10),
        Container(height: 0.5, color: c.borderSoft),
        const SizedBox(height: 10),

        // Recipient row
        _detailRow(
          icon: Icons.person_outline_rounded,
          iconColor: c.ink,
          label: isLocked ? words.phoneHidden : words.clientPhone,
          value: isLocked ? words.phoneMasked : (phone.isEmpty ? '—' : phone),
          trailing: phone.isNotEmpty && !isLocked ? _callButton(phone) : null,
        ),

        // Counterparty row (if available)
        if (!isLocked && counterPhone.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(height: 0.5, color: c.borderSoft),
          const SizedBox(height: 10),
          _detailRow(
            icon: isShop
                ? Icons.delivery_dining_outlined
                : Icons.storefront_outlined,
            iconColor: c.inkMuted,
            label: isShop
                ? (courierName.isNotEmpty
                      ? '${words.courier} — $courierName'
                      : words.courier)
                : words.orderSender,
            value: counterPhone,
            trailing: _callButton(counterPhone),
          ),
        ],
      ],
    );
  }

  Widget _detailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.regular(fontSize: 10, color: c.inkSoft),
              ),
              const SizedBox(height: 1),
              Text(value, style: AppText.medium(fontSize: 13, color: c.ink)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }

  Widget _callButton(String phone) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => _makePhoneCall(phone),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.call, color: Colors.white, size: 18),
      ),
    );
  }

  // ── Price block ────────────────────────────────────────────────────────────
  Widget _buildPriceBlock(
    bool isShop,
    double total,
    double delivery,
    double cashback,
    AppLocalizations words,
  ) {
    final c = AppColors.of(context);
    final double itemPrice = total - delivery;

    return Column(
      children: [
        _priceRow(
          words.itemPrice,
          '${itemPrice.toStringAsFixed(0)} TMT',
          c.ink,
        ),
        const SizedBox(height: 8),
        _priceRow(words.delivery, '${delivery.toStringAsFixed(0)} TMT', c.ink),
        if (!isShop && cashback > 0) ...[
          const SizedBox(height: 8),
          _priceRow(
            words.cashbackPercent,
            '+${cashback.toDouble()} ${words.tokens}',
            c.amber,
          ),
        ],
        Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(vertical: 10),
          color: c.borderSoft,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isShop ? words.toShopReceive : words.courierPayout,
              style: AppText.semiBold(fontSize: 13, color: c.ink),
            ),
            Text(
              isShop
                  ? '${itemPrice.toStringAsFixed(0)} TMT'
                  : '${delivery.toStringAsFixed(0)} TMT',
              style: AppText.semiBold(fontSize: 17, color: c.ink),
            ),
          ],
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value, Color valueColor) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.regular(fontSize: 13, color: c.inkMuted)),
        Text(value, style: AppText.medium(fontSize: 13, color: valueColor)),
      ],
    );
  }

  // ── Images ─────────────────────────────────────────────────────────────────
  // ── Bottom action button ───────────────────────────────────────────────────
  Widget _buildActionButton(
    BuildContext context,
    OrderDto dto,
    bool isShop,
    AppLocalizations words,
  ) {
    final c = AppColors.of(context);
    final service = OrderService();
    final status = dto.status;
    final orderId = dto.id;

    if (status == 'completed' || status == 'canceled') {
      return const SizedBox.shrink();
    }

    if (isShop && (status == 'published' || status == 'active')) {
      return OrderPrimaryButton(
        label: words.cancelOrderBtn,
        color: c.errorMuted,
        filled: false,
        onTap: () => _showCancelReasonModal(context, orderId, service, words),
      );
    }

    if (!isShop) {
      if (status == 'published') {
        return OrderPrimaryButton(
          label: words.takeOrder,
          color: c.ink,
          filled: true,
          onTap: () => TakeOrderFlow.tryTake(
            context,
            dto: dto,
            currentUserId: widget.currentUserId,
            // На детальном экране у нас нет courierPhone — передаём пусто.
            // OrderService.updateStatus умеет работать без него.
            courierPhone: '',
            role: widget.role,
            onUpdate: widget.onUpdate,
          ),
        );
      }

      if (status == 'active') {
        final double cashback = _isExpired ? 0.0 : dto.cashbackAmount;

        return OrderPrimaryButton(
          label: cashback > 0
              ? words.finishWithCashback.replaceAll(
                  '{cashback}',
                  '${cashback.toDouble()}',
                )
              : words.finishOrder,
          color: c.ink,
          filled: true,
          onTap: () => _showDeliveryCodeModal(context, orderId, service, words),
        );
      }
    }

    return const SizedBox.shrink();
  }

  // ── Delivery code modal ────────────────────────────────────────────────────
  Future<void> _showDeliveryCodeModal(
    BuildContext context,
    String orderId,
    OrderService service,
    AppLocalizations words,
  ) async {
    final c = AppColors.of(context);
    final codeCtrl = TextEditingController();
    bool isLoading = false;
    bool codeSent = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                _handle(),
                const SizedBox(height: 20),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: codeSent ? c.emeraldTint : c.errorTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    codeSent
                        ? Icons.dialpad_rounded
                        : Icons.lock_outline_rounded,
                    color: codeSent ? c.ink : c.errorMuted,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  words.confirmDelivery,
                  style: AppText.serif(fontSize: 18, color: c.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  codeSent ? words.enterCodeHint : words.sendCodeHint,
                  style: AppText.regular(fontSize: 13, color: c.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                if (!codeSent) ...[
                  OrderPrimaryButton(
                    label: words.sendCodeBtn,
                    color: c.ink,
                    filled: true,
                    isLoading: isLoading,
                    onTap: () async {
                      setS(() => isLoading = true);
                      final result = await service.generateDeliveryCode(
                        orderId: orderId,
                        courierId: widget.currentUserId,
                        clientPhone: widget.order['client_phone'] ?? '',
                      );
                      setS(() {
                        isLoading = false;
                        if (result['success'] == true) codeSent = true;
                      });
                      if (result['success'] != true && ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(words.codeSendError),
                            backgroundColor: c.errorMuted,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ] else ...[
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: AppText.semiBold(
                      fontSize: 28,
                      color: c.ink,
                    ).copyWith(letterSpacing: 8),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • •',
                      hintStyle: AppText.regular(
                        fontSize: 28,
                        color: c.border,
                      ).copyWith(letterSpacing: 8),
                      filled: true,
                      fillColor: c.borderSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OrderPrimaryButton(
                    label: words.confirmBtn2,
                    color: c.ink,
                    filled: true,
                    isLoading: isLoading,
                    onTap: () async {
                      final code = codeCtrl.text.trim();
                      if (code.length != 4) return;
                      setS(() => isLoading = true);
                      final result = await service.verifyDeliveryCode(
                        orderId: orderId,
                        code: code,
                      );
                      setS(() => isLoading = false);
                      if (result['success'] == true) {
                        final double cashback =
                            (widget.order['cashback_amount'] ?? 0.0).toDouble();
                        final int xpEarned = result['xp_earned'] ?? 0;

                        service.applyCashbackIfOnTime(
                          orderId: orderId,
                          courierId: widget.currentUserId,
                        );

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        widget.onUpdate?.call();

                        if (context.mounted) {
                          if (cashback > 0 && !_isExpired) {
                            CashbackSuccessDialog.show(
                              context,
                              points: cashback,
                              xpEarned: xpEarned,
                              words: words,
                              onClose: () => Navigator.pop(context),
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        }
                      } else {
                        codeCtrl.clear();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message'] ?? words.wrongCode,
                              ),
                              backgroundColor: c.errorMuted,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setS(() {
                            codeSent = false;
                            codeCtrl.clear();
                          }),
                    child: Text(
                      words.resendCode,
                      style: AppText.regular(fontSize: 13, color: c.inkSoft),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelReasonModal(
    BuildContext context,
    String orderId,
    OrderService service,
    AppLocalizations words,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => CancelReasonModal(
        orderId: orderId,
        currentUserId: widget.currentUserId,
        service: service,
        onSuccess: () => widget.onUpdate?.call(),
        words: words,
      ),
    ).then((_) => widget.onUpdate?.call());
  }

  Widget _handle() {
    final c = AppColors.of(context);
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: c.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}



