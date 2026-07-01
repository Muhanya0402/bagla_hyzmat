import 'dart:io';
import 'dart:typed_data';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

/// Полноэкранный «2-в-1» пикер фото в стиле Wildberries: живой видоискатель
/// камеры (затвор + переключение фронт/тыл) сверху и выдвижной лист галереи
/// снизу с мультивыбором. Возвращает список выбранных [File] (снимок камеры —
/// один файл; галерея — до [maxAssets] файлов). Пустой список = отмена.
///
/// Используется везде, где прикрепляются фото (регистрация, заказы и т.д.).
class PhotoPickerSheet {
  PhotoPickerSheet._();

  static Future<List<File>> show(
    BuildContext context, {
    int maxAssets = 1,
  }) async {
    final result = await Navigator.of(context, rootNavigator: true).push<List<File>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PhotoPickerScreen(maxAssets: maxAssets),
      ),
    );
    return result ?? const [];
  }
}

class _PhotoPickerScreen extends StatefulWidget {
  final int maxAssets;
  const _PhotoPickerScreen({required this.maxAssets});

  @override
  State<_PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends State<_PhotoPickerScreen>
    with WidgetsBindingObserver {
  // ── Камера ────────────────────────────────────────────────────────────────
  CameraController? _cam;
  List<CameraDescription> _cameras = const [];
  int _camIndex = 0;
  bool _camReady = false;
  bool _camFailed = false;
  bool _capturing = false;

  // Зум и вспышка.
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  static const List<double> _zoomStops = [1, 2, 5];
  bool _torch = false;

  // ── Галерея ───────────────────────────────────────────────────────────────
  List<AssetEntity> _assets = const [];
  List<AssetPathEntity> _albums = const [];
  AssetPathEntity? _album;
  bool _galLoading = true;
  bool _galDenied = false;
  /// Ограниченный доступ (Android 14+/iOS 14+): пользователь дал доступ только
  /// к выбранным фото. Тогда показываем баннер «Разрешить ещё» для расширения
  /// набора через системный диалог (`presentLimited`).
  bool _galLimited = false;
  final List<AssetEntity> _selected = [];

  // Текущая высота выдвижного листа (для скрытия кнопок камеры при раскрытии).
  double _sheetExtent = 0.42;

  bool get _multi => widget.maxAssets > 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  /// Последовательно запрашиваем разрешения: сначала камеру, затем галерею.
  /// Параллельный запрос конфликтовал — Android показывает диалоги по очереди,
  /// и init камеры падал, пока висел диалог галереи (камера «недоступна» до
  /// перезахода). Теперь запрашиваем по одному.
  Future<void> _bootstrap() async {
    await _initCamera();
    if (!mounted) return;
    await _loadGallery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setCamera(_camIndex);
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _camFailed = true);
        return;
      }
      _cameras = cams;
      // Предпочитаем тыловую камеру.
      final backIdx = cams.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      final idx = backIdx >= 0 ? backIdx : 0;
      final ok = await _setCamera(idx);
      // Первый initialize() мог упасть, пока пользователь ещё отвечал на
      // диалог CAMERA-разрешения — повторяем один раз после его выдачи.
      if (!ok && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) await _setCamera(idx);
      }
    } catch (_) {
      if (mounted) setState(() => _camFailed = true);
    }
  }

  Future<bool> _setCamera(int index) async {
    if (index < 0 || index >= _cameras.length) return false;
    // ⚠️ Сначала ОСВОБОЖДАЕМ текущую камеру, потом инициализируем новую.
    // На Android две открытые камеры одновременно недопустимы — вторая
    // initialize() падает с «camera in use», из-за чего переключение
    // фронт/тыл не работало.
    final old = _cam;
    if (old != null) {
      _cam = null;
      if (mounted) setState(() => _camReady = false);
      try {
        await old.dispose();
      } catch (_) {}
    }
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      double minZ = 1, maxZ = 1;
      try {
        minZ = await controller.getMinZoomLevel();
        maxZ = await controller.getMaxZoomLevel();
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return false;
      }
      setState(() {
        _cam = controller;
        _camIndex = index;
        _camReady = true;
        _camFailed = false;
        _minZoom = minZ;
        _maxZoom = maxZ;
        _zoom = 1;
        _torch = false;
      });
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _camReady = false;
          _camFailed = true;
        });
      }
      return false;
    }
  }

  Future<void> _cycleZoom() async {
    final cam = _cam;
    if (cam == null || !_camReady) return;
    // Доступные «ступени» зума в пределах поддерживаемого максимума.
    final stops =
        _zoomStops.where((z) => z >= _minZoom && z <= _maxZoom + 0.01).toList();
    if (stops.length < 2) return; // зум не поддерживается — нечего листать
    final idx = stops.indexOf(_zoom);
    final next = stops[(idx + 1) % stops.length];
    try {
      await cam.setZoomLevel(next);
      if (mounted) setState(() => _zoom = next);
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    final cam = _cam;
    if (cam == null || !_camReady) return;
    final on = !_torch;
    try {
      await cam.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torch = on);
    } catch (_) {
      // фронтальная камера без вспышки — игнорируем
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || !_camReady) return;
    final cur = _cameras[_camIndex].lensDirection;
    final nextIdx = _cameras.indexWhere((c) => c.lensDirection != cur);
    if (nextIdx >= 0) await _setCamera(nextIdx);
  }

  Future<void> _loadGallery() async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        if (mounted) {
          setState(() {
            _galDenied = true;
            _galLimited = false;
            _galLoading = false;
          });
        }
        return;
      }
      final limited = ps == PermissionState.limited;
      // onlyAll: false — получаем ВСЕ альбомы/папки (Камера, Скриншоты,
      // Загрузки и т.д.), а не только «Recent», чтобы можно было выбирать
      // изображения по папкам.
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: false,
      );
      if (albums.isEmpty) {
        if (mounted) {
          setState(() {
            _galLimited = limited;
            _galLoading = false;
          });
        }
        return;
      }
      _albums = albums;
      if (mounted) setState(() => _galLimited = limited);
      await _selectAlbum(albums.first);
    } catch (_) {
      if (mounted) setState(() => _galLoading = false);
    }
  }

  /// Открывает системный диалог выбора доступных фото (при ограниченном
  /// доступе) и перезагружает галерею под обновлённый набор.
  Future<void> _requestMorePhotos() async {
    try {
      await PhotoManager.presentLimited();
    } catch (_) {
      // на старых Android/iOS presentLimited может быть недоступен — игнор
    }
    if (!mounted) return;
    // Сбрасываем кеш путей/файлов, чтобы новый набор точно подтянулся.
    await PhotoManager.clearFileCache();
    if (!mounted) return;
    setState(() {
      _galLoading = true;
      _albums = const [];
      _album = null;
      _assets = const [];
    });
    await _loadGallery();
  }

  Future<void> _selectAlbum(AssetPathEntity album) async {
    if (mounted) {
      setState(() {
        _album = album;
        _galLoading = true;
      });
    }
    try {
      final assets = await album.getAssetListPaged(page: 0, size: 200);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _galLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _galLoading = false);
    }
  }

  Future<void> _openAlbumPicker() async {
    if (_albums.isEmpty) return;
    final c = AppColors.of(context);
    final words = context.read<LanguageProvider>().words;
    final selected = await showModalBottomSheet<AssetPathEntity>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _albums.length,
            itemBuilder: (_, i) {
              final a = _albums[i];
              final isSel = a.id == _album?.id;
              return ListTile(
                title: Text(
                  a.name.isEmpty ? words.photoPickerGallery : a.name,
                  style: AppText.medium(
                    fontSize: 15,
                    color: isSel ? c.ink : c.inkMuted,
                  ),
                ),
                trailing: isSel ? Icon(Icons.check_rounded, color: c.ink) : null,
                onTap: () => Navigator.pop(ctx, a),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null && selected.id != _album?.id) {
      await _selectAlbum(selected);
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  Future<void> _shoot() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final x = await cam.takePicture();
      if (mounted) Navigator.pop(context, <File>[File(x.path)]);
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _onAssetTap(AssetEntity asset) async {
    if (!_multi) {
      final f = await asset.file;
      if (f != null && mounted) Navigator.pop(context, <File>[f]);
      return;
    }
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else if (_selected.length < widget.maxAssets) {
        _selected.add(asset);
      }
    });
  }

  Future<void> _confirmSelection() async {
    if (_selected.isEmpty) return;
    final files = <File>[];
    for (final a in _selected) {
      final f = await a.file;
      if (f != null) files.add(f);
    }
    if (mounted) Navigator.pop(context, files);
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final words = context.read<LanguageProvider>().words;
    final controlsVisible = _sheetExtent < 0.6;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Видоискатель ───────────────────────────────────────────────────
          Positioned.fill(child: _buildCameraArea(words)),

          // ── Верхняя панель: закрыть + заголовок ─────────────────────────────
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                _RoundIcon(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    words.photoPickerTitle,
                    textAlign: TextAlign.center,
                    style: AppText.semiBold(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 52),
              ],
            ),
          ),

          // ── Кнопки камеры (затвор + переключение) ───────────────────────────
          if (controlsVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).size.height * 0.42 + 24,
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: controlsVisible ? 1 : 0,
                  child: _buildCameraControls(),
                ),
              ),
            ),

          // ── Выдвижной лист галереи ──────────────────────────────────────────
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              if ((n.extent - _sheetExtent).abs() > 0.02) {
                setState(() => _sheetExtent = n.extent);
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.42,
              minChildSize: 0.42,
              maxChildSize: 0.92,
              builder: (ctx, scrollCtrl) => _buildGallery(ctx, scrollCtrl, words),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraArea(dynamic words) {
    if (_camReady && _cam != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cam!.value.previewSize?.height ?? 1,
          height: _cam!.value.previewSize?.width ?? 1,
          child: CameraPreview(_cam!),
        ),
      );
    }
    // Ошибка камеры — текст; иначе (загрузка/переключение) — спиннер.
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: _camFailed
          ? Text(
              words.photoPickerNoCamera,
              style: AppText.regular(fontSize: 14, color: Colors.white54),
            )
          : const CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
    );
  }

  Widget _buildCameraControls() {
    final zoomSupported = _maxZoom > 1.01;
    final zoomLabel =
        _zoom % 1 == 0 ? '${_zoom.toInt()}x' : '${_zoom.toStringAsFixed(1)}x';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Зум.
        SizedBox(
          width: 52,
          child: zoomSupported
              ? GestureDetector(
                  onTap: _cycleZoom,
                  child: Container(
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      zoomLabel,
                      style:
                          AppText.semiBold(fontSize: 13, color: Colors.white),
                    ),
                  ),
                )
              : null,
        ),
        // Затвор.
        GestureDetector(
          onTap: _camReady ? _shoot : null,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: _camReady ? 1 : 0.4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 4),
            ),
            child: _capturing
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                  )
                : null,
          ),
        ),
        // Переключение камеры.
        SizedBox(
          width: 52,
          child: _cameras.length > 1
              ? _RoundIcon(icon: Icons.cameraswitch_rounded, onTap: _flipCamera)
              : null,
        ),
        // Вспышка (фонарик).
        SizedBox(
          width: 52,
          child: _RoundIcon(
            icon: _torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            onTap: _toggleTorch,
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(
    BuildContext ctx,
    ScrollController scrollCtrl,
    dynamic words,
  ) {
    final c = AppColors.of(ctx);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16),
        ],
      ),
      child: Column(
        children: [
          // Грабер.
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                // Кликабельный селектор альбома/папки.
                Flexible(
                  child: InkWell(
                    onTap: _albums.length > 1 ? _openAlbumPicker : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _album?.name.isNotEmpty == true
                                  ? _album!.name
                                  : words.photoPickerGallery,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.semiBold(fontSize: 15, color: c.ink),
                            ),
                          ),
                          if (_albums.length > 1) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                size: 20, color: c.inkMuted),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (_multi && _selected.isNotEmpty)
                  TextButton(
                    onPressed: _confirmSelection,
                    style: TextButton.styleFrom(
                      backgroundColor: c.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      '${words.photoPickerDone} (${_selected.length})',
                      style: AppText.semiBold(fontSize: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          // Баннер ограниченного доступа — показан только при limited-доступе.
          if (_galLimited && !_galLoading) _LimitedBanner(c: c, words: words, onTap: _requestMorePhotos),
          Expanded(child: _buildGalleryBody(scrollCtrl, c, words)),
        ],
      ),
    );
  }

  Widget _buildGalleryBody(ScrollController scrollCtrl, AppColors c, dynamic words) {
    if (_galLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_galDenied) {
      return _Message(
        text: words.photoPickerNoAccess,
        actionLabel: words.photoPickerOpenSettings,
        onAction: () => PhotoManager.openSetting(),
        c: c,
      );
    }
    if (_assets.isEmpty) {
      // При ограниченном доступе пустой набор → предлагаем выбрать фото.
      if (_galLimited) {
        return _Message(
          text: words.photoPickerLimitedEmpty,
          actionLabel: words.photoPickerAllowMore,
          onAction: _requestMorePhotos,
          c: c,
        );
      }
      return _Message(text: words.photoPickerEmpty, c: c);
    }
    return GridView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _assets.length,
      itemBuilder: (_, i) {
        final asset = _assets[i];
        final selIdx = _selected.indexOf(asset);
        return _Thumb(
          asset: asset,
          c: c,
          multi: _multi,
          selectionNumber: selIdx >= 0 ? selIdx + 1 : null,
          onTap: () => _onAssetTap(asset),
        );
      },
    );
  }
}

