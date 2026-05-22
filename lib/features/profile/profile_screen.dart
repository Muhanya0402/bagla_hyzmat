import 'package:bagla/core/app_settings_provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/levels/level_card_widget.dart';
import 'package:bagla/features/profile/lang_toggle.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/language_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand
// ─────────────────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF1A7A3C);
const _kRed = Color(0xFFD32F1E);
const _kGrey = Color(0xFF9AA3AF);
const _kSurface = Color(0xFFF5F7FA);
const _kBorder = Color(0xFFEEF0F3);
const _kGradient = LinearGradient(
  colors: [_kGreen, _kRed],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color brandGreen = _kGreen;
  static const Color brandRed = _kRed;
  static const Color surfaceColor = _kSurface;
  static const LinearGradient brandGradient = _kGradient;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final words = lang.words;

    final String fullName = (auth.name.isEmpty && auth.surname.isEmpty)
        ? words.user
        : '${auth.name} ${auth.surname}'.trim();

    final bool isCourier = auth.role == 'courier';
    final bool isShop = auth.role == 'shop' || auth.role == 'business';
    final bool isClient = auth.role == 'client';
    final bool needsRoleSelection =
        isClient && auth.status.toLowerCase() == 'published';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        color: _kGreen,
        onRefresh: () => Future.wait([
          auth.refreshProfile(),
          context.read<AppSettingsProvider>().load(),
        ]),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header (аватар с badge + имя + роль) ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _ProfileHeader(
                  fullName: fullName,
                  phone: auth.phone,
                  role: auth.role,
                  status: auth.status,
                ),
              ),
            ),

            // ── Level card (только курьер) ─────────────────────────────────
            if (isCourier) const SliverToBoxAdapter(child: LevelCardWidget()),

            // ── Баннер выбора роли ─────────────────────────────────────────
            if (needsRoleSelection)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _RoleSelectionCard(
                    onTap: () =>
                        Navigator.pushNamed(context, '/user_type_selection'),
                  ),
                ),
              ),

            // ── Жетоны (только курьер) ─────────────────────────────────────
            if (isCourier)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _PointsCard(
                    balance: auth.balancePoints.toDouble(),
                    onTopUp: () => _openTopUp(context, auth),
                  ),
                ),
              ),

            // ── Меню + footer ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    _buildMenu(
                      context: context,
                      words: words,
                      auth: auth,
                      isCourier: isCourier,
                      isShop: isShop,
                      supportPhone: settings.supportPhone,
                    ),
                    const SizedBox(height: 10),
                    _FooterSection(
                      companyName: settings.companyName,
                      appVersion: settings.appVersion,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context) => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    automaticallyImplyLeading: false,
    title: Text(
      'Профиль',
      style: AppText.semiBold(fontSize: 17, color: const Color(0xFF0F1117)),
    ),
    actions: [
      const LangToggle(),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () => _showLogoutConfirm(context),
        child: Container(
          margin: const EdgeInsets.only(right: 16),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded, color: _kRed, size: 18),
        ),
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(0.5),
      child: Container(height: 0.5, color: _kBorder),
    ),
  );

  // ── Menu ───────────────────────────────────────────────────────────────────

  Widget _buildMenu({
    required BuildContext context,
    required dynamic words,
    required AuthProvider auth,
    required bool isCourier,
    required bool isShop,
    required String supportPhone,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _MenuTile(
            icon: Icons.inbox_rounded,
            iconColor: _kGreen,
            title: words.feedbacks,
            onTap: () => Navigator.pushNamed(context, '/appeals'),
          ),
          const Divider(height: 1, indent: 56, color: _kBorder),
          if (isShop || (isCourier && auth.status != 'published'))
            _MenuTile(
              icon: Icons.description_rounded,
              iconColor: const Color(0xFF2CA5E0),
              title: 'Условия использования',
              onTap: () => Navigator.pushNamed(context, '/terms'),
            ),
          const Divider(height: 1, indent: 56, color: _kBorder),
          _MenuTile(
            icon: Icons.support_agent_rounded,
            iconColor: const Color(0xFFE67E22),
            title: 'Связаться с поддержкой',
            onTap: () => _showSupportModal(context, supportPhone),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _openTopUp(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          TopUpModal(userId: auth.userId, role: auth.role, status: auth.status),
    ).then((_) => auth.refreshProfile());
  }

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
                  gradient: _kGradient,
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
                  color: _kGrey,
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
                          border: Border.all(color: _kBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Отмена',
                          style: AppText.medium(color: _kGrey),
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
                          color: _kRed,
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

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  void _showSupportModal(BuildContext context, String phone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupportModal(phone: phone),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ProfileHeader — аватар с badge поверх + имя + роль
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  final String fullName;
  final String phone;
  final String role;
  final String status;

  const _ProfileHeader({
    required this.fullName,
    required this.phone,
    required this.role,
    required this.status,
  });

  String get _roleLabel {
    switch (role.toLowerCase()) {
      case 'courier':
        return 'Курьер';
      case 'shop':
      case 'business':
        return 'Заказчик';
      case 'client':
        return 'Наблюдатель';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _badgeCfg(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Аватар + статус-badge ──────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Цветное кольцо статуса вокруг аватара
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cfg.color, width: 2.5),
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: _kGradient,
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
            ),

            // Badge — правый нижний угол
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: cfg.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: cfg.color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Пульсация только для active
                    status.toLowerCase() == 'active'
                        ? _PulseDot(color: cfg.color)
                        : Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: cfg.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                    const SizedBox(width: 4),
                    Text(
                      cfg.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: cfg.color,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),

        // ── Имя + телефон ──────────────────────────────────────────────
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
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 12, color: _kGrey),
                  const SizedBox(width: 4),
                  Text(
                    phone.isNotEmpty ? phone : '+993 ...',
                    style: AppText.regular(fontSize: 13, color: _kGrey),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Роль-бейдж ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: _kGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _roleLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  _BadgeCfg _badgeCfg(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return _BadgeCfg(
          color: _kGreen,
          bg: const Color(0xFFEDF7F1),
          label: 'Активен',
        );
      case 'pending':
        return _BadgeCfg(
          color: const Color(0xFFE67E22),
          bg: const Color(0xFFFFF8EE),
          label: 'Проверка',
        );
      case 'banned':
        return _BadgeCfg(
          color: _kRed,
          bg: const Color(0xFFFFEBEB),
          label: 'Блок',
        );
      case 'published':
        return _BadgeCfg(
          color: const Color(0xFF2CA5E0),
          bg: const Color(0xFFE8F6FD),
          label: 'Новый',
        );
      default:
        return _BadgeCfg(color: _kGrey, bg: _kSurface, label: s);
    }
  }
}

class _BadgeCfg {
  final Color color;
  final Color bg;
  final String label;
  const _BadgeCfg({required this.color, required this.bg, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// _PulseDot — анимированная точка для статуса active
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// _PointsCard — карточка жетонов для курьера
// ═════════════════════════════════════════════════════════════════════════════

class _PointsCard extends StatelessWidget {
  final double balance;
  final VoidCallback onTopUp;

  const _PointsCard({required this.balance, required this.onTopUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A7A3C), Color(0xFF25A555)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Иконка ──────────────────────────────────────────────────
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/point_icon.png',
                width: 28,
                height: 28,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.toll_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // ── Баланс ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Мои жетоны',
                  style: AppText.medium(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),

          // ── Кнопка пополнить ────────────────────────────────────────
          GestureDetector(
            onTap: onTopUp,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    'Пополнить',
                    style: AppText.bold(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _FooterSection
// ═════════════════════════════════════════════════════════════════════════════

class _FooterSection extends StatelessWidget {
  final String companyName;
  final String appVersion;
  const _FooterSection({required this.companyName, required this.appVersion});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => _kGradient.createShader(b),
          child: Text(
            companyName.toUpperCase(),
            style: AppText.extraBold(
              fontSize: 12,
              color: Colors.white,
            ).copyWith(letterSpacing: 1.5),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '© 2024–2026. Все права защищены.',
          style: AppText.regular(fontSize: 11, color: _kGrey),
        ),
        if (appVersion.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Версия $appVersion',
            style: AppText.medium(fontSize: 10, color: const Color(0xFFD1D5DB)),
          ),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _SupportModal
// ═════════════════════════════════════════════════════════════════════════════

class _SupportModal extends StatelessWidget {
  final String phone;
  const _SupportModal({required this.phone});

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
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kGreen.withValues(alpha: 0.12),
                  _kRed.withValues(alpha: 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: _kGreen,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (b) => _kGradient.createShader(b),
            child: Text(
              'Поддержка',
              style: AppText.extraBold(fontSize: 20, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Мы готовы помочь вам в любое время',
            style: AppText.regular(fontSize: 13, color: _kGrey),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _makePhoneCall(phone),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2CA5E0).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2CA5E0).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2CA5E0).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Color(0xFF2CA5E0),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Телефон',
                          style: AppText.semiBold(
                            fontSize: 14,
                            color: const Color(0xFF0F1117),
                          ),
                        ),
                        Text(
                          phone,
                          style: AppText.regular(fontSize: 12, color: _kGrey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF2CA5E0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                'Закрыть',
                style: AppText.medium(fontSize: 14, color: _kGrey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _makePhoneCall(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

// ═════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _RoleSelectionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _RoleSelectionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F5EE), Color(0xFFFFF0EE)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _kGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Выберите вашу роль',
                    style: AppText.bold(
                      fontSize: 14,
                      color: const Color(0xFF0F1117),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Станьте курьером или заказчиком',
                    style: AppText.regular(fontSize: 12, color: _kGrey),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: _kGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
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
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: AppText.semiBold(fontSize: 14, color: const Color(0xFF0F1117)),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 13,
        color: Color(0xFFD1D5DB),
      ),
    );
  }
}
