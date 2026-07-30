/// Пакет жетонов из Directus (коллекция `token_package`).
///
/// Цена задаётся НА ПАКЕТ, а не как «кол-во × курс» — именно это даёт скидку
/// за объём: крупный пакет выходит дешевле в пересчёте на один жетон и у
/// курьера появляется смысл покупать больше сразу.
class TokenPackageOption {
  final int tokens;
  final double price;

  /// Метка на карточке: `popular`, `profitable` или пусто.
  final String? badge;

  const TokenPackageOption({
    required this.tokens,
    required this.price,
    this.badge,
  });

  /// Цена одного жетона в этом пакете.
  double get pricePerToken => tokens > 0 ? price / tokens : 0;
}
