import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/pressable_scale.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RoleSelectionCard extends StatelessWidget {
  final VoidCallback onTap;
  const RoleSelectionCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.amberTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.amber.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.ink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    words.profileRolePickTitle,
                    style: AppText.semiBold(fontSize: 13, color: c.ink),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    words.profileRolePickSubtitle,
                    style: AppText.regular(fontSize: 11, color: c.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: c.emeraldTint,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
