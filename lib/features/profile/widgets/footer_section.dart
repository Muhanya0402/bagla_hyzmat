import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FooterSection extends StatelessWidget {
  final String companyName;
  final String appVersion;
  const FooterSection({
    super.key,
    required this.companyName,
    required this.appVersion,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
    final year = DateTime.now().year;

    return Column(
      children: [
        Text(
          companyName.toUpperCase(),
          style: AppText.semiBold(fontSize: 11, color: c.inkMuted)
              .copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 5),
        Text(
          words.profileFooterCopyright.replaceAll('{y}', '$year'),
          style: AppText.regular(fontSize: 11, color: c.inkSoft),
        ),
        if (appVersion.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${words.profileFooterVersion} $appVersion',
            style: AppText.regular(fontSize: 10, color: c.border),
          ),
        ],
      ],
    );
  }
}
