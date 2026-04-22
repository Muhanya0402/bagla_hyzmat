import 'package:bagla/features/home/home_screen.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailScreen extends StatelessWidget {
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

  static const String _baseUrl = 'http://192.168.10.173:8055';

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
        if (onUpdate != null) onUpdate!();
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

  @override
  Widget build(BuildContext context) {
    final status = (order['order_status'] ?? 'published')
        .toString()
        .toLowerCase();
    final isShop = role == 'shop' || role == 'business';
    // Номера скрыты только для курьера, если заказ еще "свободен"
    final bool isDataLocked = !isShop && status == 'published';

    final String orderId = order['id'].toString();
    final double total = (order['total_amount'] ?? 0.0).toDouble();
    final double delivery = (order['delivery_amount'] ?? 0.0).toDouble();
    final List pictures = order['pictures'] is List ? order['pictures'] : [];

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

          // Блок связи со второй стороной (Магазин <-> Курьер)
          if (!isDataLocked &&
              (order['courierId'] != null || order['shopId'] != null)) ...[
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

          if ((order['comment'] ?? '').toString().isNotEmpty) ...[
            _buildSection(
              title: "Комментарий",
              child: Text(
                order['comment'].toString(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                  height: 1.5,
                ),
              ),
            ),
          ],
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

  // Новый виджет для связи с Магазином или Курьером
  Widget _buildCounterpartyBlock(bool isShop) {
    String? phone;
    String? name;
    IconData icon;

    if (isShop) {
      // Магазин видит курьера
      phone = order['courier_phone'];
      icon = Icons.delivery_dining_outlined;
    } else {
      // Курьер видит магазин
      phone = order['shop_phone'];
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
    final String phone = (order['client_phone'] ?? '').toString();
    final String name = 'Клиент';

    return Row(
      children: [
        Expanded(
          child: _buildInfoRow(
            icon: Icons.person_outline,
            label: isLocked ? "Телефон скрыт" : name,
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
          value: order['shop_adress'] ?? '—',
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
              : (order['adress_of_delivery'] ?? '—'),
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
    return Column(
      children: [
        _buildPriceRow(
          label: "Товар",
          value: "${itemPrice.toStringAsFixed(0)} TMT",
          valueColor: const Color(0xFF0F1117),
        ),
        const SizedBox(height: 10),
        _buildPriceRow(
          label: "Доставка",
          value: "${delivery.toStringAsFixed(0)} TMT",
          valueColor: HomeScreen.brandGreen,
        ),
        const Divider(color: Color(0xFFF1F4F8), height: 20),
        _buildPriceRow(
          label: isShop ? "К получению" : "Выплата",
          value: isShop
              ? "${itemPrice.toStringAsFixed(0)} TMT"
              : "${delivery.toStringAsFixed(0)} TMT",
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
        onTap: () => _confirmAction(
          context: context,
          title: "Отмена",
          message: "Удалить заказ?",
          actionColor: HomeScreen.brandRed,
          action: () => service.updateStatus(orderId, 'canceled'),
        ),
      );
    }

    if (!isShop) {
      if (status == 'published') {
        final authProv = context.watch<AuthProvider>();
        final int points = order['points_amount'] ?? 0;
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
              // показываем RestrictedAccessView в bottom sheet
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
                    userId: currentUserId,
                  ),
                );
              } else {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => TopUpModal(
                    userId: currentUserId,
                    role: role,
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
        final double cashback = (order['cashback_amount'] ?? 0.0).toDouble();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кнопка отмены для курьера
            GestureDetector(
              onTap: () => _showCancelReasonModal(context, orderId, service),
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: HomeScreen.brandRed.withOpacity(0.4),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Отменить заказ",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: HomeScreen.brandRed,
                  ),
                ),
              ),
            ),
            // Кнопка завершить с кешбеком
            _buildButton(
              label: cashback > 0
                  ? "Завершить  •  +${cashback.toStringAsFixed(0)} баллов"
                  : "Завершить доставку",
              color: HomeScreen.brandBlue,
              filled: true,
              onTap: () => _confirmAction(
                context: context,
                title: "Завершить заказ",
                message: cashback > 0
                    ? "Вам будет начислено ${cashback.toStringAsFixed(0)} баллов. Подтвердить?"
                    : "Заказ передан клиенту?",
                actionColor: HomeScreen.brandBlue,
                action: () => service.updateStatus(orderId, 'completed'),
              ),
            ),
          ],
        );
      }
    }
    return const SizedBox.shrink();
  }

  // Добавить метод в OrderDetailScreen (аналог из OrderCard):
  Future<void> _showCancelReasonModal(
    BuildContext context,
    String orderId,
    OrderService service,
  ) async {
    final TextEditingController reasonController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0F3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Причина отмены",
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Укажите причину...",
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF9AA3AF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: HomeScreen.brandRed),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFEEF0F3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Назад",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final reason = reasonController.text.trim();
                        if (reason.isEmpty) return;
                        Navigator.pop(ctx);
                        await service.updateStatus(
                          orderId,
                          'canceled',
                          cancelReason: reason,
                        );
                        if (onUpdate != null) onUpdate!();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: HomeScreen.brandRed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Отменить",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
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
