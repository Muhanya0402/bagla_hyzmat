import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Секция «Цена»: разбивка стоимости товара + доставка + кэшбэк (если есть),
/// внизу — крупная итоговая строка.
///
/// Что стоит внизу, зависит от роли: магазину — «К получению» (его деньги за
/// товар), курьеру — «Итого» по заказу. У курьера там раньше была «Выплата»,
/// но она повторяла строку «Доставка» тем же числом, поэтому убрана.
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
        // У магазина итог остаётся здесь, над чертой: внизу у него своя
        // строка «К получению», и две крупные суммы подряд спорили бы за
        // внимание. У курьера итог переехал вниз, на место «Выплаты».
        if (isShop) ...[
          const SizedBox(height: 8),
          // Сумма двух строк выше. Стоит здесь, а не под кэшбэком: кэшбэк
          // начисляется жетонами, в деньги не входит, и итог под ним читался
          // бы как «товар + доставка + кэшбэк».
          _PriceRow(
            label: words.orderTotal,
            value: '${total.toStringAsFixed(0)} TMT',
            color: c.ink,
            strong: true,
          ),
        ],
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
        // Курьеру внизу — итог по заказу. Прежняя строка «Выплата» убрана:
        // она повторяла «Доставку» тем же числом, а заработок курьера
        // по-прежнему виден в этой строке.
        //
        // Кэшбэк оказывается выше итога, но черта их разделяет, и он указан
        // в жетонах, а не в манатах — сложить его с суммой не получится.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isShop ? words.toShopReceive : words.orderTotal,
              style: AppText.semiBold(fontSize: 13, color: c.ink),
            ),
            Text(
              isShop
                  ? '${itemPrice.toStringAsFixed(0)} TMT'
                  : '${total.toStringAsFixed(0)} TMT',
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

  /// Выделить строку как итоговую, а не как одно из слагаемых.
  final bool strong;

  const _PriceRow({
    required this.label,
    required this.value,
    required this.color,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: strong
              ? AppText.semiBold(fontSize: 13, color: c.ink)
              : AppText.regular(fontSize: 13, color: c.inkMuted),
        ),
        Text(
          value,
          style: strong
              ? AppText.semiBold(fontSize: 14, color: color)
              : AppText.medium(fontSize: 13, color: color),
        ),
      ],
    );
  }
}
