import 'dart:async';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/features/auth/auth_provider.dart';
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

  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isExpired = false;

  late final AnimationController _animCtrl;

  List<TargetFocus> _buildTourTargets() {
    final lang = context.read<LanguageProvider>();
    return [
      TourTarget.build(
        key: _routeKey,
        titleRu: 'Маршрут',
        titleTk: 'Ugur',
        bodyRu: 'Здесь отображается откуда и куда доставить заказ.',
        bodyTk:
            'Bu ýerde sargydyň nireden we nirä gowşuryljakdygy görkezilýär.',
        isRu: lang.isRu,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        key: _actionKey,
        titleRu: 'Действие',
        titleTk: 'Hereket',
        bodyRu: 'Нажмите чтобы принять или завершить заказ.',
        bodyTk: 'Sargyt kabul etmek ýa-da tamamlamak üçin basyň.',
        isRu: lang.isRu,
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
      duration: const Duration(milliseconds: 650),
    );
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
    startTourIfNeeded(
      screenKey: TourKeys.orderDetail,
      targetsBuilder: _buildTourTargets,
    );
  }

  void _startCountdown() {
    final String? t = widget.order['time_of_delivery'];
    if (t == null || t.isEmpty) return;
    final deadline = DateTime.parse(t).toLocal();
    _updateTimeLeft(deadline);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTimeLeft(deadline),
    );
  }

  void _updateTimeLeft(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (mounted) {
      setState(() {
        if (diff.isNegative) {
          _timeLeft = Duration.zero;
          _isExpired = true;
        } else {
          _timeLeft = diff;
          _isExpired = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Animation<double> _itemAnim(double start, double end) {
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

  // ── Confirm dialog ─────────────────────────────────────────────────────────
  Future<void> _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required Color actionColor,
    required Future<void> Function() action,
    required AppLocalizations words,
  }) async {
    final c = AppColors.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.bg,
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
                  color: c.ink,
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
                  color: c.inkSoft,
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
                          border: Border.all(color: c.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          words.dialogBack,
                          style: AppText.medium(color: c.inkMuted),
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
                          words.dialogConfirm,
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
        if (widget.onUpdate != null) widget.onUpdate!();
        if (context.mounted) Navigator.pop(context);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(words.error),
              backgroundColor: c.errorMuted,
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

  // ── Cashback success dialog ─────────────────────────────────────────────────
  void _showCashbackSuccessModal(
    BuildContext context,
    double points,
    int xpEarned,
    AppLocalizations words,
  ) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.emeraldTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: c.ink, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                words.orderDone,
                style: AppText.serif(fontSize: 20, color: c.ink),
              ),
              const SizedBox(height: 8),
              Text(
                words.deliveredOnTime,
                style: AppText.regular(fontSize: 13, color: c.inkSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: c.amberTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/point_icon.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.toll_rounded, color: c.amber, size: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${points.toDouble()} ${words.tokens}',
                      style: AppText.semiBold(fontSize: 20, color: c.amber),
                    ),
                  ],
                ),
              ),
              if (xpEarned > 0) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFF7C3AED),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+$xpEarned XP',
                        style: AppText.semiBold(
                          fontSize: 20,
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                words.deliveryOnTimeSub,
                style: AppText.regular(fontSize: 12, color: c.inkSoft),
              ),
              const SizedBox(height: 20),
              _DetailActionButton(
                label: words.great,
                color: c.ink,
                filled: true,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final status = (widget.order['order_status'] ?? 'published')
        .toString()
        .toLowerCase();
    final langProvider = context.watch<LanguageProvider>();
    final words = langProvider.words;
    final isShop = widget.role == 'shop';
    final isDataLocked = !isShop && status == 'published';
    final orderId = widget.order['id'].toString();
    final double total = (widget.order['total_amount'] ?? 0.0).toDouble();
    final double delivery = (widget.order['delivery_amount'] ?? 0.0).toDouble();
    final List pictures = widget.order['pictures'] is List
        ? widget.order['pictures']
        : [];

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
                '${words.order} #${orderId.split('-').first.toUpperCase()}',
                style: AppText.serif(fontSize: 18, color: c.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _statusChip(status, words),
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
          // ── Countdown (courier + has deadline) ──────────────────────────
          if (!isShop)
            _animated(_buildCountdownCard(words), _itemAnim(0.0, 0.45)),
          if (!isShop) const SizedBox(height: 10),

          // ── Route timeline ───────────────────────────────────────────────
          KeyedSubtree(
            key: _routeKey,
            child: _animated(
              _section(
                title: words.routeSection,
                child: _buildRouteBlock(isDataLocked, langProvider),
              ),
              _itemAnim(isShop ? 0.0 : 0.1, isShop ? 0.45 : 0.55),
            ),
          ),
          const SizedBox(height: 10),

          // ── Details (transport + contacts) ───────────────────────────────
          _animated(
            _section(
              title: words.recipientSection,
              child: _buildDetailsBlock(isDataLocked, isShop, words),
            ),
            _itemAnim(isShop ? 0.1 : 0.2, isShop ? 0.55 : 0.65),
          ),
          const SizedBox(height: 10),

          // ── Price ────────────────────────────────────────────────────────
          _animated(
            _section(
              title: words.priceSection,
              child: _buildPriceBlock(isShop, total, delivery, words),
            ),
            _itemAnim(isShop ? 0.2 : 0.3, isShop ? 0.65 : 0.75),
          ),

          // ── Photos ───────────────────────────────────────────────────────
          if (pictures.isNotEmpty) ...[
            const SizedBox(height: 10),
            _animated(
              _section(
                title: words.photoSection,
                child: _buildImagesBlock(pictures),
              ),
              _itemAnim(isShop ? 0.3 : 0.4, isShop ? 0.75 : 0.85),
            ),
          ],

          // ── Comment ──────────────────────────────────────────────────────
          if ((widget.order['comment'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _animated(
              _section(
                title: words.commentSection,
                child: Text(
                  widget.order['comment'].toString(),
                  style: AppText.regular(
                    fontSize: 13,
                    color: c.ink,
                  ).copyWith(height: 1.5),
                ),
              ),
              _itemAnim(isShop ? 0.35 : 0.45, isShop ? 0.8 : 0.9),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          key: _actionKey,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _animated(
            _buildActionButton(context, status, orderId, isShop, words),
            _itemAnim(isShop ? 0.4 : 0.5, 1.0),
          ),
        ),
      ),
    );
  }

  // ── Status chip ────────────────────────────────────────────────────────────
  Widget _statusChip(String status, AppLocalizations words) {
    final c = AppColors.of(context);
    final Color color;
    final Color bg;
    final String label;

    switch (status) {
      case 'published':
        color = const Color(0xFFFFC107);
        bg = c.errorTint;
        label = words.statusFree;
      case 'active':
        color = c.ink;
        bg = c.amberTint;
        label = words.statusActive;
      case 'completed':
        color = c.ink;
        bg = c.emeraldTint;
        label = words.statusDone;
      default:
        color = c.errorMuted;
        bg = c.borderSoft;
        label = words.statusCanceled;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: AppText.semiBold(fontSize: 10, color: color)),
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

  // ── Countdown strip ────────────────────────────────────────────────────────
  Widget _buildCountdownCard(AppLocalizations words) {
    final c = AppColors.of(context);
    final double cashback = (widget.order['cashback_amount'] ?? 0.0).toDouble();
    final Color color = _isExpired ? c.errorMuted : c.ink;
    final Color bg = _isExpired ? c.errorTint : c.emeraldTint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            _isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isExpired ? words.timerExpired : words.timerLabel,
                  style: AppText.regular(fontSize: 10, color: color),
                ),
                Text(
                  _isExpired ? words.cashbackNone : _formatDuration(_timeLeft),
                  style: AppText.semiBold(fontSize: 16, color: color),
                ),
              ],
            ),
          ),
          if (!_isExpired && cashback > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.amberTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/point_icon.png',
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.toll_rounded, size: 16, color: c.amber),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+${cashback.toDouble()}',
                    style: AppText.semiBold(fontSize: 13, color: c.amber),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Route timeline ─────────────────────────────────────────────────────────
  Widget _buildRouteBlock(bool isLocked, LanguageProvider langProvider) {
    final c = AppColors.of(context);
    final fromAddr = langProvider.isRu
        ? (widget.order['shop_adress'] ?? 'Адрес магазина')
        : (widget.order['shop_adresstk'] ?? 'Dükan salgysy');
    final toAddr = langProvider.isRu
        ? (widget.order['adress_of_delivery'] ?? 'Адрес доставки')
        : (widget.order['adress_of_deliverytk'] ?? 'Eltip beriş salgysy');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: c.borderSoft,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.ink,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Addresses
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _routePoint(label: 'Откуда', value: fromAddr),
                const SizedBox(height: 14),
                _routePoint(label: 'Куда', value: toAddr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routePoint({required String label, required String value}) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.regular(fontSize: 10, color: c.inkSoft)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppText.medium(
            fontSize: 13,
            color: c.ink,
          ).copyWith(height: 1.4),
        ),
      ],
    );
  }

  // ── Details block (transport + recipient + counterparty) ───────────────────
  Widget _buildDetailsBlock(
    bool isLocked,
    bool isShop,
    AppLocalizations words,
  ) {
    final c = AppColors.of(context);
    final String? transportType = widget.order['transport_type']?.toString();
    final String phone = (widget.order['client_phone'] ?? '').toString();
    final String? counterPhone = isShop
        ? widget.order['courier_phone']
        : widget.order['shop_phone'];
    final String courierName = widget.order['courier_name']?.toString() ?? '';

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
        if (!isLocked && counterPhone != null && counterPhone.isNotEmpty) ...[
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
    AppLocalizations words,
  ) {
    final c = AppColors.of(context);
    final double itemPrice = total - delivery;
    final double cashback = (widget.order['cashback_amount'] ?? 0.0).toDouble();

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
  Widget _buildImagesBlock(List pictures) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final String? fileId = pictures[i]['directus_files_id'];
          if (fileId == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => _openPhotoViewer(context, pictures, i),
            child: Hero(
              tag: 'photo_$fileId',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  '$_baseUrl/assets/$fileId?width=250&quality=80',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Builder(
                    builder: (ctx) {
                      final c = AppColors.of(ctx);
                      return Container(
                        width: 100,
                        color: c.borderSoft,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: c.inkSoft,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, List pictures, int initialIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _PhotoViewerScreen(
          pictures: pictures,
          initialIndex: initialIndex,
          baseUrl: _baseUrl,
        ),
      ),
    );
  }

  // ── Bottom action button ───────────────────────────────────────────────────
  Widget _buildActionButton(
    BuildContext context,
    String status,
    String orderId,
    bool isShop,
    AppLocalizations words,
  ) {
    final c = AppColors.of(context);
    final service = OrderService();
    if (status == 'completed' || status == 'canceled') {
      return const SizedBox.shrink();
    }

    if (isShop && (status == 'published' || status == 'active')) {
      return _DetailActionButton(
        label: words.cancelOrderBtn,
        color: c.errorMuted,
        filled: false,
        onTap: () => _showCancelReasonModal(context, orderId, service, words),
      );
    }

    if (!isShop) {
      if (status == 'published') {
        final authProv = context.watch<AuthProvider>();
        final int points = widget.order['points_amount'] ?? 0;
        final double balancePoints = authProv.balancePoints;
        final bool isRestricted =
            authProv.role == 'courier' && authProv.status == 'pending';
        final bool isUserActive =
            authProv.role == 'courier' && authProv.status == 'active';
        final bool isClient = authProv.role == 'client';

        return _DetailActionButton(
          label: words.takeOrder,
          color: c.ink,
          filled: true,
          onTap: () async {
            if (isRestricted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
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
                      const SizedBox(height: 24),
                      RestrictedAccessView(
                        onActionPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ).then((_) => widget.onUpdate?.call());
            } else if (isUserActive) {
              final activeCount = await service.getActiveOrdersCount(
                widget.currentUserId,
              );
              if (!context.mounted) return;
              if (activeCount >= 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(words.tooManyOrders),
                    backgroundColor: c.errorMuted,
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
                      ? words.confirmWithPoints.replaceAll(
                          '{points}',
                          '$points',
                        )
                      : words.confirmNoPoints,
                  actionColor: c.ink,
                  words: words,
                  action: () => service.updateStatus(
                    orderId,
                    'active',
                    userId: widget.currentUserId,
                  ),
                );
              } else {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  builder: (_) => TopUpModal(
                    userId: widget.currentUserId,
                    role: widget.role,
                    status: status,
                  ),
                ).then((_) => widget.onUpdate?.call());
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
              ).then((_) => widget.onUpdate?.call());
            }
          },
        );
      }

      if (status == 'active') {
        double cashback = 0.0;
        if (!_isExpired) {
          cashback = (widget.order['cashback_amount'] ?? 0.0).toDouble();
        }

        return _DetailActionButton(
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
                  _DetailActionButton(
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
                  _DetailActionButton(
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
                            _showCashbackSuccessModal(
                              context,
                              cashback,
                              xpEarned,
                              words,
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

// ── Detail action button — spring press ──────────────────────────────────────

class _DetailActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final bool filled;
  final bool isLoading;
  final VoidCallback onTap;

  const _DetailActionButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  State<_DetailActionButton> createState() => _DetailActionButtonState();
}

class _DetailActionButtonState extends State<_DetailActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: widget.filled
                ? (widget.isLoading
                      ? widget.color.withValues(alpha: 0.4)
                      : widget.color)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: widget.filled
                ? null
                : Border.all(
                    color: widget.color.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
            boxShadow: widget.filled && !widget.isLoading
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  widget.label,
                  style: AppText.semiBold(
                    fontSize: 14,
                    color: widget.filled ? Colors.white : widget.color,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Photo viewer ──────────────────────────────────────────────────────────────

class _PhotoViewerScreen extends StatefulWidget {
  final List pictures;
  final int initialIndex;
  final String baseUrl;

  const _PhotoViewerScreen({
    required this.pictures,
    required this.initialIndex,
    required this.baseUrl,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.pictures.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: total > 1
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_current + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: total,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final String? fileId = widget.pictures[i]['directus_files_id'];
              if (fileId == null) return const SizedBox.shrink();
              final url =
                  '${widget.baseUrl}/assets/$fileId?width=1200&quality=95';
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: 'photo_$fileId',
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                : null,
                            color: AppColors.of(context).ink,
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (total > 1)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final isActive = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
