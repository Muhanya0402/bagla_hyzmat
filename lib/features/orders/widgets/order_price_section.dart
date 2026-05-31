import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Секция «Цена»: разбивка стоимости товара + доставка + кэшбэк (если есть),
/// внизу — итог («К получению магазину» / «К выплате курьеру»).
class OrderPriceSection extends StatelessWidget {
  final bool isShop;
  final double total;
  final double delivery;
  final double cashback;

  const OrderPriceSection({
    super.key,
    required this.isShop,
    required this.total,
    required this.delivery,
    required this.cashback,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
    final double itemPrice = total - delivery;

    return Column(
      children: [
        _PriceRow(
          label: words.itemPrice,
          value: '${itemPrice.toStringAsFixed(0)} TMT',
          color: c.ink,
        ),
        const SizedBox(height: 8),
        _PriceRow(
          label: words.delivery,
          value: '${delivery.toStringAsFixed(0)} TMT',
          color: c.ink,
        ),
        if (!isShop && cashback > 0) ...[
          const SizedBox(height: 8),
          _PriceRow(
            label: words.cashbackPercent,
            value: '+${cashback.toDouble()} ${words.tokens}',
            color: c.amber,
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
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PriceRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.regular(fontSize: 13, color: c.inkMuted)),
        Text(value, style: AppText.medium(fontSize: 13, color: color)),
      ],
    );
  }
}
