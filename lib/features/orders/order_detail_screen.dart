import 'dart:async';
import 'package:bagla/features/home/home_screen.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  static const String _baseUrl = 'http://192.168.10.173:8055';

  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final String? timeOfDelivery = widget.order['time_of_delivery'];
    if (timeOfDelivery == null || timeOfDelivery.isEmpty) return;

    final DateTime deadline = DateTime.parse(timeOfDelivery).toLocal();
    _updateTimeLeft(deadline);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft(deadline);
    });
  }

  void _updateTimeLeft(DateTime deadline) {
    final Duration diff = deadline.difference(DateTime.now());
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
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

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
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF9AA3AF),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: _buildDialogButton(
                    "Назад",
                    Colors.transparent,
                    const Color(0xFF9AA3AF),
                    isBordered: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: _buildDialogButton(
                    "Подтвердить",
                    actionColor,
                    Colors.white,
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
        if (widget.onUpdate != null) widget.onUpdate!();
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ошибка сети. Попробуйте позже."),
              backgroundColor: HomeScreen.brandRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  static Widget _buildDialogButton(
    String text,
    Color bg,
    Color textColor, {
    bool isBordered = false,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: isBordered ? Border.all(color: const Color(0xFFEEF0F3)) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  void _showCashbackSuccessModal(BuildContext context, double points) {
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
                  color: HomeScreen.brandGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: HomeScreen.brandGreen,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Заказ выполнен!',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F1117),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Вы доставили заказ вовремя',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF9AA3AF),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: HomeScreen.brandGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: HomeScreen.brandGreen.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/point_icon.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.toll_rounded,
                        color: HomeScreen.brandGreen,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '+$points жетонов',
                      style: GoogleFonts.montserrat(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: HomeScreen.brandGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'кэшбек за своевременную доставку',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF9AA3AF),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeScreen.brandGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'ОТЛИЧНО!',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
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

  @override
  Widget build(BuildContext context) {
    final status = (widget.order['order_status'] ?? 'published')
        .toString()
        .toLowerCase();
    final isShop = widget.role == 'shop' || widget.role == 'business';
    final bool isDataLocked = !isShop && status == 'published';
    final String orderId = widget.order['id'].toString();
    final double total = (widget.order['total_amount'] ?? 0.0).toDouble();
    final double delivery = (widget.order['delivery_amount'] ?? 0.0).toDouble();
    final List pictures = widget.order['pictures'] is List
        ? widget.order['pictures']
        : [];
    final bool showCountdown =
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
              color: HomeScreen.brandBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: HomeScreen.brandBlue,
              size: 16,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Заказ",
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1117),
              ),
            ),
            Text(
              "ID: ${orderId.split('-').first.toUpperCase()}",
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9AA3AF),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildStatusCard(status),
          const SizedBox(height: 12),

          // Обратный отсчёт для курьера
          if (showCountdown) ...[
            _buildCountdownCard(),
            const SizedBox(height: 12),
          ],

          _buildSection(
            title: "Маршрут",
            child: _buildRouteBlock(isDataLocked),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: "Получатель (Клиент)",
            child: _buildRecipientBlock(isDataLocked),
          ),
          const SizedBox(height: 12),

          if (!isDataLocked &&
              (widget.order['courierId'] != null ||
                  widget.order['shopId'] != null)) ...[
            _buildSection(
              title: isShop ? "Исполнитель" : "Отправитель",
              child: _buildCounterpartyBlock(isShop),
            ),
            const SizedBox(height: 12),
          ],

          _buildSection(
            title: "Стоимость",
            child: _buildPriceBlock(isShop, total, delivery),
          ),
          const SizedBox(height: 12),

          if (pictures.isNotEmpty) ...[
            _buildSection(
              title: "Фото товара",
              child: _buildImagesBlock(pictures),
            ),
            const SizedBox(height: 12),
          ],

          if ((widget.order['comment'] ?? '').toString().isNotEmpty)
            _buildSection(
              title: "Комментарий",
              child: Text(
                widget.order['comment'].toString(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                  height: 1.5,
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

  Widget _buildCountdownCard() {
    final double cashback = (widget.order['cashback_amount'] ?? 0.0).toDouble();
    final Color color = _isExpired
        ? HomeScreen.brandRed
        : HomeScreen.brandGreen;
    final Color bgColor = _isExpired
        ? HomeScreen.brandRed.withOpacity(0.06)
        : HomeScreen.brandGreen.withOpacity(0.06);

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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isExpired
                      ? 'Кэшбек не будет начислен'
                      : _formatDuration(_timeLeft),
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (!_isExpired && cashback > 0) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Кэшбек',
                  style: GoogleFonts.inter(
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
                        color: HomeScreen.brandGreen,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${cashback.toDouble()}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HomeScreen.brandGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCounterpartyBlock(bool isShop) {
    String? phone;
    IconData icon;
    if (isShop) {
      phone = widget.order['courier_phone'];
      icon = Icons.delivery_dining_outlined;
    } else {
      phone = widget.order['shop_phone'];
      icon = Icons.storefront_outlined;
    }
    if (phone == null || phone.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: _buildInfoRow(
            icon: icon,
            label: isShop ? "Курьер" : "Магазин",
            value: phone,
            color: HomeScreen.brandBlue,
          ),
        ),
        _buildPhoneActionButton(phone),
      ],
    );
  }

  Widget _buildRecipientBlock(bool isLocked) {
    final String phone = (widget.order['client_phone'] ?? '').toString();
    return Row(
      children: [
        Expanded(
          child: _buildInfoRow(
            icon: Icons.person_outline,
            label: isLocked ? "Телефон скрыт" : "Клиент",
            value: isLocked ? "+993 ••• •• ••" : (phone.isEmpty ? '—' : phone),
            color: HomeScreen.brandGreen,
          ),
        ),
        if (phone.isNotEmpty && !isLocked) _buildPhoneActionButton(phone),
      ],
    );
  }

  Widget _buildPhoneActionButton(String phone) {
    return GestureDetector(
      onTap: () => _makePhoneCall(phone),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: HomeScreen.brandGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.call, color: HomeScreen.brandGreen, size: 20),
      ),
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
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF9AA3AF),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F1117),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String status) {
    final Map<String, _StatusStyle> styles = {
      'published': _StatusStyle(
        color: HomeScreen.brandRed,
        label: "Свободный заказ",
        icon: Icons.search_rounded,
        description: "Ожидает курьера",
      ),
      'active': _StatusStyle(
        color: HomeScreen.brandBlue,
        label: "В работе",
        icon: Icons.local_shipping_outlined,
        description: "Курьер в пути",
      ),
      'completed': _StatusStyle(
        color: HomeScreen.brandGreen,
        label: "Доставлен",
        icon: Icons.check_circle_outline_rounded,
        description: "Заказ выполнен",
      ),
      'canceled': _StatusStyle(
        color: const Color(0xFF9AA3AF),
        label: "Отменён",
        icon: Icons.cancel_outlined,
        description: "Заказ отменён",
      ),
    };
    final style = styles[status] ?? styles['published']!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(style.icon, color: style.color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                style.label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: style.color,
                ),
              ),
              Text(
                style.description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: style.color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9AA3AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildRouteBlock(bool isLocked) {
    return Column(
      children: [
        _buildRoutePoint(
          icon: Icons.inventory_2_outlined,
          label: "Откуда",
          value: widget.order['shop_adress'] ?? '—',
          color: HomeScreen.brandRed,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 17),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 2,
              height: 20,
              color: const Color(0xFFEEF0F3),
            ),
          ),
        ),
        _buildRoutePoint(
          icon: Icons.location_on_outlined,
          label: "Куда",
          value: isLocked
              ? "Адрес скрыт"
              : (widget.order['adress_of_delivery'] ?? '—'),
          color: HomeScreen.brandGreen,
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
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF9AA3AF),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isGrey ? Colors.grey : const Color(0xFF0F1117),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBlock(bool isShop, double total, double delivery) {
    final double itemPrice = total - delivery;
    final double cashback = (widget.order['cashback_amount'] ?? 0.0).toDouble();
    return Column(
      children: [
        _buildPriceRow(
          label: "Товар",
          value: "${itemPrice.toDouble()} TMT",
          valueColor: const Color(0xFF0F1117),
        ),
        const SizedBox(height: 10),
        _buildPriceRow(
          label: "Доставка",
          value: "${delivery.toDouble()} TMT",
          valueColor: HomeScreen.brandGreen,
        ),
        if (!isShop && cashback > 0) ...[
          const SizedBox(height: 10),
          _buildPriceRow(
            label: "Кэшбек (20%)",
            value: "+${cashback.toDouble()} жетонов",
            valueColor: HomeScreen.brandGreen,
          ),
        ],
        const Divider(color: Color(0xFFF1F4F8), height: 20),
        _buildPriceRow(
          label: isShop ? "К получению" : "Выплата",
          value: isShop
              ? "${itemPrice.toDouble()} TMT"
              : "${delivery.toDouble()} TMT",
          valueColor: HomeScreen.brandBlue,
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildPriceRow({
    required String label,
    required String value,
    required Color valueColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

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
          final String imageUrl =
              "$_baseUrl/assets/$fileId?width=250&quality=80";
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              imageUrl,
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

  Widget _buildActionButton(
    BuildContext context,
    String status,
    String orderId,
    bool isShop,
  ) {
    final OrderService service = OrderService();
    if (status == 'completed' || status == 'canceled')
      return const SizedBox.shrink();

    if (isShop && status == 'published') {
      return _buildButton(
        label: "Отменить заказ",
        color: HomeScreen.brandRed,
        filled: false,
        onTap: () => _showCancelReasonModal(context, orderId, service),
      );
    }

    if (!isShop) {
      if (status == 'published') {
        final authProv = context.watch<AuthProvider>();
        final int points = widget.order['points_amount'] ?? 0;
        final balancePoints = authProv.balancePoints;
        final bool isRestricted =
            authProv.role == 'courier' && authProv.status == 'pending';
        final bool isActive =
            authProv.role == 'courier' && authProv.status == 'active';
        final bool isClient = authProv.role == 'client';

        return _buildButton(
          label: "Взять заказ",
          color: HomeScreen.brandGreen,
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
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF0F3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      RestrictedAccessView(
                        onActionPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              );
            } else if (isActive) {
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
                    userId: widget.currentUserId,
                  ),
                );
              } else {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => TopUpModal(
                    userId: widget.currentUserId,
                    role: widget.role,
                    status: status,
                  ),
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
      } else if (status == 'active') {
        final double cashback = (widget.order['cashback_amount'] ?? 0.0)
            .toDouble();
        return _buildButton(
          label: cashback > 0
              ? "Завершить  •  +${cashback.toDouble()} баллов"
              : "Завершить доставку",
          color: HomeScreen.brandBlue,
          filled: true,
          onTap: () => _showDeliveryCodeModal(context, orderId, service),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Future<void> _showDeliveryCodeModal(
    BuildContext context,
    String orderId,
    OrderService service,
  ) async {
    final TextEditingController codeController = TextEditingController();
    bool isLoading = false;
    bool codeSent = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0F3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: HomeScreen.brandBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: HomeScreen.brandBlue,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Подтверждение доставки',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F1117),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  codeSent
                      ? 'Введите код который получил клиент по SMS'
                      : 'Нажмите кнопку — клиент получит код по SMS',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF9AA3AF),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (!codeSent) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeScreen.brandBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setModalState(() => isLoading = true);
                              final result = await service.generateDeliveryCode(
                                orderId: orderId,
                                courierId: widget.currentUserId,
                                clientPhone: widget.order['client_phone'] ?? '',
                              );
                              setModalState(() {
                                isLoading = false;
                                if (result['success'] == true) codeSent = true;
                              });
                              if (result['success'] != true && ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ошибка отправки кода'),
                                    backgroundColor: HomeScreen.brandRed,
                                    behavior: SnackBarBehavior.floating,
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
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      color: const Color(0xFF0F1117),
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • •',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 28,
                        letterSpacing: 8,
                        color: const Color(0xFFD1D5DB),
                      ),
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
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeScreen.brandGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              final code = codeController.text.trim();
                              if (code.length != 4) return;

                              setModalState(() => isLoading = true);
                              final result = await service.verifyDeliveryCode(
                                orderId: orderId,
                                code: code,
                              );
                              setModalState(() => isLoading = false);

                              if (result['success'] == true) {
                                // Начисляем кэшбек
                                final double cashback =
                                    (widget.order['cashback_amount'] ?? 0.0)
                                        .toDouble();
                                await service.applyCashbackIfOnTime(
                                  orderId: orderId,
                                  courierId: widget.currentUserId,
                                );

                                Navigator.pop(ctx);
                                if (widget.onUpdate != null) widget.onUpdate!();

                                // Показываем алерт если кэшбек начислен
                                if (context.mounted &&
                                    cashback > 0 &&
                                    !_isExpired) {
                                  _showCashbackSuccessModal(
                                    context,
                                    cashback.toDouble(),
                                  );
                                } else if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              } else {
                                codeController.clear();
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result['message'] ?? 'Неверный код',
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
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setModalState(() {
                            codeSent = false;
                            codeController.clear();
                          }),
                    child: Text(
                      'Отправить код повторно',
                      style: GoogleFonts.inter(
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
        currentUserId: widget.currentUserId, // исправлено
        service: service,
        onSuccess: () {
          if (widget.onUpdate != null) widget.onUpdate!(); // исправлено
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildButton({
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
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: color.withOpacity(0.4)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: filled ? Colors.white : color,
          ),
        ),
      ),
    );
  }
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
