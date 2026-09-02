import 'dart:async';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/orders/courier_report_service.dart';
import 'package:bagla/features/orders/edit_amount_modal.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/orders/return_order_flow.dart';
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

  /// Авто-открытие формы подтверждения завершения заказа сразу после входа.
  /// Используется при переходе из sticky-уведомления «Активные заказы»
  /// по кнопке «Завершить» — курьер сразу попадает на форму ввода кода.
  final bool autoOpenFinish;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.role,
    required this.currentUserId,
    this.onUpdate,
    this.autoOpenFinish = false,
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

    // Кнопка действия есть только для активных/свободных заказов. Для
    // завершённого/отменённого _buildActionButton возвращает SizedBox.shrink(),
    // и шаг тура «Действие» подсвечивал бы пустую полоску внизу — поэтому в
    // таких статусах этот шаг не показываем.
    final status = (widget.order['order_status'] ?? '').toString();
    final hasAction = status == 'published' || status == 'active';

    return [
      TourTarget.build(
        id: 'order_detail_0',
        key: _routeKey,
        title: words.tourOrderRouteTitle,
        body: words.tourOrderRouteBody,
        isLast: !hasAction,
        align: ContentAlign.bottom,
      ),
      if (hasAction)
        TourTarget.build(
          id: 'order_detail_1',
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
    _a0 = _ia(0.0, 0.45);
    _a1 = _ia(s ? 0.0 : 0.1, s ? 0.45 : 0.55);
    _a2 = _ia(s ? 0.1 : 0.2, s ? 0.55 : 0.65);
    _a3 = _ia(s ? 0.2 : 0.3, s ? 0.65 : 0.75);
    _a4 = _ia(s ? 0.3 : 0.4, s ? 0.75 : 0.85);
    _a5 = _ia(s ? 0.35 : 0.45, s ? 0.8 : 0.9);
    WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
    // При входе из уведомления «Завершить» — не показываем тур, сразу
    // открываем форму подтверждения завершения.
    if (widget.autoOpenFinish) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final orderId = (widget.order['id'] ?? '').toString();
        final status = (widget.order['order_status'] ?? '').toString();
        if (orderId.isEmpty || status != 'active' || widget.role == 'shop') {
          return;
        }
        final words = context.read<LanguageProvider>().words;
        _showDeliveryCodeModal(context, orderId, OrderService(), words);
      });
    } else {
      startTourIfNeeded(
        screenKey: TourKeys.orderDetail,
        targetsBuilder: _buildTourTargets,
        shouldSkip: () => context.read<AuthProvider>().shouldSkipTour,
      );
    }
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
    // Пустой список — у заказа фото нет вовсе (например, заказ из кафе, где
    // фотографировать нечего). Раньше сюда попадали и делали лишний запрос
    // при КАЖДОМ открытии такого заказа. Секция фото и так не отрисуется.
    if (cached is List && cached.isEmpty) return;

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
    final isCourier = widget.role == 'courier';
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
          //    Показываем для статусов active или published. После завершения
          //    (completed/canceled) таймер кэшбека НЕ тикает.
          //    ТОЛЬКО курьеру: кэшбек — его награда за доставку в срок,
          //    заказчику (магазин/клиент) он не релевантен.
          if (isCourier &&
              (dto.status == 'active' || dto.status == 'published'))
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
          if (isCourier &&
              (dto.status == 'active' || dto.status == 'published'))
            const SizedBox(height: 10),

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
                  style: AppText.regular(
                    fontSize: 13,
                    color: c.ink,
                  ).copyWith(height: 1.5),
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
      // Заказ закрыт — действий почти нет, но сутки после закрытия магазин
      // может пожаловаться на курьера. Позже кнопку прячем: жалобы по
      // горячим следам разбирать честнее, чем спустя неделю.
      if (isShop &&
          CourierReportService.canReport(
            status: status,
            closedAt: dto.closedAt,
            courierId: dto.courierItemId,
          )) {
        return OrderPrimaryButton(
          label: words.reportCourierBtn,
          color: c.errorMuted,
          filled: false,
          onTap: () => _showReportModal(context, dto, words),
        );
      }
      return const SizedBox.shrink();
    }

    if (isShop && (status == 'published' || status == 'active')) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrderPrimaryButton(
            label: words.editAmountBtn,
            color: c.ink,
            filled: false,
            onTap: () => _showEditAmountModal(context, dto, service, words),
          ),
          const SizedBox(height: 10),
          OrderPrimaryButton(
            label: words.cancelOrderBtn,
            color: c.errorMuted,
            filled: false,
            onTap: () => _showCancelReasonModal(context, orderId, service, words),
          ),
        ],
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
            // Телефон курьера ОБЯЗАТЕЛЕН. Раньше здесь передавалась пустая
            // строка с пометкой «на детальном экране его нет» — а он есть, в
            // профиле. Из-за этого у заказов, взятых с этого экрана, колонка
            // `courier_phone` оставалась пустой, и заказчик не видел строки
            // с кнопкой «Позвонить». Половина заказов в базе пострадала
            // именно так: взятые из карточки — с номером, взятые отсюда — без.
            courierPhone: context.read<AuthProvider>().phone,
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

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrderPrimaryButton(
              label: cashback > 0
                  ? words.finishWithCashback.replaceAll(
                      '{cashback}',
                      '${cashback.toDouble()}',
                    )
                  : words.finishOrder,
              color: c.ink,
              filled: true,
              onTap: () => _showDeliveryCodeModal(context, orderId, service, words),
            ),
            const SizedBox(height: 10),
            OrderPrimaryButton(
              label: words.returnOrder,
              color: c.errorMuted,
              filled: false,
              // После успешного отказа заказ больше не принадлежит курьеру,
              // а `dto` строится из `widget.order` и сам не перечитывается —
              // если экран оставить открытым, кнопки «Завершить»/«Отказаться»
              // остались бы для чужого уже заказа (нажатие «Завершить» ушло
              // бы на сервер по чужому заказу). Закрываем экран так же, как
              // при успешном взятии заказа (см. ветку `published` выше).
              onTap: () => ReturnOrderFlow.start(
                context,
                dto: dto,
                onUpdate: () {
                  widget.onUpdate?.call();
                  if (mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
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
                      // Захватываем messenger ДО await — после async-gap
                      // lookup через ctx ненадёжен (O3).
                      final messenger = ScaffoldMessenger.of(ctx);
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
                        messenger.showSnackBar(
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
                      final messenger = ScaffoldMessenger.of(
                        ctx,
                      ); // до await (O3)
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
                          messenger.showSnackBar(
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

  /// Шторка «Пожаловаться на курьера».
  ///
  /// Переиспользуем шторку выбора причины: набор закрытых вариантов плюс
  /// комментарий — ровно то, что нужно и здесь. Сервер разбирает жалобу сам
  /// и сам решает, начислять ли штрафные баллы.
  void _showReportModal(
    BuildContext context,
    OrderDto dto,
    AppLocalizations words,
  ) {
    final service = CourierReportService();
    var sent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => CancelReasonModal(
        words: words,
        title: words.reportCourierTitle,
        subtitle: words.reportCourierSubtitle,
        confirmLabel: words.reportCourierSend,
        reasons: [
          ReasonOption(
              id: 'rude',
              label: words.reportReasonRude,
              icon: Icons.sentiment_very_dissatisfied_outlined),
          ReasonOption(
              id: 'extortion',
              label: words.reportReasonExtortion,
              icon: Icons.playlist_add_check_circle_outlined),
          ReasonOption(
              id: 'no_door',
              label: words.reportReasonNoDoor,
              icon: Icons.stairs_outlined),
          ReasonOption(
              id: 'late',
              label: words.reportReasonLate,
              icon: Icons.timer_off_outlined),
          ReasonOption(
              id: 'no_contact',
              label: words.reportReasonNoContact,
              icon: Icons.phone_disabled_outlined),
          ReasonOption(
              id: 'not_delivered',
              label: words.reportReasonNotDelivered,
              icon: Icons.remove_shopping_cart_outlined),
        ],
        onSubmit: (reasonId, comment) async {
          final reason = ReportReason.values.firstWhere(
            (r) => r.id == reasonId,
            orElse: () => ReportReason.late,
          );
          final ok = await service.sendReport(
            orderId: dto.id,
            courierId: dto.courierItemId,
            shopId: widget.currentUserId,
            reason: reason,
            comment: comment,
          );
          sent = ok;
          // Закрываем в любом случае: повторная отправка той же жалобы
          // ничего не даст, а держать шторку открытой без объяснения хуже.
          return true;
        },
      ),
    ).then((_) {
      if (!context.mounted) return;
      final c = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent ? words.reportCourierSent : words.reportCourierFailed,
            style: AppText.regular(
              fontSize: 13,
              color: sent ? c.ink : c.errorMuted,
            ),
          ),
          backgroundColor: sent ? c.emeraldTint : c.errorTint,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    });
  }

  /// Шторка «Изменить сумму заказа» — только для магазина, пока заказ не
  /// закрыт. Курьеру уйдёт пуш: его шлёт флоу на изменение сумм заказа.
  void _showEditAmountModal(
    BuildContext context,
    OrderDto dto,
    OrderService service,
    AppLocalizations words,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => EditAmountModal(
        words: words,
        itemPrice: dto.totalAmount - dto.deliveryAmount,
        deliveryFee: dto.deliveryAmount,
        courierAssigned: dto.courierId.isNotEmpty,
        onSubmit: (itemPrice, deliveryFee) async {
          final ok = await service.updateAmounts(
            orderId: dto.id,
            itemPrice: itemPrice,
            deliveryFee: deliveryFee,
          );
          if (ok) {
            widget.onUpdate?.call();
            return true;
          }
          // Не закрываем шторку: введённое не потеряется, а сообщение об
          // ошибке шторка покажет у себя — снек за ней не виден.
          return false;
        },
      ),
    ).then((_) => widget.onUpdate?.call());
  }

  void _showCancelReasonModal(
    BuildContext context,
    String orderId,
    OrderService service,
    AppLocalizations words,
  ) {
    // Заказ мог стать терминальным уже после открытия шторки. В этом случае
    // сообщение показываем ПОСЛЕ её закрытия (в .then) — снек рисуется в
    // Scaffold этого экрана, а шторка лежит поверх него отдельным слоем
    // маршрутов, так что до закрытия шторки снек всё равно не виден.
    var showAlreadyClosedMessage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => CancelReasonModal(
        words: words,
        title: words.cancelReasonTitle,
        subtitle: words.cancelReasonSubtitle,
        confirmLabel: words.cancelOrder,
        reasons: [
          ReasonOption(id: 'client_refused',
              label: words.cancelReasonClientRefused, icon: Icons.person_off_outlined),
          ReasonOption(id: 'courier_late',
              label: words.cancelReasonCourierLate, icon: Icons.timer_off_outlined),
          ReasonOption(id: 'wrong_address',
              label: words.cancelReasonWrongAddress, icon: Icons.location_off_outlined),
          ReasonOption(id: 'other',
              label: words.cancelReasonOther, icon: Icons.help_outline_rounded),
        ],
        onSubmit: (reasonId, comment) async {
          final label = {
            'client_refused': words.cancelReasonClientRefused,
            'courier_late': words.cancelReasonCourierLate,
            'wrong_address': words.cancelReasonWrongAddress,
            'other': words.cancelReasonOther,
          }[reasonId]!;
          // CAS-отмена: применяется только если заказ ещё published/active.
          // Защита от отмены уже доставленного заказа при устаревшем UI магазина.
          final outcome = await service.cancelOrderIfOpen(
            orderId,
            cancelReason: label + (comment.isNotEmpty ? ': $comment' : ''),
            shopId: widget.currentUserId,
          );
          if (outcome == CancelOutcome.applied) {
            // Обновляем список — заказ пропал из ленты магазина после отмены.
            widget.onUpdate?.call();
            return true;
          }
          if (outcome == CancelOutcome.alreadyClosed) {
            // Повторять попытку бессмысленно — закрываем шторку, сообщение
            // покажем в .then(), когда шторка уже сойдёт с экрана.
            showAlreadyClosedMessage = true;
            return true;
          }
          return false;
        },
      ),
    ).then((_) {
      if (showAlreadyClosedMessage && context.mounted) {
        final c = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              words.orderAlreadyClosed,
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
      // Рефрешим — UI подтянет актуальный статус (в т.ч. терминальный).
      widget.onUpdate?.call();
    });
  }

  Widget _handle() => const SheetHandle(topPadding: 0);
}
