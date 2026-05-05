import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/profile/registration_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/role_provider.dart';

class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const Color surfaceColor = Color(0xFFF5F7FA);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final roleProv = context.watch<RoleProvider>();
    final words = lang.words;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brandGreen.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: brandGreen,
              size: 18,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              // ── Заголовок ──────────────────────────────────────────────
              ShaderMask(
                shaderCallback: (b) => brandGradient.createShader(b),
                child: Text(
                  words.selectRole,
                  style: AppText.extraBold(fontSize: 28, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                words.roleSubtitle,
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF9AA3AF),
                ),
              ),

              const SizedBox(height: 36),

              // ── Карточка: Заказчик ─────────────────────────────────────
              _RoleCard(
                title: words.roleClient,
                desc: words.roleClientDesc,
                roleId: 'shop',
                icon: Icons.shopping_bag_outlined,
                isSelected: roleProv.selectedRole == 'shop',
                onTap: () => roleProv.selectRole('shop'),
              ),

              const SizedBox(height: 14),

              // ── Карточка: Курьер ───────────────────────────────────────
              _RoleCard(
                title: words.roleCourier,
                desc: words.roleCourierDesc,
                roleId: 'courier',
                icon: Icons.electric_bike_outlined,
                isSelected: roleProv.selectedRole == 'courier',
                onTap: () => roleProv.selectRole('courier'),
              ),

              const Spacer(),

              // ── Кнопка подтверждения ───────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RegistrationDetailsScreen(role: roleProv.selectedRole),
                  ),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: brandGradient,
                    color: null,
                    borderRadius: BorderRadius.circular(16),
                    border: null,
                    boxShadow: [
                      BoxShadow(
                        color: brandGreen.withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    words.saveBtn.toUpperCase(),
                    style: AppText.bold(
                      fontSize: 14,
                      color: Colors.white,
                    ).copyWith(letterSpacing: 0.5),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Role card
// ═════════════════════════════════════════════════════════════════════════════

class _RoleCard extends StatelessWidget {
  final String title;
  final String desc;
  final String roleId;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  const _RoleCard({
    required this.title,
    required this.desc,
    required this.roleId,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: brandGreen.withValues(alpha: 0.3), width: 1.5)
              : Border.all(color: const Color(0xFFEEF0F3)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandGreen.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: isSelected ? brandGradient : null,
                color: isSelected ? null : const Color(0xFFEEF0F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : const Color(0xFF9AA3AF),
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bold(
                      fontSize: 16,
                      color: isSelected
                          ? const Color(0xFF0F1117)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: AppText.regular(
                      fontSize: 12,
                      color: const Color(0xFF9AA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Check indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected ? brandGradient : null,
                border: isSelected
                    ? null
                    : Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
