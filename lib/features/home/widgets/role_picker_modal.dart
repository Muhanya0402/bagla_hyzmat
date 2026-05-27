import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/profile/registration_details_screen.dart';
import 'package:flutter/material.dart';

/// Bottom-sheet content shown when a client/observer tries to open
/// an order or tap "take order" without having a real role yet.
class RolePickerEmbedded extends StatelessWidget {
  final VoidCallback onClose;

  const RolePickerEmbedded({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AuthColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AuthColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Icon ────────────────────────────────────────────────────
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AuthColors.emeraldTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: AuthColors.emerald,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Кто вы?',
              style: AppText.serif(fontSize: 22, letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            Text(
              'Выберите роль, чтобы продолжить',
              style: AppText.regular(fontSize: 13, color: AuthColors.inkMuted),
            ),
            const SizedBox(height: 20),

            // ── Курьер ──────────────────────────────────────────────────
            _RoleOption(
              icon: Icons.electric_bike_outlined,
              title: 'Курьер',
              description: 'Принимаю и доставляю заказы',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const RegistrationDetailsScreen(role: 'courier'),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Заказчик ────────────────────────────────────────────────
            _RoleOption(
              icon: Icons.shopping_bag_outlined,
              title: 'Заказчик',
              description: 'Создаю заказы для доставки',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const RegistrationDetailsScreen(role: 'shop'),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Single role option tile ───────────────────────────────────────────────────

class _RoleOption extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_RoleOption> createState() => _RoleOptionState();
}

class _RoleOptionState extends State<_RoleOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AuthColors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: AuthColors.ink.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AuthColors.emeraldTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: AuthColors.emerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppText.semiBold(
                        fontSize: 14,
                        color: AuthColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: AppText.regular(
                        fontSize: 12,
                        color: AuthColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AuthColors.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
