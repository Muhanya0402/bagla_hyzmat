import 'dart:async';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/base_url.dart';
import 'package:bagla/features/home/home_screen.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const String _baseUrl = BaseUrl.url;

  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isExpired = false;

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _gradient = LinearGradient(
    colors: [_green, _red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  void initState() {
    super.initState();
    _startCountdown();
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
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
                  gradient: _gradient,
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
                      child: _dialogBtn(
                        'Назад',
                        Colors.transparent,
                        const Color(0xFF9AA3AF),
                        bordered: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: _dialogBtn(
                        'Подтвердить',
                        actionColor,
                        Colors.white,
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
              content: const Text('Ошибка сети. Попробуйте позже.'),
              backgroundColor: _red,
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

  static Widget _dialogBtn(
    String text,
    Color bg,
    Color textColor, {
    bool bordered = false,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: bordered ? Border.all(color: const Color(0xFFEEF0F3)) : null,
      ),
      alignment: Alignment.center,
      child: Text(text, style: AppText.medium(fontSize: 14, color: textColor)),
    );
  }

  // ── Cashback success dialog ───────────────────────────────────────────────
  void _showCashbackSuccessModal(
    BuildContext context,
    double points,
    int xpEarned,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_green.withOpacity(0.12), _red.withOpacity(0.08)],
                  ),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _green,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (b) => _gradient.createShader(b),
                child: Text(
                  'Заказ выполнен!',
                  style: AppText.extraBold(fontSize: 20, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Вы доставили заказ вовремя',
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF9AA3AF),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // ── Кэшбек ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _green.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/point_icon.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.toll_rounded,
                        color: _green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${points.toDouble()} жетонов',
                      style: AppText.extraBold(fontSize: 22, color: _green),
                    ),
                  ],
                ),
              ),

              // ── XP ──
              if (xpEarned > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFF7C3AED),
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+$xpEarned XP',
                        style: AppText.extraBold(
                          fontSize: 22,
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Text(
                'кэшбек за своевременную доставку',
                style: AppText.regular(
                  fontSize: 12,
                  color: const Color(0xFF9AA3AF),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'ОТЛИЧНО!',
                      style: AppText.bold(
                        fontSize: 15,
                        color: Colors.white,
                      ).copyWith(letterSpacing: .5),
                    ),
                  ),
                ),
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
    final isShop = widget.role == 'shop' || widget.role == 'business';
    final isDataLocked = !isShop && status == 'published';
    final orderId = widget.order['id'].toString();
    final double total = (widget.order['total_amount'] ?? 0.0).toDouble();
    final double delivery = (widget.order['delivery_amount'] ?? 0.0).toDouble();
    final List pictures = widget.order['pictures'] is List
        ? widget.order['pictures']
        : [];
    final showCountdown =
        !isShop &&
        status == 'active' &&
        widget.order['time_of_delivery'] != null &&
        widget.order['time_of_delivery'].toString().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _green,
              size: 16,
            ),
          ),
        ),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Заказ',
                  style: AppText.semiBold(
                    fontSize: 17,
                    color: const Color(0xFF0F1117),
                  ),
                ),
                Text(
                  'ID: ${orderId.split('-').first.toUpperCase()}',
                  style: AppText.regular(
                    fontSize: 11,
                    color: const Color(0xFF9AA3AF),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildStatusCard(status),
          const SizedBox(height: 12),

          if (showCountdown) ...[
            _buildCountdownCard(),
            const SizedBox(height: 12),
          ],

          _buildSection(
            title: 'Маршрут',
            child: _buildRouteBlock(isDataLocked),
          ),
          const SizedBox(height: 12),

          _buildSection(
            title: 'Получатель (Клиент)',
            child: _buildRecipientBlock(isDataLocked),
          ),
          const SizedBox(height: 12),

          if (!isDataLocked &&
              (widget.order['courierId'] != null ||
                  widget.order['shopId'] != null)) ...[
            _buildSection(
              title: isShop ? 'Исполнитель' : 'Отправитель',
              child: _buildCounterpartyBlock(isShop),
            ),
            const SizedBox(height: 12),
          ],

          _buildSection(
            title: 'Стоимость',
            child: _buildPriceBlock(isShop, total, delivery),
          ),
          const SizedBox(height: 12),

          if (pictures.isNotEmpty) ...[
            _buildSection(
              title: 'Фото товара',
              child: _buildImagesBlock(pictures),
            ),
            const SizedBox(height: 12),
          ],

          if ((widget.order['comment'] ?? '').toString().isNotEmpty)
            _buildSection(
              title: 'Комментарий',
              child: Text(
                widget.order['comment'].toString(),
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildActionButton(context, status, orderId, isShop),
        ),
      ),
    );
  }

  // ── Section wrapper ────────────────────────────────────────────────────────
  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
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
                  gradient: _gradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: AppText.semiBold(
                  fontSize: 10,
                  color: const Color(0xFF9AA3AF),
                ).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── Status card ────────────────────────────────────────────────────────────
  Widget _buildStatusCard(String status) {
    const styles = {
      'published': _StatusStyle(
        color: _red,
        label: 'Свободный заказ',
        icon: Icons.search_rounded,
        description: 'Ожидает курьера',
      ),
      'active': _StatusStyle(
        color: _green,
        label: 'В работе',
        icon: Icons.local_shipping_outlined,
        description: 'Курьер в пути',
      ),
      'completed': _StatusStyle(
        color: _green,
        label: 'Доставлен',
        icon: Icons.check_circle_outline_rounded,
        description: 'Заказ выполнен',
      ),
      'canceled': _StatusStyle(
        color: Color(0xFF9AA3AF),
        label: 'Отменён',
        icon: Icons.cancel_outlined,
        description: 'Заказ отменён',
      ),
    };
    final s = styles[status] ?? styles['published']!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.label,
                style: AppText.semiBold(fontSize: 15, color: s.color),
              ),
              Text(
                s.description,
                style: AppText.regular(
                  fontSize: 12,
                  color: s.color.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Gradient accent dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.color,
              boxShadow: [
                BoxShadow(
                  color: s.color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Countdown card ─────────────────────────────────────────────────────────
  Widget _buildCountdownCard() {
    final double cashback = (widget.order['cashback_amount'] ?? 0.0).toDouble();
    final Color color = _isExpired ? _red : _green;
    final Color bgColor = color.withOpacity(0.06);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isExpired ? 'Время истекло' : 'До истечения кэшбека',
                  style: AppText.regular(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isExpired
                      ? 'Кэшбек не будет начислен'
                      : _formatDuration(_timeLeft),
                  style: AppText.extraBold(fontSize: 22, color: color),
                ),
              ],
            ),
          ),
          if (!_isExpired && cashback > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Кэшбек',
                  style: AppText.regular(
                    fontSize: 11,
                    color: const Color(0xFF9AA3AF),
                  ),
                ),
                Row(
                  children: [
                    Image.asset(
                      'assets/images/point_icon.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.toll_rounded,
                        size: 20,
                        color: _green,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${cashback.toDouble()}',
                      style: AppText.bold(fontSize: 16, color: _green),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Route block ────────────────────────────────────────────────────────────
  Widget _buildRouteBlock(bool isLocked) {
    // Формируем адрес с районом
    final dynamic district = widget.order['district'];
    String districtName = '';
    if (district is Map) {
      districtName = district['district_ru']?.toString() ?? '';
    }
    final String deliveryAddress = widget.order['adress_of_delivery'] ?? '—';
    final String fullDeliveryAddress = districtName.isNotEmpty
        ? '$districtName, $deliveryAddress'
        : deliveryAddress;

    return Column(
      children: [
        _buildRoutePoint(
          icon: Icons.inventory_2_outlined,
          label: 'Откуда',
          value: widget.order['shop_adress'] ?? '—',
          color: _red,
        ),
        const SizedBox(height: 12),
        _buildRoutePoint(
          icon: isLocked
              ? Icons.lock_outline_rounded
              : Icons.location_on_outlined,
          label: 'Куда',
          value: isLocked ? 'Адрес скрыт' : fullDeliveryAddress, // 👈
          color: isLocked ? const Color(0xFF9AA3AF) : _green,
          isGrey: isLocked,
        ),
      ],
    );
  }

  Widget _buildRoutePoint({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isGrey = false,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
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
                value,
                style: AppText.mono(
                  fontSize: 14,
                  color: isGrey
                      ? const Color(0xFF9AA3AF)
                      : const Color(0xFF0F1117),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Recipient / counterparty ───────────────────────────────────────────────
  Widget _buildRecipientBlock(bool isLocked) {
    final String phone = (widget.order['client_phone'] ?? '').toString();
    return Row(
      children: [
        Expanded(
          child: _buildInfoRow(
            icon: Icons.person_outline,
            label: isLocked ? 'Телефон скрыт' : 'Клиент',
            value: isLocked ? '+993 ••• •• ••' : (phone.isEmpty ? '—' : phone),
            color: _green,
          ),
        ),
        if (phone.isNotEmpty && !isLocked) _buildCallButton(phone),
      ],
    );
  }

  Widget _buildCounterpartyBlock(bool isShop) {
    final String? phone = isShop
        ? widget.order['courier_phone']
        : widget.order['shop_phone'];
    final IconData icon = isShop
        ? Icons.delivery_dining_outlined
        : Icons.storefront_outlined;
    if (phone == null || phone.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: _buildInfoRow(
            icon: icon,
            label: isShop ? 'Курьер' : 'Заказчик',
            value: phone,
            color: _red,
          ),
        ),
        _buildCallButton(phone),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
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
                value,
                style: AppText.mono(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCallButton(String phone) {
    return GestureDetector(
      onTap: () => _makePhoneCall(phone),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_green, Color(0xFF22963F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.call, color: Colors.white, size: 20),
      ),
    );
  }

  // ── Price block ────────────────────────────────────────────────────────────
  Widget _buildPriceBlock(bool isShop, double total, double delivery) {
    final double itemPrice = total - delivery;
    final double cashback = (widget.order['cashback_amount'] ?? 0.0).toDouble();

    return Column(
      children: [
        _priceRow(
          'Товар',
          '${itemPrice.toStringAsFixed(0)} TMT',
          const Color(0xFF0F1117),
        ),
        const SizedBox(height: 10),
        _priceRow('Доставка', '${delivery.toStringAsFixed(0)} TMT', _green),
        if (!isShop && cashback > 0) ...[
          const SizedBox(height: 10),
          _priceRow('Кэшбек (20%)', '+${cashback.toDouble()} жетонов', _green),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Color(0xFFF1F4F8), height: 1),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isShop ? 'К получению' : 'Выплата',
              style: AppText.semiBold(fontSize: 14),
            ),
            ShaderMask(
              shaderCallback: (b) => _gradient.createShader(b),
              child: Text(
                isShop
                    ? '${itemPrice.toStringAsFixed(0)} TMT'
                    : '${delivery.toStringAsFixed(0)} TMT',
                style: AppText.semiBold(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.regular(fontSize: 13)),
        Text(value, style: AppText.mono(fontSize: 14, color: valueColor)),
      ],
    );
  }

  // ── Images ─────────────────────────────────────────────────────────────────
  Widget _buildImagesBlock(List pictures) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final String? fileId = pictures[i]['directus_files_id'];
          if (fileId == null) return const SizedBox.shrink();
          final url = '$_baseUrl/assets/$fileId?width=250&quality=80';
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              url,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 110,
                color: const Color(0xFFF1F4F8),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Action button ──────────────────────────────────────────────────────────
  Widget _buildActionButton(
    BuildContext context,
    String status,
    String orderId,
    bool isShop,
  ) {
    final service = OrderService();
    if (status == 'completed' || status == 'canceled') {
      return const SizedBox.shrink();
    }

    // Shop cancel
    if (isShop && (status == 'published' || status == 'active')) {
      return _actionBtn(
        label: 'Отменить заказ',
        color: _red,
        filled: false,
        onTap: () => _showCancelReasonModal(context, orderId, service),
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

        return _actionBtn(
          label: 'Взять заказ',
          color: _green,
          filled: true,
          onTap: () {
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
              ).then((_) => widget.onUpdate?.call()); // авто-рефреш
            } else if (isUserActive) {
              if (balancePoints >= points) {
                _confirmAction(
                  context: context,
                  title: 'Принять заказ',
                  message: points > 0
                      ? 'С вашего баланса будет списано $points баллов. Приступить?'
                      : 'Заказ будет закреплён за вами. Приступить?',
                  actionColor: _green,
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
                ).then((_) => widget.onUpdate?.call()); // авто-рефреш
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
              ).then((_) => widget.onUpdate?.call()); // авто-рефреш
            }
          },
        );
      }

      if (status == 'active') {
        final double cashback = (widget.order['cashback_amount'] ?? 0.0)
            .toDouble();
        return _actionBtn(
          label: cashback > 0
              ? 'Завершить  •  +${cashback.toDouble()} баллов'
              : 'Завершить доставку',
          color: _green,
          filled: true,
          onTap: () => _showDeliveryCodeModal(context, orderId, service),
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
  ) async {
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
                _handle(),
                const SizedBox(height: 24),
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: codeSent
                          ? [_green.withOpacity(0.1), _green.withOpacity(0.05)]
                          : [_red.withOpacity(0.1), _red.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    codeSent
                        ? Icons.dialpad_rounded
                        : Icons.lock_outline_rounded,
                    color: codeSent ? _green : _red,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                // Gradient title
                ShaderMask(
                  shaderCallback: (b) => _gradient.createShader(b),
                  child: Text(
                    'Подтверждение доставки',
                    style: AppText.bold(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  codeSent
                      ? 'Введите код который получил клиент по SMS'
                      : 'Нажмите кнопку — клиент получит код по SMS',
                  style: AppText.regular(
                    fontSize: 13,
                    color: const Color(0xFF9AA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (!codeSent) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                setS(() => isLoading = true);
                                final result = await service
                                    .generateDeliveryCode(
                                      orderId: orderId,
                                      courierId: widget.currentUserId,
                                      clientPhone:
                                          widget.order['client_phone'] ?? '',
                                    );
                                setS(() {
                                  isLoading = false;
                                  if (result['success'] == true) {
                                    codeSent = true;
                                  }
                                });
                                if (result['success'] != true && ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Ошибка отправки кода',
                                      ),
                                      backgroundColor: _red,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'ОТПРАВИТЬ КОД КЛИЕНТУ',
                                style: AppText.bold(
                                  fontSize: 14,
                                  color: Colors.white,
                                ).copyWith(letterSpacing: .5),
                              ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Code input
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: AppText.bold(
                      fontSize: 28,
                      color: const Color(0xFF0F1117),
                    ).copyWith(letterSpacing: 8),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • •',
                      hintStyle: AppText.regular(
                        fontSize: 28,
                        color: const Color(0xFFD1D5DB),
                      ).copyWith(letterSpacing: 8),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _gradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
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
                                      (widget.order['cashback_amount'] ?? 0.0)
                                          .toDouble();
                                  final int xpEarned = result['xp_earned'] ?? 0;

                                  // Кэшбек начисляем без await — не блокируем UI
                                  service.applyCashbackIfOnTime(
                                    orderId: orderId,
                                    courierId: widget.currentUserId,
                                  );

                                  Navigator.pop(ctx);
                                  if (widget.onUpdate != null)
                                    widget.onUpdate!();

                                  if (context.mounted) {
                                    if (cashback > 0 && !_isExpired) {
                                      _showCashbackSuccessModal(
                                        context,
                                        cashback,
                                        xpEarned,
                                      ); // 👈
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
                                          result['message'] ?? 'Неверный код',
                                        ),
                                        backgroundColor: _red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'ПОДТВЕРДИТЬ',
                                style: AppText.bold(
                                  fontSize: 14,
                                  color: Colors.white,
                                ).copyWith(letterSpacing: .5),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setS(() {
                            codeSent = false;
                            codeCtrl.clear();
                          }),
                    child: Text(
                      'Отправить код повторно',
                      style: AppText.regular(
                        fontSize: 13,
                        color: const Color(0xFF9AA3AF),
                      ),
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
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CancelReasonModal(
        orderId: orderId,
        currentUserId: widget.currentUserId,
        service: service,
        onSuccess: () => widget.onUpdate?.call(),
      ),
    ).then((_) => widget.onUpdate?.call()); // авто-рефреш
  }

  Widget _actionBtn({
    required String label,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: filled ? _gradient : null,
          color: filled ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: color.withOpacity(0.4)),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: _green.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.mono(
            fontSize: 15,
            color: filled ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  static Widget _handle() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F3),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _StatusStyle {
  final Color color;
  final String label;
  final IconData icon;
  final String description;
  const _StatusStyle({
    required this.color,
    required this.label,
    required this.icon,
    required this.description,
  });
}
