import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Полноэкранный просмотрщик фото товара с pinch-zoom и swipe-листанием.
///
/// Открывается через push:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => OrderPhotoViewerScreen(
///     pictures: dto.pictures,
///     initialIndex: i,
///     baseUrl: BaseUrl.url,
///   )),
/// );
/// ```
class OrderPhotoViewerScreen extends StatefulWidget {
  final List pictures;
  final int initialIndex;
  final String baseUrl;

  const OrderPhotoViewerScreen({
    super.key,
    required this.pictures,
    required this.initialIndex,
    required this.baseUrl,
  });

  @override
  State<OrderPhotoViewerScreen> createState() => _OrderPhotoViewerScreenState();
}

class _OrderPhotoViewerScreenState extends State<OrderPhotoViewerScreen> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.pictures.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: total > 1
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_current + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: total,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              // Defensive: pictures может прийти как `[int, int]` если
              // на главном запросе сработал fallback `fields=*` (см.
              // OrderService.getOrders). В этом случае file ID недоступен —
              // показываем пустоту вместо краша.
              final raw = widget.pictures[i];
              final String? fileId = raw is Map
                  ? raw['directus_files_id'] as String?
                  : null;
              if (fileId == null) return const SizedBox.shrink();
              final url =
                  '${widget.baseUrl}/assets/$fileId?width=1200&quality=95';
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: 'photo_$fileId',
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: AppColors.of(context).ink,
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (total > 1)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final isActive = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
