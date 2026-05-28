import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/core/app_text_styles.dart';

/// Anthropic-style Terms of Service screen.
///
/// Editorial typography (serif headings + reading-optimized sans body),
/// inline TOC chips, "In plain English" callouts before each legal section,
/// generous whitespace, no flashy colors.
class PolicyScreen extends StatefulWidget {
  final VoidCallback? onAccepted;
  const PolicyScreen({super.key, this.onAccepted});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  static const _contentMaxWidth = 720.0;
  Color _calloutBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2A2520) : const Color(0xFFF6F0E8);
  }

  final _scrollCtrl = ScrollController();
  bool _hasScrolledToBottom = false;

  // GlobalKey'и для якорей секций — нужны для ensureVisible из TOC.
  late final List<GlobalKey> _sectionKeys = List.generate(
    6,
    (_) => GlobalKey(),
  );

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_hasScrolledToBottom &&
        _scrollCtrl.offset >= _scrollCtrl.position.maxScrollExtent - 48) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _accept() {
    widget.onAccepted?.call();
    Navigator.pop(context);
  }

  Future<void> _scrollToSection(int i) async {
    final ctx = _sectionKeys[i].currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.02, // секция почти у верха
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;

    final sections = _buildSections(words);

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.of(context).bg,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.of(context).borderSoft,
                    width: 1,
                  ),
                ),
              ),

              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 10),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: Row(
                      children: [
                        const AuthBackButton(),
                        const Spacer(),
                        AuthLangSwitcher(
                          isRu: lang.isRu,
                          onToggle: lang.toggleLanguage,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Last updated meta
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.of(context).surface,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: AppColors.of(context).border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              words.policyLastUpdated,
                              style: AppText.medium(
                                fontSize: 11.5,
                                color: AppColors.of(context).inkMuted,
                              ).copyWith(letterSpacing: 0.2),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Hero serif title
                          Text(
                            words.policyTitle,
                            style: AppText.serif(
                              fontSize: 40,
                              letterSpacing: -0.8,
                              height: 1.05,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Lede / intro — editorial serif standfirst
                          Text(
                            words.policyIntro,
                            style: AppText.serif(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              color: AppColors.of(context).inkMuted,
                              height: 1.55,
                              letterSpacing: 0,
                            ),
                          ),

                          const SizedBox(height: 36),

                          // TOC — горизонтальный sidebar-аналог для мобильного
                          _TableOfContents(
                            title: words.policyTocTitle,
                            items: sections
                                .map((s) => s.title)
                                .toList(growable: false),
                            onTap: _scrollToSection,
                          ),

                          const SizedBox(height: 28),

                          // ── Hairline divider ──────────────────────────
                          Container(
                            height: 1,
                            color: AppColors.of(context).border,
                          ),

                          const SizedBox(height: 28),

                          // Sections
                          for (var i = 0; i < sections.length; i++) ...[
                            _PolicySection(
                              key: _sectionKeys[i],
                              index: i + 1,
                              section: sections[i],
                              calloutBg: _calloutBg(context),
                              calloutLabel: words.policyInPlainEnglish,
                            ),
                            if (i < sections.length - 1) ...[
                              const SizedBox(height: 28),
                              Container(
                                height: 1,
                                color: AppColors.of(context).borderSoft,
                              ),
                              const SizedBox(height: 28),
                            ],
                          ],

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Accept footer ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.of(context).bg,
                border: Border(
                  top: BorderSide(
                    color: AppColors.of(context).borderSoft,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                  child: Column(
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: _hasScrolledToBottom ? 0 : 1,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            words.policyScrollHint,
                            style: AppText.regular(
                              fontSize: 12,
                              color: AppColors.of(context).inkSoft,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      AuthGradientButton(
                        label: words.policyAcceptBtn,
                        enabled: _hasScrolledToBottom,
                        onPressed: _accept,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_SectionData> _buildSections(AppLocalizations w) => [
    _SectionData(w.policySec1Title, w.policySec1Plain, w.policySec1Body),
    _SectionData(w.policySec2Title, w.policySec2Plain, w.policySec2Body),
    _SectionData(w.policySec3Title, w.policySec3Plain, w.policySec3Body),
    _SectionData(w.policySec4Title, w.policySec4Plain, w.policySec4Body),
    _SectionData(w.policySec5Title, w.policySec5Plain, w.policySec5Body),
    _SectionData(w.policySec6Title, w.policySec6Plain, w.policySec6Body),
  ];
}

// ═════════════════════════════════════════════════════════════════════════════
// Data
// ═════════════════════════════════════════════════════════════════════════════

class _SectionData {
  final String title;
  final String plain;
  final String body;
  const _SectionData(this.title, this.plain, this.body);
}

// ═════════════════════════════════════════════════════════════════════════════
// Table of contents — chips rail (мобильный sidebar)
// ═════════════════════════════════════════════════════════════════════════════

class _TableOfContents extends StatelessWidget {
  final String title;
  final List<String> items;
  final ValueChanged<int> onTap;

  const _TableOfContents({
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppText.semiBold(
            fontSize: 11,
            color: AppColors.of(context).inkSoft,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < items.length; i++)
              _TocChip(index: i + 1, label: items[i], onTap: () => onTap(i)),
          ],
        ),
      ],
    );
  }
}

class _TocChip extends StatelessWidget {
  final int index;
  final String label;
  final VoidCallback onTap;

  const _TocChip({
    required this.index,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.of(context).border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$index',
              style: AppText.semiBold(
                fontSize: 11.5,
                color: AppColors.of(context).inkSoft,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppText.medium(
                fontSize: 12.5,
                color: AppColors.of(context).ink,
              ).copyWith(letterSpacing: 0.1),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Section block — number, serif title, plain-English callout, body
// ═════════════════════════════════════════════════════════════════════════════

class _PolicySection extends StatelessWidget {
  final int index;
  final _SectionData section;
  final Color calloutBg;
  final String calloutLabel;

  const _PolicySection({
    super.key,
    required this.index,
    required this.section,
    required this.calloutBg,
    required this.calloutLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number label (small caps)
        Text(
          'S· ${index.toString().padLeft(2, '0')}',
          style:
              AppText.semiBold(
                fontSize: 11,
                color: AppColors.of(context).inkSoft,
              ).copyWith(
                letterSpacing: 1.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 10),

        // Serif title
        Text(
          section.title,
          style: AppText.serif(fontSize: 24, letterSpacing: -0.3, height: 1.2),
        ),

        const SizedBox(height: 18),

        // Plain-English callout
        _PlainEnglishCallout(
          label: calloutLabel,
          text: section.plain,
          bg: calloutBg,
        ),

        const SizedBox(height: 18),

        // Body
        Text(
          section.body,
          style: AppText.regular(
            fontSize: 15,
            color: AppColors.of(context).ink,
          ).copyWith(height: 1.7, letterSpacing: 0.1),
        ),
      ],
    );
  }
}

class _PlainEnglishCallout extends StatelessWidget {
  final String label;
  final String text;
  final Color bg;

  const _PlainEnglishCallout({
    required this.label,
    required this.text,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.of(context).accent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.of(context).ink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppText.semiBold(
                  fontSize: 11.5,
                  color: AppColors.of(context).inklabel,
                ).copyWith(letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            // Serif pull-quote — короткое объяснение читается как «врезка»
            style: AppText.serif(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.of(context).ink,
              height: 1.55,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