// ── Превью одного фото ────────────────────────────────────────────────────────
class _Thumb extends StatelessWidget {
  final AssetEntity asset;
  final AppColors c;
  final bool multi;
  final int? selectionNumber;
  final VoidCallback onTap;
  const _Thumb({
    required this.asset,
    required this.c,
    required this.multi,
    required this.selectionNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectionNumber != null;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FutureBuilder<Uint8List?>(
              future: asset.thumbnailDataWithSize(const ThumbnailSize.square(300)),
              builder: (_, snap) {
                final data = snap.data;
                if (data == null) return Container(color: c.borderSoft);
                return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
              },
            ),
          ),
          if (selected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.ink, width: 3),
              ),
            ),
          if (multi)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.ink : Colors.black.withValues(alpha: 0.25),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Text(
                        '$selectionNumber',
                        style: AppText.semiBold(fontSize: 12, color: Colors.white),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Вспомогательные ───────────────────────────────────────────────────────────
class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

// Баннер ограниченного доступа к фото (Android 14+/iOS 14+).
class _LimitedBanner extends StatelessWidget {
  final AppColors c;
  final dynamic words;
  final VoidCallback onTap;
  const _LimitedBanner({required this.c, required this.words, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: c.amberTint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: c.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    words.photoPickerLimited,
                    style: AppText.regular(fontSize: 12.5, color: c.ink)
                        .copyWith(height: 1.3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  words.photoPickerAllowMore,
                  style: AppText.semiBold(fontSize: 12.5, color: c.amber),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppColors c;
  const _Message({
    required this.text,
    this.actionLabel,
    this.onAction,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppText.regular(fontSize: 14, color: c.inkMuted)
                  .copyWith(height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  backgroundColor: c.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  actionLabel!,
                  style: AppText.semiBold(fontSize: 14, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
