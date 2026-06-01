import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Конкретный пресет сжатия — что хотим получить на выходе.
class ImagePreset {
  /// Максимальная сторона (px). Меньшая сторона ужимается пропорционально.
  /// `flutter_image_compress` называет это `minWidth/minHeight`, но семантика
  /// именно «не больше N» — кадр ужимается **под** эти размеры с сохранением
  /// aspect ratio.
  final int maxSide;

  /// JPEG/WebP quality factor 1–100.
  /// Для WebP 70–75 уже выглядит как «лосслесс» на глаз.
  final int quality;

  /// WebP по умолчанию — меньший размер при той же чёткости.
  /// Если хочешь оставить совместимость со старыми системами — `jpeg`.
  final CompressFormat format;

  const ImagePreset({
    required this.maxSide,
    required this.quality,
    this.format = CompressFormat.webp,
  });

  /// Расширение результирующего файла (с точкой).
  String get extension {
    switch (format) {
      case CompressFormat.webp:
        return '.webp';
      case CompressFormat.jpeg:
        return '.jpg';
      case CompressFormat.png:
        return '.png';
      case CompressFormat.heic:
        return '.heic';
    }
  }
}

/// Пресеты для типовых сценариев. Менять числа здесь — централизованно.
abstract final class ImagePresets {
  ImagePresets._();

  // ── Товар в заказе ────────────────────────────────────────────────────
  // Цель: ~150–250 KB. Покупатель видит товар, но 4K не нужны.
  static const orderItem = ImagePreset(maxSide: 1280, quality: 70);

  // ── Главная страница паспорта / прописка / фото-страница паспорта ─────
  // Цель: ~350–500 KB. Текст должен читаться модератору.
  // q80 + 1600 — золотой стандарт для документов на WebP.
  static const passportPage = ImagePreset(maxSide: 1600, quality: 80);

  // ── Селфи / фронталка ─────────────────────────────────────────────────
  // Цель: ~200–300 KB. Лицо на 1280px распознаётся идеально.
  static const face = ImagePreset(maxSide: 1280, quality: 72);
}
