import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/phone_screen.dart'; // LangToggle
import 'package:bagla/features/levels/level_card_widget.dart';
import 'package:bagla/features/profile/lang_toggle.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/features/home/widgets/wallet_info_modal.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const Color surfaceColor = Color(0xFFF5F7FA);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();
    final words = lang.words;

    final String fullName = (auth.name.isEmpty && auth.surname.isEmpty)
        ? 'Пользователь'
        : '${auth.name} ${auth.surname}'.trim();

    final bool isCourier = auth.role == 'courier';
    final bool isShop = auth.role == 'shop' || auth.role == 'business';

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
              color: brandGreen.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.close, color: brandGreen, size: 20),
          ),
        ),
        title: Text(
          'Профиль',
          style: AppText.semiBold(fontSize: 17, color: const Color(0xFF0F1117)),
        ),
        actions: [
          // Language toggle
          const LangToggle(),
          const SizedBox(width: 8),
          // Logout
          GestureDetector(
            onTap: () => _showLogoutConfirm(context),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: brandRed.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: brandRed,
                size: 18,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
        ),
      ),
      body: RefreshIndicator(
        color: brandGreen,
        onRefresh: () async => auth.refreshProfile(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    // Avatar circle with gradient
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: AppText.extraBold(
                              fontSize: 20,
                              color: const Color(0xFF0F1117),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            auth.phone.isNotEmpty ? auth.phone : '+993 ...',
                            style: AppText.regular(
                              fontSize: 13,
                              color: const Color(0xFF9AA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCourier
                            ? 'Курьер'
                            : isShop
                            ? 'Заказчик'
                            : 'Наблюдатель',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Level card (couriers only) ───────────────────────────────────
            if (isCourier) const SliverToBoxAdapter(child: LevelCardWidget()),

            // ── Content ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    // ── Balance cards ────────────────────────────────────────
                    Row(
                      children: [
                        if (isShop)
                          _StatCard(
                            label: 'Кошелёк',
                            value:
                                '${auth.walletBalance.toStringAsFixed(2)} TMT',
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: brandGreen,
                            actionIcon: Icons.info_outline_rounded,
                            onAction: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  WalletInfoModal(balance: auth.walletBalance),
                            ).then((_) => auth.refreshProfile()),
                          )
                        else
                          _StatCard(
                            label: 'Мои жетоны',
                            value: auth.balancePoints
                                .toDouble()
                                .toStringAsFixed(2),
                            customIcon: Image.asset(
                              'assets/images/point_icon.png',
                              width: 26,
                              height: 26,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.toll_rounded,
                                color: brandGreen,
                                size: 24,
                              ),
                            ),
                            actionIcon: Icons.add_circle_outline_rounded,
                            iconColor: brandGreen,
                            onAction: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28),
                                ),
                              ),
                              builder: (_) => TopUpModal(
                                userId: auth.userId,
                                role: auth.role,
                                status: auth.status,
                              ),
                            ).then((_) => auth.refreshProfile()),
                          ),
                        const SizedBox(width: 12),
                        // Daily bonus info card
                        if (isCourier)
                          _StatCard(
                            label: 'В день',
                            value: _dailyBonus(auth),
                            icon: Icons.bolt_rounded,
                            iconColor: const Color(0xFFE67E22),
                            actionIcon: Icons.arrow_forward_ios_rounded,
                            onAction: () {},
                          )
                        else
                          _StatCard(
                            label: 'Статус',
                            value: _statusLabel(auth.status),
                            icon: Icons.verified_rounded,
                            iconColor: _statusColor(auth.status),
                            actionIcon: Icons.arrow_forward_ios_rounded,
                            onAction: () {},
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Menu ─────────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEEF0F3)),
                      ),
                      child: Column(
                        children: [
                          _divider(),

                          // Appeals
                          _MenuTile(
                            icon: Icons.inbox_rounded,
                            iconColor: brandGreen,
                            title: 'Мои обращения',
                            onTap: () =>
                                Navigator.pushNamed(context, '/appeals'),
                          ),
                          _divider(),

                          // Support
                          _MenuTile(
                            icon: Icons.support_agent_rounded,
                            iconColor: const Color(0xFFE67E22),
                            title: 'Связаться с поддержкой',
                            subtitle: 'Telegram / WhatsApp',
                            onTap: () => _showSupportModal(context),
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _dailyBonus(AuthProvider auth) {
    // Если уровень хранится в auth — используем его,
    // иначе показываем минимум
    // Формула: level * 0.5 жетонов в день
    // Здесь просто читаем из auth.level если есть, иначе 0
    return '+0.5 жетона'; // будет обновлено когда LevelProvider даст данные
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Активен';
      case 'pending':
        return 'На проверке';
      case 'banned':
        return 'Заблокирован';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return brandGreen;
      case 'pending':
        return const Color(0xFFE67E22);
      default:
        return const Color(0xFF9AA3AF);
    }
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 56, color: Color(0xFFEEF0F3));

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: brandGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Выход', style: AppText.bold(fontSize: 17)),
              const SizedBox(height: 8),
              Text(
                'Вы действительно хотите выйти из аккаунта?',
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF9AA3AF),
                ).copyWith(height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFEEF0F3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Отмена',
                          style: AppText.medium(color: const Color(0xFF9AA3AF)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleLogout(context);
                      },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: brandRed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Выйти',
                          style: AppText.medium(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SupportModal(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Stat card
// ═════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Widget? customIcon;
  final Color? iconColor;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _StatCard({
    required this.label,
    required this.value,
    this.icon,
    this.customIcon,
    this.iconColor,
    required this.actionIcon,
    required this.onAction,
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
                customIcon ?? Icon(icon, color: iconColor, size: 22),
                GestureDetector(
                  onTap: onAction,
                  child: Icon(
                    actionIcon,
                    color: ProfileScreen.brandGreen,
                    size: actionIcon == Icons.arrow_forward_ios_rounded
                        ? 14
                        : 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppText.regular(
                fontSize: 11,
                color: const Color(0xFF9AA3AF),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppText.bold(fontSize: 16, color: const Color(0xFF0F1117)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Menu tile
// ═════════════════════════════════════════════════════════════════════════════

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: AppText.semiBold(fontSize: 14, color: const Color(0xFF0F1117)),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: ProfileScreen.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 6),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Support modal
// ═════════════════════════════════════════════════════════════════════════════

class _SupportModal extends StatelessWidget {
  const _SupportModal();

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _gradient = LinearGradient(colors: [_green, _red]);

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_green.withOpacity(0.12), _red.withOpacity(0.07)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: _green,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),

          ShaderMask(
            shaderCallback: (b) => _gradient.createShader(b),
            child: Text(
              'Поддержка',
              style: AppText.extraBold(fontSize: 20, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Мы готовы помочь вам в любое время',
            style: AppText.regular(
              fontSize: 13,
              color: const Color(0xFF9AA3AF),
            ),
          ),
          const SizedBox(height: 24),

          // Telegram
          _SupportButton(
            icon: Icons.send_rounded,
            iconColor: const Color(0xFF2CA5E0),
            bgColor: const Color(0xFF2CA5E0).withOpacity(0.08),
            title: 'Telegram',
            subtitle: '@bagla_support',
            onTap: () => _launch('https://t.me/bagla_support'),
          ),
          const SizedBox(height: 10),

          // WhatsApp
          _SupportButton(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: const Color(0xFF25D366),
            bgColor: const Color(0xFF25D366).withOpacity(0.08),
            title: 'WhatsApp',
            subtitle: '+993 ...',
            onTap: () => _launch('https://wa.me/99300000000'),
          ),
          const SizedBox(height: 20),

          // Close
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEF0F3)),
              ),
              alignment: Alignment.center,
              child: Text(
                'Закрыть',
                style: AppText.medium(
                  fontSize: 14,
                  color: const Color(0xFF9AA3AF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportButton({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.semiBold(
                      fontSize: 14,
                      color: const Color(0xFF0F1117),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppText.regular(
                      fontSize: 12,
                      color: const Color(0xFF9AA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: iconColor.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Footer
// ═════════════════════════════════════════════════════════════════════════════

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  Future<String> _getVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'Версия ${info.version} (сборка ${info.buildNumber})';
    } catch (_) {
      return 'Версия 1.0.0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Gradient logo text
          ShaderMask(
            shaderCallback: (b) => ProfileScreen.brandGradient.createShader(b),
            child: Text(
              'BAGLA IT SOLUTIONS',
              style: AppText.extraBold(
                fontSize: 12,
                color: Colors.white,
              ).copyWith(letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '© 2024–2026. Все права защищены.',
            style: AppText.regular(
              fontSize: 11,
              color: const Color(0xFF9AA3AF),
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<String>(
            future: _getVersion(),
            builder: (_, snap) => Text(
              snap.data ?? '',
              style: AppText.medium(
                fontSize: 10,
                color: const Color(0xFFD1D5DB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
