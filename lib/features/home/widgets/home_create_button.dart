import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Visual-only sticker FAB.
/// Drag state and positioning live in MainShell.
class HomeCreateFab extends StatelessWidget {
  final String label;
  final bool isDragging;

  const HomeCreateFab({
    super.key,
    required this.label,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedScale(
      scale: isDragging ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: Container(
          width: 162,
          height: 52,
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(13),
            border: Border(
              top: BorderSide(color: c.accent, width: 3),
            ),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(
                  alpha: isDragging ? 0.35 : 0.22,
                ),
                blurRadius: isDragging ? 20 : 14,
                spreadRadius: isDragging ? 1 : 0,
                offset: Offset(0, isDragging ? 8 : 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppText.semiBold(
                  fontSize: 13,
                  color: Colors.white,
                ).copyWith(letterSpacing: 0.1),
              ),
            ],
          ),
        ),
    );
  }
}
