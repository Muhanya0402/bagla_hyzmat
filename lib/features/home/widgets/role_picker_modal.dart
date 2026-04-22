import 'package:bagla/features/profile/registration_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RolePickerEmbedded extends StatelessWidget {
  final VoidCallback onClose;

  const RolePickerEmbedded({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Кто вы?",
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1117),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Выберите вашу роль чтобы продолжить",
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF9AA3AF),
          ),
        ),
        const SizedBox(height: 24),
        _RoleOption(
          icon: Icons.directions_bike_rounded,
          title: "Курьер",
          description: "Принимаю и доставляю заказы",
          color: const Color(0xFF27AE60),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RegistrationDetailsScreen(role: 'courier'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RoleOption(
          icon: Icons.storefront_rounded,
          title: "Заказчик",
          description: "Создаю заказы для доставки",
          color: const Color(0xFF1B3A6B),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RegistrationDetailsScreen(role: 'shop'),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F1117),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF9AA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
