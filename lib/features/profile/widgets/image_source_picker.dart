import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Bottom sheet выбора источника фото: камера или галерея.
/// Возвращает `ImageSource` или `null` если пользователь отменил.
class ImageSourcePicker {
  ImageSourcePicker._();

  static Future<ImageSource?> show(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(),
    );
  }
}

class _Sheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.read<LanguageProvider>().words;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(topPadding: 0),
          const SizedBox(height: 18),
          _Row(
            icon: Icons.camera_alt_outlined,
            label: words.regPickFromCamera,
            onTap: () => Navigator.pop(context, ImageSource.camera),
            c: c,
          ),
          const SizedBox(height: 8),
          _Row(
            icon: Icons.photo_library_outlined,
            label: words.regPickFromGallery,
            onTap: () => Navigator.pop(context, ImageSource.gallery),
            c: c,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: c.borderSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                words.regPickCancel,
                style: AppText.medium(fontSize: 14, color: c.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppColors c;
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: c.ink),
              const SizedBox(width: 14),
              Text(
                label,
                style: AppText.medium(fontSize: 14, color: c.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
