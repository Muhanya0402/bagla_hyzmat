import 'package:flutter/material.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/levels/level_provider.dart';

class HomeLevelBar extends StatelessWidget {
  final LevelProvider provider;
  const HomeLevelBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final int level = provider.currentLevel?.levelNumber ?? 1;
    final double progress = provider.progressInLevel.clamp(0.0, 1.0);

    final int currentXp = provider.currentXp;
    final int? nextLevelXp = provider.nextLevel?.xpRequired;

    return Row(
      children: [
        // ── Level badge — outside the track ────────────────────────────
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: c.amber, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$level',
            style: AppText.extraBold(fontSize: 9, color: c.inklabel),
          ),
        ),

        const SizedBox(width: 6),

        // ── Progress track ──────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (_, constraints) {
              final double w = constraints.maxWidth;
              // Always show at least a 22 px pill so the bar is never empty.
              final double fill = progress > 0
                  ? (w * progress).clamp(22.0, w)
                  : 0.0;
              // White on fill (amber bg), ink on unfilled (amberTint bg).
              // Never use c.amber for text — low contrast on amberTint.
              final bool onFill = fill > w * 0.55;

              return Container(
                height: 30,
                decoration: BoxDecoration(
                  color: c.amberTint,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: c.amber.withValues(alpha: 0.18)),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      width: fill,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.amber, c.amber.withValues(alpha: 0.72)],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: c.amber.withValues(alpha: 0.22),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    // Labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              nextLevelXp != null
                                  ? '$currentXp / $nextLevelXp XP'
                                  : '$currentXp XP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.semiBold(
                                fontSize: 9,
                                color: onFill ? c.inklabel : c.inklabel,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 10,
                                color: onFill ? Colors.white : c.ink,
                              ),
                              Text(
                                '${level + 1}',
                                style: AppText.extraBold(
                                  fontSize: 8,
                                  color: onFill ? Colors.white : c.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeProgressTrack extends StatelessWidget {
  final double progress;
  const HomeProgressTrack({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(
      builder: (_, constraints) {
        final double filled = (constraints.maxWidth * progress).clamp(
          0.0,
          constraints.maxWidth,
        );
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: c.amberTint,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: filled,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.amber, c.amber.withValues(alpha: 0.75)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: c.amber.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
