import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/profile/registration_details_screen.dart';
import 'package:flutter/material.dart';

class RolePickerEmbedded extends StatelessWidget {
  final VoidCallback onClose;

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  const RolePickerEmbedded({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle

        // Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                brandGreen.withValues(alpha: 0.12),
                brandRed.withValues(alpha: 0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.swap_horiz_rounded,
            color: brandGreen,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),

        ShaderMask(
          shaderCallback: (b) => brandGradient.createShader(b),
          child: Text(
            'Кто вы?',
            style: AppText.extraBold(fontSize: 22, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Выберите вашу роль чтобы продолжить',
          style: AppText.regular(fontSize: 13, color: const Color(0xFF9AA3AF)),
        ),
        const SizedBox(height: 24),

        // Курьер
        _RoleOption(
          icon: Icons.electric_bike_outlined,
          title: 'Курьер',
          description: 'Принимаю и доставляю заказы',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RegistrationDetailsScreen(role: 'courier'),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Заказчик
        _RoleOption(
          icon: Icons.shopping_bag_outlined,
          title: 'Заказчик',
          description: 'Создаю заказы для доставки',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RegistrationDetailsScreen(role: 'shop'),
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEEF0F3)),
        ),
        child: Row(
          children: [
            // Gradient icon box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: brandGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.semiBold(
                      fontSize: 15,
                      color: const Color(0xFF0F1117),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppText.regular(
                      fontSize: 13,
                      color: const Color(0xFF9AA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }
}
