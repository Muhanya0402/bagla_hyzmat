import 'dart:ui';
import 'package:bagla/core/api_client.dart';
import 'package:bagla/core/app_settings_provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/levels/level_card_widget.dart';
import 'package:bagla/features/levels/level_provider.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/language_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
      backgroundColor: AuthColors.bg,
      appBar: _buildAppBar(context, lang),
      body: RefreshIndicator(
        color: AuthColors.emerald,
        backgroundColor: Colors.white,
        onRefresh: () => Future.wait([
          auth.refreshProfile(),
          context.read<AppSettingsProvider>().load(),
        ]),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Top card: avatar + name + level (courier) ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ProfileTopCard(
                  auth: auth,
                  fullName: fullName,
                  isCourier: isCourier,
                ),
              ),
            ),

            // ── Role selection prompt ───────────────────────────────────────
            if (needsRoleSelection)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _RoleSelectionCard(
                    onTap: () =>
                        Navigator.pushNamed(context, '/user_type_selection'),
                  ),
                ),
              ),

            // ── Tokens card (courier) ───────────────────────────────────────
            if (isCourier)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _PointsCard(
                    balance: auth.balancePoints.toDouble(),
                    onTopUp: () => _openTopUp(context, auth),
                  ),
                ),
              ),

            // ── Menu ───────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildMenu(
                  context: context,
                  words: words,
                  auth: auth,
                  isCourier: isCourier,
                  isShop: isShop,
                  supportPhone: settings.supportPhone,
                ),
              ),
            ),

            // ── Footer ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                child: _FooterSection(
                  companyName: settings.companyName,
                  appVersion: settings.appVersion,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext context, LanguageProvider lang) => AppBar(
    backgroundColor: AuthColors.bg,
    elevation: 0,
    centerTitle: false,
    automaticallyImplyLeading: false,
    title: Text(
      'Профиль',
      style: AppText.serif(fontSize: 18, color: AuthColors.ink),
    ),
    actions: [
      GestureDetector(
        onTap: lang.toggleLanguage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AuthColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AuthColors.border),
          ),
          child: Text(
            lang.label,
            style: AppText.semiBold(fontSize: 12, color: AuthColors.inkMuted),
          ),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () => _showLogoutConfirm(context),
        child: Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: Text(
            'Выйти',
            style: AppText.medium(fontSize: 13, color: AuthColors.errorMuted),
          ),
        ),
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(0.5),
      child: Container(height: 0.5, color: AuthColors.border),
    ),
  );

  // ── Menu ────────────────────────────────────────────────────────────────────
  Widget _buildMenu({
    required BuildContext context,
    required dynamic words,
    required AuthProvider auth,
    required bool isCourier,
    required bool isShop,
    required String supportPhone,
  }) {
    final items = <Widget>[];

    items.add(_MenuTile(
      icon: Icons.inbox_outlined,
      title: words.feedbacks,
      onTap: () => Navigator.pushNamed(context, '/appeals'),
    ));

    if (isShop || (isCourier && auth.status != 'published')) {
      items.add(const Divider(
        height: 1,
        thickness: 0.8,
        indent: 52,
        color: AuthColors.borderSoft,
      ));
      items.add(_MenuTile(
        icon: Icons.description_outlined,
        title: words.termsOfUse,
        onTap: () => Navigator.pushNamed(context, '/terms'),
      ));
    }

    items.add(const Divider(
      height: 1,
      thickness: 0.8,
      indent: 52,
      color: AuthColors.borderSoft,
    ));
    items.add(_MenuTile(
      icon: Icons.headset_mic_outlined,
      title: 'Связаться с поддержкой',
      onTap: () => _showSupportModal(context, supportPhone),
    ));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(children: items),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  void _openTopUp(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          TopUpModal(userId: auth.userId, role: auth.role, status: auth.status),
    ).then((_) => auth.refreshProfile());
  }

  void _showLogoutConfirm(BuildContext context) {
    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withValues(alpha: 0.18)),
          ),
          Center(
            child: _LogoutDialog(
              onConfirm: () => _handleLogout(context),
            ),
          ),
        ],
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Capture navigator ref BEFORE the async gap — context may be deactivated
    // after logout() calls notifyListeners() and rebuilds the widget tree.
    final navigator = Navigator.of(context, rootNavigator: true);
    await context.read<AuthProvider>().logout();
    navigator.pushNamedAndRemoveUntil('/login', (r) => false);
  }

  void _showSupportModal(BuildContext context, String phone) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _SupportModal(phone: phone),
    );
  }
}

