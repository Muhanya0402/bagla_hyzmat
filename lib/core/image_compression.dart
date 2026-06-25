import 'dart:io';

import 'package:bagla/core/image_picker_presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Тонкий wrapper над `flutter_image_compress` под наши пресеты.
///
/// **Что делает:**
///   - Ресайз до `preset.maxSide` (нативно: libjpeg-turbo / Image I/O)
///   - Перекодировка в WebP (или JPEG) с заданным quality
///   - **Удаляет EXIF** (приватность: GPS-координаты, модель телефона)
///   - Пишет результат во временный файл рядом с исходным
///
/// **Что НЕ делает:**
///   - Не загружает картинку в Dart-память — всё через native path API
///   - Не блокирует UI-поток — нативные вызовы async
///   - Не падает: на любой ошибке возвращает исходный файл (fallback)
abstract final class ImageCompression {
  ImageCompression._();

  /// Сжать `source` согласно `preset` и вернуть путь нового файла.
  /// Если сжатие провалилось — возвращает исходный `source` без изменений.
  static Future<File> compress(File source, ImagePreset preset) async {
    try {
      // ⚠️ Пишем результат в системный temp-каталог приложения, НЕ рядом с
      // исходником. Для фото из галереи `photo_manager`/`asset.file` отдаёт
      // оригинал в общем хранилище (DCIM/Pictures) — и `cmp_*.webp` рядом с
      // ним попадал в саму галерею как дубликат. `Directory.systemTemp` —
      // приватный кэш приложения (Android: .../cache, iOS: sandbox tmp),
      // который не индексируется медиатекой. path_provider не нужен.
      final ts = DateTime.now().microsecondsSinceEpoch;
      final targetPath =
          '${Directory.systemTemp.path}/cmp_$ts${preset.extension}';

      final result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        targetPath,
        minWidth: preset.maxSide,
        minHeight: preset.maxSide,
        quality: preset.quality,
        format: preset.format,
        // EXIF выкидывается по умолчанию — приватность бесплатно.
      );

      if (result == null) {
        if (kDebugMode) {
          debugPrint('⚠️ ImageCompression: result null, returning source');
        }
        return source;
      }

      if (kDebugMode) {
        final srcKb = source.lengthSync() ~/ 1024;
        final dstKb = File(result.path).lengthSync() ~/ 1024;
        debugPrint('🖼 ImageCompression: $srcKb KB → $dstKb KB '
            '(${preset.maxSide}px q${preset.quality} ${preset.format.name})');
      }

      return File(result.path);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ ImageCompression error: $e');
      return source;
    }
  }
}
