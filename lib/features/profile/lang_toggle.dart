import 'package:bagla/core/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LangToggle — animated RU | TK pill, usable from any screen.
// Import: import 'package:bagla/core/widgets/lang_toggle.dart';
// ─────────────────────────────────────────────────────────────────────────────

class LangToggle extends StatelessWidget {
  const LangToggle({super.key});
  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return GestureDetector(
      onTap: lang.toggleLanguage,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(label: 'RU', active: lang.isRu),
            _Chip(label: 'TK', active: !lang.isRu),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  const _Chip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: active ? LangToggle.brandGradient : null,
        borderRadius: BorderRadius.circular(100),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppText.extraBold(
          fontSize: 12,
          color: active ? Colors.white : Colors.black45,
        ),
      ),
    );
  }
}
