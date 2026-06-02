import 'dart:async';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/orders/take_order_flow.dart';
import 'package:bagla/features/orders/widgets/cashback_success_dialog.dart';
import 'package:bagla/features/orders/widgets/order_countdown_card.dart';
import 'package:bagla/features/orders/widgets/order_details_section.dart';
import 'package:bagla/features/orders/widgets/order_images_section.dart';
import 'package:bagla/features/orders/widgets/order_price_section.dart';
import 'package:bagla/features/orders/widgets/order_route_section.dart';
import 'package:bagla/features/orders/widgets/order_primary_button.dart';
import 'package:bagla/features/orders/widgets/order_status_badge.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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

  /// Pictures, подгруженные отдельным запросом в Directus.
  /// Изначально null → используем `dto.pictures` (что пришло в кэше списка).
  /// После fetch'а — этот список (всегда в формате `[{directus_files_id: ...}]`).
  /// Зачем: в `getOrders` (список) при некоторых permission-настройках
  /// pictures приходят как junction-IDs (int) → не отображаются.
  /// Точечный запрос на конкретный заказ обычно работает.
  List<dynamic>? _fetchedPictures;

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
    _loadPicturesIfNeeded();
  }

  /// Триггерим отдельный fetch только если в кэше списка картинки не
  /// в Map-формате (т.е. если они int junction-IDs — фолбэк `*` в getOrders).
  Future<void> _loadPicturesIfNeeded() async {
    final orderId = (widget.order['id'] ?? '').toString();
    if (orderId.isEmpty) return;
    final cached = widget.order['pictures'];
    // Если в кэше уже Map-формат — ничего не делаем, всё уже есть.
    if (cached is List && cached.isNotEmpty && cached.first is Map) return;

    final picsResult = await OrderService().getOrderPictures(orderId);
    if (!mounted) return;
    setState(() => _fetchedPictures = picsResult);
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
                child: OrderDetailsSection(
                  dto: dto,
                  isLocked: isDataLocked,
                  isShop: isShop,
                ),
              ),
            ),
            _a2,
          ),
          const SizedBox(height: 10),

          // ── Price ────────────────────────────────────────────────────────
          _animated(
            _section(
              title: words.priceSection,
              child: OrderPriceSection(
                isShop: isShop,
                total: dto.totalAmount,
                delivery: dto.deliveryAmount,
                cashback: dto.cashbackAmount,
              ),
            ),
            _a3,
          ),

          // ── Photos ───────────────────────────────────────────────────────
          // Если pictures загрузили отдельным запросом (`_fetchedPictures`) —
          // используем их (всегда в Map-формате). Иначе fallback на dto
          // (может быть Map-формат если list-запрос успел получить
          // explicit fields, или int junction IDs если был fallback на `*`).
          if (() {
            final pics = _fetchedPictures ?? dto.pictures;
            return pics.any((p) => p is Map);
          }()) ...[
            const SizedBox(height: 10),
            _animated(
              _section(
                title: words.photoSection,
                child: OrderImagesSection(
                  pictures: _fetchedPictures ?? dto.pictures,
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


  // ── Price block ────────────────────────────────────────────────────────────
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
            // После успешного «взять заказ» закрываем детальный экран —
            // курьер возвращается на главную и видит обновлённую ленту.
            onUpdate: () {
              widget.onUpdate?.call();
              if (mounted) Navigator.pop(context);
            },
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



