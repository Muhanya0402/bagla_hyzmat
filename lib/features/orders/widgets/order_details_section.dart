import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Секция «Получатель»: транспорт + контакты получателя + контрагент.
///
/// Для курьера на свободном заказе (`isLocked: true`) телефон получателя
/// маскируется (`words.phoneMasked`) и нет кнопки звонка.
class OrderDetailsSection extends StatelessWidget {
  final OrderDto dto;
  final bool isLocked;
  final bool isShop;

  const OrderDetailsSection({
    super.key,
    required this.dto,
    required this.isLocked,
    required this.isShop,
  });

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

  String _transportLabel(String? type, dynamic words) {
    switch (type) {
      case 'car':
        return words.transportCar;
      case 'truck':
        return words.transportTruck;
      default:
        return words.transportAny;
    }
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;

    final transportType = dto.transportType;
    final phone = dto.clientPhone;
    final counterPhone = isShop ? dto.courierPhone : dto.shopPhone;
    final courierName = dto.courierName;

    return Column(
      children: [
        // ── Transport row ─────────────────────────────────────────────────
        _DetailRow(
          icon: _transportIcon(transportType),
          iconColor: transportType == 'truck' ? c.errorMuted : c.ink,
          label: words.transportRequirement,
          value: _transportLabel(transportType, words),
        ),

        const SizedBox(height: 10),
        Container(height: 0.5, color: c.borderSoft),
        const SizedBox(height: 10),

        // ── Recipient row ─────────────────────────────────────────────────
        _DetailRow(
          icon: Icons.person_outline_rounded,
          iconColor: c.ink,
          label: isLocked ? words.phoneHidden : words.clientPhone,
          value: isLocked ? words.phoneMasked : (phone.isEmpty ? '—' : phone),
          trailing: phone.isNotEmpty && !isLocked
              ? _CallButton(onTap: () => _makeCall(phone))
              : null,
        ),

        // ── Counterparty row ──────────────────────────────────────────────
        if (!isLocked && counterPhone.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(height: 0.5, color: c.borderSoft),
          const SizedBox(height: 10),
          _DetailRow(
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
            trailing: _CallButton(onTap: () => _makeCall(counterPhone)),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
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
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
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
}
