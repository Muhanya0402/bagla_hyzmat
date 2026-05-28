import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';

// ── Filter icon button ────────────────────────────────────────────────────────
class HomeFilterButton extends StatefulWidget {
  final int activeCount;
  final VoidCallback onTap;

  const HomeFilterButton({
    super.key,
    required this.activeCount,
    required this.onTap,
  });

  @override
  State<HomeFilterButton> createState() => _HomeFilterButtonState();
}

class _HomeFilterButtonState extends State<HomeFilterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bool has = widget.activeCount > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: has ? c.emeraldTint : c.bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: has ? c.emerald.withValues(alpha: 0.35) : c.border,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: has ? c.emerald : c.inkSoft,
              ),
              if (has)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: c.emerald,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.activeCount}',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role selection banner ─────────────────────────────────────────────────────
class RoleSelectionBanner extends StatefulWidget {
  final VoidCallback onTap;
  const RoleSelectionBanner({super.key, required this.onTap});

  @override
  State<RoleSelectionBanner> createState() => _RoleSelectionBannerState();
}

class _RoleSelectionBannerState extends State<RoleSelectionBanner> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                  color: c.emerald,
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
                      words.roleSelectionTitle,
                      style: AppText.semiBold(fontSize: 13, color: c.ink),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      words.roleActionPrompt,
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
                  color: c.emerald,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Active orders counter (AppBar chip) ───────────────────────────────────────
class ActiveOrdersCounter extends StatelessWidget {
  final int current;
  final int max;
  const ActiveOrdersCounter({
    super.key,
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final bool isFull = current >= max;
    final Color c = isFull ? palette.errorMuted : palette.emerald;
    final Color bg = isFull ? palette.errorTint : palette.emeraldTint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined, size: 13, color: c),
          const SizedBox(width: 5),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$current',
                  style: AppText.bold(fontSize: 13, color: c),
                ),
                TextSpan(
                  text: '/$max',
                  style: AppText.regular(
                    fontSize: 13,
                    color: c.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Accent-colored text helper (replaces gradient text) ───────────────────────
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GradientText({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: style.copyWith(color: AppColors.of(context).emerald));
}

// ── Empty state ───────────────────────────────────────────────────────────────
class HomeEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const HomeEmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.border),
            ),
            child: Icon(
              icon,
              size: 28,
              color: c.emerald.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            text,
            style: AppText.medium(fontSize: 13, color: c.inkSoft),
          ),
        ),
      ],
    );
  }
}

// ── Level-up overlay (stub resolved by home_screen) ──────────────────────────
class LevelUpOverlay extends StatelessWidget {
  final dynamic provider;
  final VoidCallback onDismiss;
  const LevelUpOverlay({
    super.key,
    required this.provider,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
