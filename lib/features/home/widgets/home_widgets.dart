import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/providers/language_provider.dart';

class HomeFilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const HomeFilterButton({
    super.key,
    required this.activeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool has = activeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: has ? HomeColors.green.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: has
                ? HomeColors.green.withValues(alpha: 0.35)
                : HomeColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: has ? HomeColors.green : HomeColors.grey,
            ),
            if (has)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: HomeColors.green,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class RoleSelectionBanner extends StatelessWidget {
  final VoidCallback onTap;
  const RoleSelectionBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F5EE), Color(0xFFFFF0EE)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomeColors.green.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: HomeColors.gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    words.roleSelectionTitle,
                    style: AppText.bold(fontSize: 14, color: HomeColors.dark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    words.roleActionPrompt,
                    style: AppText.regular(
                      fontSize: 12,
                      color: HomeColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: HomeColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: HomeColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final bool isFull = current >= max;
    final Color c = isFull ? HomeColors.red : HomeColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.2)),
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

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GradientText({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (b) => HomeColors.gradient.createShader(b),
    child: Text(text, style: style.copyWith(color: Colors.white)),
  );
}

class HomeEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const HomeEmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HomeColors.border),
            ),
            child: Icon(
              icon,
              size: 32,
              color: HomeColors.green.withValues(alpha: 0.25),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            text,
            style: AppText.medium(fontSize: 14, color: HomeColors.grey),
          ),
        ),
      ],
    );
  }
}

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
