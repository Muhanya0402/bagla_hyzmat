import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

/// Компактная иконка для TopBar авторизационных экранов.
/// Стиль совпадает с AuthBackButton — 38×38, скруглённый контейнер с бордером.
class ThemeToggleIcon extends StatefulWidget {
  const ThemeToggleIcon({super.key});

  @override
  State<ThemeToggleIcon> createState() => _ThemeToggleIconState();
}

class _ThemeToggleIconState extends State<ThemeToggleIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final c = AppColors.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:  (_) => setState(() => _pressed = true),
      onTapUp:    (_) {
        setState(() => _pressed = false);
        context.read<ThemeProvider>().toggle();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutBack,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border, width: 1.5),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween(begin: 0.75, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              key: ValueKey(isDark),
              size: 16,
              color: c.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Switch-строка для экрана профиля.
/// Самостоятельный виджет — подписывается на ThemeProvider сам.
class ThemeToggleTile extends StatelessWidget {
  const ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final c = AppColors.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.read<ThemeProvider>().toggle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.borderSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 17,
                color: c.inkMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isDark ? 'Тёмная тема' : 'Светлая тема',
                style: AppText.medium(fontSize: 14, color: c.ink),
              ),
            ),
            Switch.adaptive(
              value: isDark,
              activeThumbColor: Colors.white,
              activeTrackColor: c.accent,
              inactiveThumbColor: c.inkSoft,
              inactiveTrackColor: c.borderSoft,
              onChanged: (v) => context.read<ThemeProvider>().setDark(v),
            ),
          ],
        ),
      ),
    );
  }
}
