import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Bottom sheet «Аккаунт заблокирован» — единый паттерн для всех мест,
/// где надо отказать banned-пользователю в доступе (top-up жетонов и пр.).
///
/// Визуально повторяет `_buildStatusBanner` из `home_screen` для консистентности.
///
/// Использование:
/// ```dart
/// if (auth.isBanned) {
///   BannedAccessSheet.show(context);
///   return;
/// }
/// // ...обычный flow
/// ```
class BannedAccessSheet extends StatelessWidget {
  const BannedAccessSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BannedAccessSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.read<LanguageProvider>().words;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── Статус-баннер (тот же, что _buildStatusBanner в home_screen)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: c.errorTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.errorMuted.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.errorMuted.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.block_rounded,
                    color: c.errorMuted,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    words.accountBanned,
                    style: AppText.medium(
                      fontSize: 13,
                      color: c.errorMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions row: outline «Закрыть» + filled «Связаться с поддержкой»
          Row(
            children: [
              // Close — outline
              Expanded(
                child: SizedBox(
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
                      words.notifClose,
                      style: AppText.medium(fontSize: 14, color: c.inkMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Contact support — charcoal primary
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/appeals');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: c.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.headset_mic_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            words.profileSupportContact,
                            style: AppText.semiBold(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
