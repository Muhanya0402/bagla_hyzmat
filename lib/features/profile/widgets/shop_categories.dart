import 'package:bagla/l10n/app_localizations.dart';

/// Категории магазина. ID — стабильный английский код для отправки на бэк,
/// label — локализованное название для UI.
///
/// На бэке добавь поле `category: string` в коллекцию `users` (или many-to-one
/// к отдельной коллекции `shop_categories`).
class ShopCategory {
  final String id;
  final String Function(AppLocalizations w) label;
  const ShopCategory(this.id, this.label);
}

/// 13 категорий, подходящих для рынка Туркменистана.
List<ShopCategory> shopCategories() => [
      ShopCategory('food', (w) => w.regCatFood),
      ShopCategory('cafe', (w) => w.regCatCafe),
      ShopCategory('pharmacy', (w) => w.regCatPharmacy),
      ShopCategory('electronics', (w) => w.regCatElectronics),
      ShopCategory('clothing', (w) => w.regCatClothing),
      ShopCategory('cosmetics', (w) => w.regCatCosmetics),
      ShopCategory('flowers', (w) => w.regCatFlowers),
      ShopCategory('household', (w) => w.regCatHousehold),
      ShopCategory('books', (w) => w.regCatBooks),
      ShopCategory('sport', (w) => w.regCatSport),
      ShopCategory('pets', (w) => w.regCatPets),
      ShopCategory('auto', (w) => w.regCatAuto),
      ShopCategory('other', (w) => w.regCatOther),
    ];
