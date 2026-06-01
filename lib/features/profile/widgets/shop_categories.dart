import 'package:flutter/material.dart';

/// Категория магазина (m2o → коллекция `shop_categories` в Directus).
///
/// `id` — primary key из Directus (string slug или int). Уходит в Directus
/// как значение поля `customers.category` через `_selectedCategory!.id`.
/// `labelRu` / `labelTk` — двуязычные подписи, готовые для отображения.
/// `icon` — материал-иконка для chip'а в picker'е, выбирается по slug.
class ShopCategory {
  final dynamic id;
  final IconData icon;
  final String labelRu;
  final String labelTk;
  const ShopCategory({
    required this.id,
    required this.icon,
    required this.labelRu,
    required this.labelTk,
  });

  String label(bool isRu) => isRu ? labelRu : labelTk;
}

/// Маппинг slug → иконка. Используется и для серверных данных,
/// и для локального fallback'а. Если сервер вернёт незнакомый slug —
/// показываем дефолтную `storefront`.
const Map<String, IconData> kShopCategoryIcons = {
  'food': Icons.shopping_basket_outlined,
  'cafe': Icons.restaurant_outlined,
  'pharmacy': Icons.medical_services_outlined,
  'electronics': Icons.devices_other_outlined,
  'clothing': Icons.checkroom_outlined,
  'cosmetics': Icons.brush_outlined,
  'flowers': Icons.local_florist_outlined,
  'household': Icons.cleaning_services_outlined,
  'books': Icons.menu_book_outlined,
  'sport': Icons.sports_basketball_outlined,
  'pets': Icons.pets_outlined,
  'auto': Icons.directions_car_outlined,
  'other': Icons.storefront_outlined,
};

IconData iconForSlug(String slug) =>
    kShopCategoryIcons[slug] ?? Icons.storefront_outlined;

/// Найти локальную категорию по slug. Возвращает null если slug неизвестен —
/// в этом случае UI показывает сырой slug (лучше, чем пустоту).
ShopCategory? localCategoryBySlug(String slug) {
  for (final cat in kLocalShopCategories) {
    if (cat.id == slug) return cat;
  }
  return null;
}

/// Локализованный лейбл по slug. Если slug неизвестен — возвращается сам slug.
String labelForSlug(String slug, bool isRu) {
  final cat = localCategoryBySlug(slug);
  if (cat == null) return slug;
  return cat.label(isRu);
}

/// Локальный fallback. Используется ТОЛЬКО когда нет сети / сервер не отвечает.
/// При живом подключении приложение всегда тянет актуальный список из Directus.
const List<ShopCategory> kLocalShopCategories = [
  ShopCategory(
    id: 'food',
    icon: Icons.shopping_basket_outlined,
    labelRu: 'Продукты',
    labelTk: 'Iýmit',
  ),
  ShopCategory(
    id: 'cafe',
    icon: Icons.restaurant_outlined,
    labelRu: 'Кафе / Ресторан',
    labelTk: 'Kafe / Restoran',
  ),
  ShopCategory(
    id: 'pharmacy',
    icon: Icons.medical_services_outlined,
    labelRu: 'Аптека',
    labelTk: 'Dermanhana',
  ),
  ShopCategory(
    id: 'electronics',
    icon: Icons.devices_other_outlined,
    labelRu: 'Электроника',
    labelTk: 'Elektronika',
  ),
  ShopCategory(
    id: 'clothing',
    icon: Icons.checkroom_outlined,
    labelRu: 'Одежда и обувь',
    labelTk: 'Geýim we aýakgap',
  ),
  ShopCategory(
    id: 'cosmetics',
    icon: Icons.brush_outlined,
    labelRu: 'Косметика',
    labelTk: 'Kosmetika',
  ),
  ShopCategory(
    id: 'flowers',
    icon: Icons.local_florist_outlined,
    labelRu: 'Цветы и подарки',
    labelTk: 'Güller we sowgatlar',
  ),
  ShopCategory(
    id: 'household',
    icon: Icons.cleaning_services_outlined,
    labelRu: 'Хозтовары',
    labelTk: 'Hojalyk haryt',
  ),
  ShopCategory(
    id: 'books',
    icon: Icons.menu_book_outlined,
    labelRu: 'Книги и канцтовары',
    labelTk: 'Kitaplar we kanselýariýa',
  ),
  ShopCategory(
    id: 'sport',
    icon: Icons.sports_basketball_outlined,
    labelRu: 'Спорт',
    labelTk: 'Sport',
  ),
  ShopCategory(
    id: 'pets',
    icon: Icons.pets_outlined,
    labelRu: 'Зоотовары',
    labelTk: 'Haýwan haryt',
  ),
  ShopCategory(
    id: 'auto',
    icon: Icons.directions_car_outlined,
    labelRu: 'Авто',
    labelTk: 'Awtomobil',
  ),
  ShopCategory(
    id: 'other',
    icon: Icons.storefront_outlined,
    labelRu: 'Другое',
    labelTk: 'Başga',
  ),
];
