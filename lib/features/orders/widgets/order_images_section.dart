import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/orders/widgets/order_photo_viewer_screen.dart';
import 'package:flutter/material.dart';

/// Горизонтальная лента thumb'нейлов фото товара.
///
/// Тап по любому thumb'у открывает full-screen `OrderPhotoViewerScreen`
/// через push с прозрачным барьером.
class OrderImagesSection extends StatelessWidget {
  final List pictures;
  final String baseUrl;

  const OrderImagesSection({
    super.key,
    required this.pictures,
    required this.baseUrl,
  });

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => OrderPhotoViewerScreen(
          pictures: pictures,
          initialIndex: initialIndex,
          baseUrl: baseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pictures.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          // Resilient к двум форматам ответа Directus:
          //   - explicit fields `pictures.directus_files_id` → `[{directus_files_id: 'uuid'}]`
          //   - fields `*` (fallback при 403) → `[145, 146]` (just junction ID ints)
          // Если получили int — нет file ID, скипаем (а не падаем).
          final raw = pictures[i];
          final String? fileId =
              raw is Map ? raw['directus_files_id'] as String? : null;
          if (fileId == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => _openViewer(ctx, i),
            child: Hero(
              tag: 'photo_$fileId',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  '$baseUrl/assets/$fileId?width=250&quality=80',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Builder(
                    builder: (innerCtx) {
                      final c = AppColors.of(innerCtx);
                      return Container(
                        width: 100,
                        color: c.borderSoft,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: c.inkSoft,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
