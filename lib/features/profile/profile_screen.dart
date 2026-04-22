import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import 'user_type_selection_screen.dart';
import 'top_up_modal.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color brandBlue = Color(0xFF1B3A6B);
  static const Color brandGreen = Color(0xFF27AE60);
  static const Color surfaceColor = Color(0xFFF5F7FA);
  static const Color goldColor = Color(0xFFF1C40F);

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();
    final words = lang.words;

    final String fullName = (auth.name.isEmpty && auth.surname.isEmpty)
        ? "Пользователь"
        : "${auth.name} ${auth.surname}".trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brandBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.close, color: brandBlue, size: 20),
          ),
        ),
        title: Text(
          "Профиль",
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1117),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showLogoutConfirm(context),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: "Выйти",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: brandGreen,
        onRefresh: () async => await auth.refreshProfile(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    Text(
                      fullName,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: brandBlue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      auth.phone.isNotEmpty ? auth.phone : "+993 ...",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF9AA3AF),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        _QuickStatCard(
                          label: "Мои баллы",
                          value: "${auth.balancePoints}",
                          customIcon: Image.asset(
                            'assets/images/point_icon.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.toll_rounded,
                                  color: brandBlue,
                                  size: 22,
                                ),
                          ),
                          buttonIcon: Icons.add_circle,
                          onActionTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              builder: (context) => TopUpModal(
                                userId: auth.userId,
                                role: auth.role,
                                status: auth.status,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        _QuickStatCard(
                          label: "История",
                          value: "Платежи",
                          iconData: Icons.history_rounded,
                          buttonIcon: Icons.arrow_forward_ios_rounded,
                          onActionTap: () {
                            debugPrint("Переход в историю платежей");
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEEF0F3)),
                      ),
                      child: Column(
                        children: [
                          _ProfileTile(
                            title: "Мой рейтинг",
                            trailing: auth.rating.toStringAsFixed(1),
                            icon: Icons.star_rounded,
                            iconColor: goldColor,
                            onTap: () {},
                          ),
                          if (auth.role != 'courier' &&
                              auth.role != 'shop') ...[
                            _buildDivider(),
                            _ProfileTile(
                              title: words.selectRole,
                              subtitle: "Стать курьером или заказчиком",
                              icon: Icons.assignment_ind_rounded,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const UserTypeSelectionScreen(),
                                ),
                              ),
                            ),
                          ],
                          _buildDivider(),
                          _ProfileTile(
                            title: "Язык / Dil",
                            icon: Icons.translate_rounded,
                            trailing: lang.label.toUpperCase(),
                            onTap: () => lang.toggleLanguage(),
                          ),
                          _buildDivider(),
                          _ProfileTile(
                            title: "Обратная связь",
                            icon: Icons.feedback,
                            onTap: () {
                              debugPrint("Переход в обратную связь");
                            },
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    const _FooterSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() =>
      const Divider(height: 1, indent: 56, color: Color(0xFFEEF0F3));

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Выход",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Вы действительно хотите выйти?",
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Отмена", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleLogout(context);
            },
            child: Text(
              "Выйти",
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  Future<String> _getVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return "Версия ${packageInfo.version} (сборка ${packageInfo.buildNumber})";
    } catch (_) {
      return "Версия 1.0.0";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(
            "BAGLA IT SOLUTIONS",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFD1D5DB),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "© 2024-2026. Все права защищены.",
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF9AA3AF),
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<String>(
            future: _getVersion(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? "",
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFD1D5DB),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? iconData;
  final Widget? customIcon;
  final IconData buttonIcon;
  final VoidCallback onActionTap;

  const _QuickStatCard({
    required this.label,
    required this.value,
    this.iconData,
    this.customIcon,
    required this.buttonIcon,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ProfileScreen.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEF0F3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                customIcon ??
                    Icon(iconData, color: ProfileScreen.brandBlue, size: 22),
                GestureDetector(
                  onTap: onActionTap,
                  child: Icon(
                    buttonIcon,
                    color: ProfileScreen.brandGreen,
                    size: buttonIcon == Icons.arrow_forward_ios_rounded
                        ? 16
                        : 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF9AA3AF),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ProfileScreen.brandBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final String? trailing;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? ProfileScreen.brandBlue).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor ?? ProfileScreen.brandBlue,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: const Color(0xFF0F1117),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF9AA3AF),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing!,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: ProfileScreen.brandGreen,
                fontSize: 14,
              ),
            ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }
}
