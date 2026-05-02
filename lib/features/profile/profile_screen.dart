import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/levels/level_card_widget.dart';
import 'package:flutter/material.dart';
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

    // Показываем карточку уровня только курьерам
    final bool isCourier = auth.role == 'courier';

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
          style: AppText.semiBold(fontSize: 17, color: const Color(0xFF0F1117)),
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
            /// ───────── HEADER ─────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: AppText.extraBold(fontSize: 28, color: brandBlue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      auth.phone.isNotEmpty ? auth.phone : "+993 ...",
                      style: AppText.regular(
                        fontSize: 15,
                        color: const Color(0xFF9AA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// ───────── LEVEL CARD (EDGE TO EDGE) ─────────
            if (isCourier) const SliverToBoxAdapter(child: LevelCardWidget()),

            /// ───────── CONTENT ─────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _QuickStatCard(
                          label: "Мои баллы",
                          value: "${auth.balancePoints}",
                          customIcon: Image.asset(
                            'assets/images/point_icon.png',
                            width: 48,
                            height: 48,
                          ),
                          buttonIcon: Icons.add_circle,
                          onActionTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => TopUpModal(
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
                          iconData: Icons.history,
                          buttonIcon: Icons.arrow_forward_ios,
                          onActionTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    /// MENU
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
                            icon: Icons.star,
                            iconColor: goldColor,
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _ProfileTile(
                            title: "Язык",
                            icon: Icons.translate,
                            trailing: lang.label.toUpperCase(),
                            onTap: () => lang.toggleLanguage(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
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
        title: Text("Выход", style: AppText.bold(fontSize: 16)),
        content: Text(
          "Вы действительно хотите выйти?",
          style: AppText.regular(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Отмена",
              style: AppText.regular(fontSize: 14, color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleLogout(context);
            },
            child: Text(
              "Выйти",
              style: AppText.bold(fontSize: 14, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ (без изменений) ──────────────────────────────

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
            style: AppText.extraBold(
              fontSize: 12,
              color: const Color(0xFFD1D5DB),
            ).copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: 6),
          Text(
            "© 2024-2026. Все права защищены.",
            style: AppText.regular(
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
                style: AppText.medium(
                  fontSize: 10,
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
              style: AppText.regular(
                fontSize: 12,
                color: const Color(0xFF9AA3AF),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppText.bold(fontSize: 17, color: ProfileScreen.brandBlue),
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
        style: AppText.semiBold(fontSize: 15, color: const Color(0xFF0F1117)),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppText.regular(
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
              style: AppText.bold(
                fontSize: 14,
                color: ProfileScreen.brandGreen,
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
