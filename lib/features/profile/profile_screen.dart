import 'dart:ui';
import 'package:bagla/core/app_settings_provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/theme/theme_toggle_button.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/features/profile/widgets/footer_section.dart';
import 'package:bagla/features/profile/widgets/logout_dialog.dart';
import 'package:bagla/features/profile/widgets/menu_tile.dart';
import 'package:bagla/features/profile/widgets/points_card.dart';
import 'package:bagla/features/profile/widgets/profile_top_card.dart';
import 'package:bagla/features/profile/widgets/role_selection_card.dart';
import 'package:bagla/features/profile/widgets/support_modal.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AppTourMixin<ProfileScreen> {
  // ── Tour anchors — повешены на сами виджеты, а не на Padding'и ──────────
  final _topCardKey = GlobalKey();
  final _roleSelectKey = GlobalKey();
  final _topUpKey = GlobalKey();
  final _menuKey = GlobalKey();
  final _logoutKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    startTourIfNeeded(
      screenKey: TourKeys.profile,
      targetsBuilder: _buildTourTargets,
    );
  }

  List<TargetFocus> _buildTourTargets() {
    final auth = context.read<AuthProvider>();
    final words = context.read<LanguageProvider>().words;

    if (auth.shouldSkipTour) return const [];

    // Собираем динамический список «спецификаций» — потом конвертируем,
    // выставив isLast на последнем фактически отрисованном шаге.
    final specs = <(GlobalKey, String, String, ContentAlign)>[
      (
        _topCardKey,
        words.tourProfileTitle,
        words.tourProfileBody,
        ContentAlign.bottom,
      ),
      if (auth.needsRoleSelection)
        (
          _roleSelectKey,
          words.tourProfileRolePickTitle,
          words.tourProfileRolePickBody,
          ContentAlign.bottom,
        ),
      if (auth.isCourier)
        (
          _topUpKey,
          words.tourProfileTopUpTitle,
          words.tourProfileTopUpBody,
          ContentAlign.bottom,
        ),
      (
        _menuKey,
        words.tourProfileMenuTitle,
        words.tourProfileMenuBody,
        ContentAlign.top,
      ),
      (
        _logoutKey,
        words.tourProfileLogoutTitle,
        words.tourProfileLogoutBody,
        ContentAlign.bottom,
      ),
    ];

    return [
      for (var i = 0; i < specs.length; i++)
        TourTarget.build(
          key: specs[i].$1,
          title: specs[i].$2,
          body: specs[i].$3,
          align: specs[i].$4,
          isLast: i == specs.length - 1,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final words = lang.words;
    final c = AppColors.of(context);

    final String fullName = (auth.name.isEmpty && auth.surname.isEmpty)
        ? words.user
        : '${auth.name} ${auth.surname}'.trim();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _buildAppBar(context, lang),
      body: RefreshIndicator(
        color: c.ink,
        backgroundColor: c.surface,
        onRefresh: () => Future.wait([
          auth.refreshProfile(),
          context.read<AppSettingsProvider>().load(),
        ]),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ProfileTopCard(
                  key: _topCardKey,
                  auth: auth,
                  fullName: fullName,
                  isCourier: auth.isCourier,
                ),
              ),
            ),

            if (auth.needsRoleSelection)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: RoleSelectionCard(
                    key: _roleSelectKey,
                    onTap: () =>
                        Navigator.pushNamed(context, '/user_type_selection'),
                  ),
                ),
              ),

            if (auth.isCourier)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: PointsCard(
                    balance: auth.balancePoints.toDouble(),
                    isLoading: auth.userId.isEmpty,
                    onTopUp: () => _openTopUp(context, auth),
                    topUpKey: _topUpKey,
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: KeyedSubtree(
                  key: _menuKey,
                  child: _buildMenu(
                    context: context,
                    auth: auth,
                    supportPhone: settings.supportPhone,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                child: FooterSection(
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

  // ── AppBar ──────────────────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext context, LanguageProvider lang) {
    final c = AppColors.of(context);
    final words = lang.words;
    return AppBar(
      backgroundColor: c.bg,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      title: Text(
        words.profileScreenTitle,
        style: AppText.serif(fontSize: 18, color: c.ink),
      ),
      actions: [
        GestureDetector(
          onTap: lang.toggleLanguage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Text(
              lang.label,
              style: AppText.semiBold(fontSize: 12, color: c.inkMuted),
            ),
          ),
        ),
        const SizedBox(width: 8),
        KeyedSubtree(
          key: _logoutKey,
          child: GestureDetector(
            onTap: () => _showLogoutConfirm(context),
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 4),
              child: Text(
                words.profileLogout,
                style: AppText.medium(fontSize: 13, color: c.errorMuted),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: c.border),
      ),
    );
  }

  // ── Menu ────────────────────────────────────────────────────────────────
  Widget _buildMenu({
    required BuildContext context,
    required AuthProvider auth,
    required String supportPhone,
  }) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
    final items = <Widget>[];

    items.add(
      ProfileMenuTile(
        icon: Icons.inbox_outlined,
        title: words.feedbacks,
        onTap: () => Navigator.pushNamed(context, '/appeals'),
      ),
    );

    if (auth.isShop || (auth.isCourier && !auth.isPublished)) {
      items.add(
        Divider(height: 1, thickness: 0.8, indent: 52, color: c.borderSoft),
      );
      items.add(
        ProfileMenuTile(
          icon: Icons.description_outlined,
          title: words.termsOfUse,
          onTap: () => Navigator.pushNamed(context, '/terms'),
        ),
      );
    }

    items.add(
      Divider(height: 1, thickness: 0.8, indent: 52, color: c.borderSoft),
    );
    items.add(
      ProfileMenuTile(
        icon: Icons.headset_mic_outlined,
        title: words.profileSupportContact,
        onTap: () => _showSupportModal(context, supportPhone),
      ),
    );

    items.add(
      Divider(height: 1, thickness: 0.8, indent: 52, color: c.borderSoft),
    );
    items.add(const ThemeToggleTile());

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(children: items),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  void _openTopUp(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TopUpModal(
        userId: auth.userId,
        role: auth.role,
        status: auth.status,
      ),
    ).then((_) => auth.refreshProfile());
  }

  void _showLogoutConfirm(BuildContext context) {
    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: '',
      // Один источник dimming — barrierColor + blur. Без чёрного контейнера.
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: const SizedBox.expand(),
          ),
          Center(
            child: LogoutDialog(onConfirm: () => _handleLogout(context)),
          ),
        ],
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
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
      builder: (_) => SupportModal(phone: phone),
    );
  }
}