// ── Top card: profile + level progress ────────────────────────────────────────
class _ProfileTopCard extends StatefulWidget {
  final AuthProvider auth;
  final String fullName;
  final bool isCourier;

  const _ProfileTopCard({
    required this.auth,
    required this.fullName,
    required this.isCourier,
  });

  @override
  State<_ProfileTopCard> createState() => _ProfileTopCardState();
}

class _ProfileTopCardState extends State<_ProfileTopCard> {
  @override
  void initState() {
    super.initState();
    if (widget.isCourier && widget.auth.userId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final lp = context.read<LevelProvider>();
        if (!lp.isLoading && lp.currentLevel == null) {
          lp.loadForUser(widget.auth.userId);
        }
      });
    }
  }

  String get _roleLabel {
    switch (widget.auth.role.toLowerCase()) {
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

  _StatusCfg _cfg(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return _StatusCfg(
          color: AuthColors.emerald,
          bg: AuthColors.emeraldTint,
          label: 'Активен',
        );
      case 'pending':
        return _StatusCfg(
          color: AuthColors.amber,
          bg: AuthColors.amberTint,
          label: 'Проверка',
        );
      case 'banned':
        return _StatusCfg(
          color: AuthColors.errorMuted,
          bg: AuthColors.errorTint,
          label: 'Блок',
        );
      case 'published':
        return _StatusCfg(
          color: AuthColors.inkMuted,
          bg: AuthColors.borderSoft,
          label: 'Новый',
        );
      default:
        return _StatusCfg(
          color: AuthColors.inkSoft,
          bg: AuthColors.bg,
          label: s,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg(widget.auth.status);
    final lang = context.watch<LanguageProvider>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar + status badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cfg.color, width: 2),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AuthColors.emerald,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.fullName.isNotEmpty
                                ? widget.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cfg.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widget.auth.status.toLowerCase() == 'active'
                                ? _PulseDot(color: cfg.color)
                                : Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: cfg.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            const SizedBox(width: 3),
                            Text(
                              cfg.label,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
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

                const SizedBox(width: 14),

                // Name + role + phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.fullName,
                              style: AppText.serif(
                                fontSize: 17,
                                color: AuthColors.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AuthColors.emeraldTint,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _roleLabel,
                              style: AppText.semiBold(
                                fontSize: 10,
                                color: AuthColors.emerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 11,
                            color: AuthColors.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.auth.phone.isNotEmpty
                                ? widget.auth.phone
                                : '+993 ...',
                            style: AppText.regular(
                              fontSize: 12,
                              color: AuthColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Level progress (courier) ──────────────────────────────────
          if (widget.isCourier)
            Consumer<LevelProvider>(
              builder: (_, lp, _) {
                if (lp.isLoading || lp.currentLevel == null) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AuthColors.borderSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
                final level = lp.currentLevel!;
                final progress = lp.progressInLevel.clamp(0.0, 1.0);
                final nextXp = lp.nextLevel?.xpRequired;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showLevelDetailsSheet(
                    context,
                    provider: lp,
                    words: lang.words,
                    isRu: lang.isRu,
                  ),
                  child: Column(
                    children: [
                      const Divider(
                        height: 1,
                        thickness: 0.8,
                        color: AuthColors.borderSoft,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 11, 16, 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events_outlined,
                                  size: 13,
                                  color: AuthColors.amber,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${level.title(lang.isRu)}  •  Ур. ${level.levelNumber}',
                                  style: AppText.medium(
                                    fontSize: 12,
                                    color: AuthColors.inkMuted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  nextXp != null
                                      ? '${lp.currentXp} / $nextXp XP'
                                      : '${lp.currentXp} XP',
                                  style: AppText.semiBold(
                                    fontSize: 11,
                                    color: AuthColors.ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: AuthColors.amberTint,
                                valueColor: const AlwaysStoppedAnimation(
                                  AuthColors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatusCfg {
  final Color color;
  final Color bg;
  final String label;
  const _StatusCfg({
    required this.color,
    required this.bg,
    required this.label,
  });
}

// ── Pulsing dot for active status ─────────────────────────────────────────────
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
    _anim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

// ── Tokens card ───────────────────────────────────────────────────────────────
class _PointsCard extends StatefulWidget {
  final double balance;
  final VoidCallback onTopUp;

  const _PointsCard({required this.balance, required this.onTopUp});

  @override
  State<_PointsCard> createState() => _PointsCardState();
}

class _PointsCardState extends State<_PointsCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AuthColors.amberTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.amber.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AuthColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.toll_rounded,
                  color: AuthColors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мои жетоны',
                      style: AppText.regular(
                        fontSize: 11,
                        color: AuthColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.balance.toStringAsFixed(2),
                      style: AppText.bold(
                        fontSize: 22,
                        color: AuthColors.ink,
                      ).copyWith(letterSpacing: -0.5, height: 1.1),
                    ),
                  ],
                ),
              ),
              // Top-up button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) {
                  setState(() => _pressed = false);
                  widget.onTopUp();
                },
                onTapCancel: () => setState(() => _pressed = false),
                child: AnimatedScale(
                  scale: _pressed ? 0.94 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AuthColors.emeraldTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AuthColors.emerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: AuthColors.emerald,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Пополнить',
                          style: AppText.semiBold(
                            fontSize: 12,
                            color: AuthColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Hint
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 11,
                color: AuthColors.inkSoft,
              ),
              const SizedBox(width: 5),
              Text(
                'Жетоны списываются только при взятии заказа',
                style: AppText.regular(
                  fontSize: 11,
                  color: AuthColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Role selection card ───────────────────────────────────────────────────────
class _RoleSelectionCard extends StatefulWidget {
  final VoidCallback onTap;
  const _RoleSelectionCard({required this.onTap});

  @override
  State<_RoleSelectionCard> createState() => _RoleSelectionCardState();
}

class _RoleSelectionCardState extends State<_RoleSelectionCard> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AuthColors.amberTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AuthColors.amber.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AuthColors.emerald,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выберите вашу роль',
                      style: AppText.semiBold(
                        fontSize: 13,
                        color: AuthColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Станьте курьером или заказчиком',
                      style: AppText.regular(
                        fontSize: 11,
                        color: AuthColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AuthColors.emeraldTint,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AuthColors.emerald,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu tile ─────────────────────────────────────────────────────────────────
class _MenuTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _pressed
            ? AuthColors.emeraldTint.withValues(alpha: 0.6)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AuthColors.borderSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: 16, color: AuthColors.inkMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: AppText.medium(fontSize: 14, color: AuthColors.ink),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AuthColors.inkSoft,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _FooterSection extends StatelessWidget {
  final String companyName;
  final String appVersion;
  const _FooterSection({required this.companyName, required this.appVersion});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          companyName.toUpperCase(),
          style: AppText.semiBold(
            fontSize: 11,
            color: AuthColors.inkMuted,
          ).copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 5),
        Text(
          '© 2024–2026. Все права защищены.',
          style: AppText.regular(fontSize: 11, color: AuthColors.inkSoft),
        ),
        if (appVersion.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Версия $appVersion',
            style: AppText.regular(fontSize: 10, color: AuthColors.border),
          ),
        ],
      ],
    );
  }
}

// ── Support modal ─────────────────────────────────────────────────────────────
class _SupportModal extends StatefulWidget {
  final String phone;
  const _SupportModal({required this.phone});

  @override
  State<_SupportModal> createState() => _SupportModalState();
}

class _SupportModalState extends State<_SupportModal> {
  String? _category;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _isLoading = false;

  static const _categories = [
    'Проблема с заказом',
    'Списание жетонов',
    'Ошибка в приложении',
    'Предложение',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      _focus.requestFocus();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      await ApiClient().dio.post(
        '/items/appeals',
        data: {
          'user_id': int.tryParse(auth.userId) ?? auth.userId,
          'subject': _category ?? 'Обращение в поддержку',
          'body': text,
          'status': 'open',
        },
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Сообщение отправлено',
            style: AppText.medium(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: AuthColors.emerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Ошибка отправки. Попробуйте позже.',
            style: AppText.medium(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: AuthColors.errorMuted,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          bottomInset > 0 ? bottomInset + 16 : bottomPadding + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 32,
                height: 3.5,
                decoration: BoxDecoration(
                  color: AuthColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AuthColors.emeraldTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.headset_mic_outlined,
                    color: AuthColors.emerald,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Служба поддержки',
                        style: AppText.serif(
                          fontSize: 17,
                          color: AuthColors.ink,
                        ),
                      ),
                      Text(
                        'Мы на связи и готовы помочь вам с любым вопросом',
                        style: AppText.regular(
                          fontSize: 11,
                          color: AuthColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Category tags ────────────────────────────────────────────────
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _categories.map((cat) {
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(
                    () => _category = sel ? null : cat,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? AuthColors.emeraldTint
                          : AuthColors.borderSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? AuthColors.emerald.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: AppText.medium(
                        fontSize: 12,
                        color: sel
                            ? AuthColors.emerald
                            : AuthColors.inkMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // ── Message field ────────────────────────────────────────────────
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              maxLines: 4,
              minLines: 3,
              textInputAction: TextInputAction.newline,
              style: AppText.regular(fontSize: 14, color: AuthColors.ink),
              decoration: InputDecoration(
                hintText: 'Опишите ваш вопрос...',
                hintStyle: AppText.regular(
                  fontSize: 14,
                  color: AuthColors.inkSoft,
                ),
                filled: true,
                fillColor: AuthColors.bg,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AuthColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AuthColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AuthColors.emerald,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Actions ──────────────────────────────────────────────────────
            Row(
              children: [
                // Call button
                GestureDetector(
                  onTap: () => _makePhoneCall(widget.phone),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AuthColors.borderSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.call_outlined,
                      color: AuthColors.inkMuted,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Send button
                Expanded(
                  child: _SendButton(
                    isLoading: _isLoading,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Send button with spring press ─────────────────────────────────────────────
class _SendButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SendButton({required this.isLoading, required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 46,
          decoration: BoxDecoration(
            color: widget.isLoading
                ? AuthColors.emerald.withValues(alpha: 0.5)
                : AuthColors.emerald,
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isLoading
                ? null
                : [
                    BoxShadow(
                      color: AuthColors.emerald.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Отправить сообщение',
                      style: AppText.semiBold(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Logout confirmation dialog ────────────────────────────────────────────────
class _LogoutDialog extends StatefulWidget {
  final VoidCallback onConfirm;
  const _LogoutDialog({required this.onConfirm});

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  bool _cancelPressed = false;
  bool _confirmPressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AuthColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AuthColors.border),
          boxShadow: [
            BoxShadow(
              color: AuthColors.ink.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AuthColors.errorTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AuthColors.errorMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Выйти из профиля?',
              style: AppText.serif(fontSize: 19, color: AuthColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              'Вы сможете войти снова в любой момент, используя свой номер телефона. Все ваши данные, жетоны и уровень (XP) будут сохранены.',
              style: AppText.regular(
                fontSize: 13,
                color: AuthColors.inkMuted,
              ).copyWith(height: 1.55),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _cancelPressed = true),
                    onTapUp: (_) {
                      setState(() => _cancelPressed = false);
                      Navigator.pop(context);
                    },
                    onTapCancel: () =>
                        setState(() => _cancelPressed = false),
                    child: AnimatedScale(
                      scale: _cancelPressed ? 0.97 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: AuthColors.borderSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Остаться',
                          style: AppText.medium(
                            fontSize: 14,
                            color: AuthColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Confirm
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _confirmPressed = true),
                    onTapUp: (_) {
                      setState(() => _confirmPressed = false);
                      Navigator.pop(context);
                      widget.onConfirm();
                    },
                    onTapCancel: () =>
                        setState(() => _confirmPressed = false),
                    child: AnimatedScale(
                      scale: _confirmPressed ? 0.97 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: AuthColors.errorMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Выйти',
                          style: AppText.medium(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _makePhoneCall(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}
