import 'package:bagla/features/auth/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/role_provider.dart';

class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  static const Color brandBlue = Color(0xFF1B3A6B);
  static const Color brandGreen = Color(0xFF27AE60);
  static const Color lightGrey = Color(0xFFF6F6F6);

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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: brandBlue,
            size: 22,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const _BrandingStrip(),
              const SizedBox(height: 16),

              Text(
                words.selectRole,
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: brandBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                words.roleSubtitle,
                style: const TextStyle(fontSize: 16, color: Colors.black45),
              ),

              const SizedBox(height: 40),

              // Карточки ролей
              _RoleCard(
                title: words.roleClient,
                desc: words.roleClientDesc,
                roleId: 'shop',
                icon: Icons.shopping_cart_outlined,
                isSelected: roleProv.selectedRole == 'shop',
                onTap: () => roleProv.selectRole('shop'),
              ),

              const SizedBox(height: 16),

              _RoleCard(
                title: words.roleCourier,
                desc: words.roleCourierDesc,
                roleId: 'courier',
                icon: Icons.delivery_dining_outlined,
                isSelected: roleProv.selectedRole == 'courier',
                onTap: () => roleProv.selectRole('courier'),
              ),

              const Spacer(),

              // Кнопка подтверждения (Dostavista style)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: roleProv.isSaving
                      ? null
                      : () => roleProv.saveRole(context),
                  child: roleProv.isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          words.saveBtn.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔹 ФИРМЕННАЯ ПОЛОСКА
class _BrandingStrip extends StatelessWidget {
  const _BrandingStrip();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 6,
      decoration: BoxDecoration(
        color: UserTypeSelectionScreen.brandGreen,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// 🔹 КАРТОЧКА ВЫБОРА РОЛИ
class _RoleCard extends StatelessWidget {
  final String title;
  final String desc;
  final String roleId;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected
              ? UserTypeSelectionScreen.brandBlue
              : UserTypeSelectionScreen.lightGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? UserTypeSelectionScreen.brandBlue
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? Colors.white
                  : UserTypeSelectionScreen.brandBlue,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : UserTypeSelectionScreen.brandBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white70 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: UserTypeSelectionScreen.brandGreen,
              ),
          ],
        ),
      ),
    );
  }
}
