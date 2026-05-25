import 'package:flutter/material.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/features/levels/level_provider.dart';

class HomeLevelBar extends StatelessWidget {
  final LevelProvider provider;
  const HomeLevelBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 currentXp: ${provider.currentXp}');
    debugPrint(
      '🔍 currentLevel.xpRequired: ${provider.currentLevel?.xpRequired}',
    );
    debugPrint('🔍 nextLevel.xpRequired: ${provider.nextLevel?.xpRequired}');
    debugPrint('🔍 progressInLevel: ${provider.progressInLevel}');
    final int level = provider.currentLevel?.levelNumber ?? 1;
    final double progress = provider.progressInLevel;

    // XP внутри текущего уровня
    final int xpEarned =
        provider.currentXp - (provider.currentLevel?.xpRequired ?? 0);
    // Сколько нужно для следующего уровня
    final int xpRange = provider.nextLevel != null
        ? (provider.nextLevel!.xpRequired -
              (provider.currentLevel?.xpRequired ?? 0))
        : 0;

    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            width: MediaQuery.of(context).size.width * 0.42 * progress,
            height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [HomeColors.green, Color(0xFF2BBE63)],
              ),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: HomeColors.green.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$level',
                    style: AppText.extraBold(
                      fontSize: 9,
                      color: HomeColors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Center(
                    child: Text(
                      '$xpEarned/$xpRange XP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.semiBold(
                        fontSize: 9,
                        color: progress > 0.55
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: progress > 0.88
                        ? Colors.white.withValues(alpha: 0.16)
                        : HomeColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 10,
                        color: progress > 0.88
                            ? Colors.white
                            : HomeColors.green,
                      ),
                      Text(
                        '${level + 1}',
                        style: AppText.extraBold(
                          fontSize: 8,
                          color: progress > 0.88
                              ? Colors.white
                              : HomeColors.green,
                        ),
                      ),
                    ],
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

class HomeProgressTrack extends StatelessWidget {
  final double progress;
  const HomeProgressTrack({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double filledWidth = (constraints.maxWidth * progress).clamp(
          0.0,
          constraints.maxWidth,
        );
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: filledWidth,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [HomeColors.green, Color(0xFF34D46A)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: HomeColors.green.withValues(alpha: 0.35),
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
