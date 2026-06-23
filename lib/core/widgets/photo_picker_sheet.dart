import 'dart:io';
import 'dart:typed_data';

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

/// Единый «2-в-1» пикер фото в дизайне приложения: большая плитка «Камера»
/// + инлайн-сетка последних фото из галереи. Возвращает выбранный [File]
/// (снятый камерой или выбранный из галереи) либо `null`, если отменили.
///
/// Используется везде, где прикрепляются фото (регистрация, заказы и т.д.),
/// вместо системного выбора источника.
class PhotoPickerSheet {
  PhotoPickerSheet._();

  static Future<File?> show(BuildContext context) {
    return showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PhotoPickerBody(),
    );
  }
}

class _PhotoPickerBody extends StatefulWidget {
  const _PhotoPickerBody();

  @override
  State<_PhotoPickerBody> createState() => _PhotoPickerBodyState();
}

class _PhotoPickerBodyState extends State<_PhotoPickerBody> {
  final ImagePicker _picker = ImagePicker();

  List<AssetEntity> _assets = const [];
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        if (mounted) {
          setState(() {
            _denied = true;
            _loading = false;
          });
        }
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (paths.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final recent = await paths.first.getAssetListPaged(page: 0, size: 80);
      if (!mounted) return;
      setState(() {
        _assets = recent;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shootCamera() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera);
      if (x != null && mounted) Navigator.pop(context, File(x.path));
    } catch (_) {
      // нет камеры / отмена — ничего не делаем
    }
  }

  Future<void> _chooseAsset(AssetEntity asset) async {
    final f = await asset.file;
    if (f != null && mounted) Navigator.pop(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.read<LanguageProvider>().words;
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.88,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SheetHandle(topPadding: 8),
          // ── Header: close + title ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                _IconBtn(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                  c: c,
                ),
                Expanded(
                  child: Text(
                    words.photoPickerTitle,
                    textAlign: TextAlign.center,
                    style: AppText.serif(fontSize: 18, color: c.ink),
                  ),
                ),
                const SizedBox(width: 40), // балансируем close слева
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: c.border),
          Expanded(child: _buildContent(c, words)),
        ],
      ),
    );
  }

  Widget _buildContent(AppColors c, dynamic words) {
    return CustomScrollView(
      slivers: [
        // ── Камера ───────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _CameraTile(onTap: _shootCamera, label: words.photoPickerCamera, c: c),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              words.photoPickerGallery,
              style: AppText.semiBold(fontSize: 14, color: c.ink),
            ),
          ),
        ),
        // ── Состояния галереи ────────────────────────────────────────────────
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_denied)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Message(
              text: words.photoPickerNoAccess,
              actionLabel: words.photoPickerOpenSettings,
              onAction: () => PhotoManager.openSetting(),
              c: c,
            ),
          )
        else if (_assets.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Message(text: words.photoPickerEmpty, c: c),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _Thumb(
                  asset: _assets[i],
                  onTap: () => _chooseAsset(_assets[i]),
                  c: c,
                ),
                childCount: _assets.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Плитка камеры ─────────────────────────────────────────────────────────────
class _CameraTile extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final AppColors c;
  const _CameraTile({required this.onTap, required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                child: Icon(Icons.photo_camera_rounded, color: c.ink, size: 26),
              ),
              const SizedBox(height: 10),
              Text(label, style: AppText.semiBold(fontSize: 14, color: c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Превью одного фото ────────────────────────────────────────────────────────
class _Thumb extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback onTap;
  final AppColors c;
  const _Thumb({required this.asset, required this.onTap, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize.square(300)),
          builder: (_, snap) {
            final data = snap.data;
            if (data == null) {
              return Container(color: c.borderSoft);
            }
            return Image.memory(
              data,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }
}

// ── Вспомогательные ───────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final AppColors c;
  const _IconBtn({required this.icon, required this.onTap, required this.c});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: c.inkMuted, size: 22),
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
