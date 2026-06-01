import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/home/widgets/home_level_bar.dart';
import 'package:bagla/features/levels/level_provider.dart';
import 'package:bagla/features/orders/order_realtime_service.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/features/profile/widgets/banned_access_sheet.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Icon button used in AppBar actions
class HomeAppBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const HomeAppBarIcon({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, color: c.inkMuted, size: 19),
      ),
    );
  }
}

/// AppBar title — app name + level bar (courier) + balance chip + lang switcher
class HomeLogoRow extends StatelessWidget {
  final AuthProvider authProv;
  final OrderRealtimeService realtimeService;
  final VoidCallback onRefresh;
  final LevelProvider? levelProvider;

  const HomeLogoRow({
    super.key,
    required this.authProv,
    required this.realtimeService,
    required this.onRefresh,
    this.levelProvider,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final c = AppColors.of(context);
    final bool isCourier = authProv.role == 'courier';
    final bool isClient = authProv.role == 'client';
    final bool needsRoleSelection =
        isClient && authProv.status.toLowerCase() == 'published';
    final bool showLevelBar =
        isCourier && !needsRoleSelection && levelProvider != null;

    final Widget balanceChip;
    if (isCourier) {
      balanceChip = GestureDetector(
        onTap: () {
          // Banned-курьер не имеет доступа к пополнению жетонов —
          // показываем статус-баннер вместо формы top-up.
          if (authProv.isBanned) {
            BannedAccessSheet.show(context);
            return;
          }
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => TopUpModal(
              userId: authProv.userId,
              role: authProv.role,
              status: authProv.status,
            ),
          ).then((_) => onRefresh());
        },
        child: _BalanceChip(
          icon: Icons.toll_rounded,
          label: authProv.balancePoints.toDouble().toStringAsFixed(0),
          chipColor: c.amber,
          tintColor: c.amberTint,
        ),
      );
    } else {
      balanceChip = const SizedBox.shrink();
    }

    final Widget langSwitcher = GestureDetector(
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
    );

    if (showLevelBar) {
      return Row(
        children: [
          const SizedBox(width: 10),
          Expanded(child: HomeLevelBar(provider: levelProvider!)),
          const SizedBox(width: 8),
          balanceChip,
          const SizedBox(width: 8),
          langSwitcher,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Bagla', style: AppText.serif(fontSize: 19, color: c.ink)),
        const SizedBox(width: 10),
        balanceChip,
        const SizedBox(width: 8),
        langSwitcher,
      ],
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color chipColor;
  final Color tintColor;

  const _BalanceChip({
    required this.icon,
    required this.label,
    required this.chipColor,
    required this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tintColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: chipColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(label, style: AppText.semiBold(fontSize: 12, color: chipColor)),
        ],
      ),
    );
  }
}

/// Offline banner — animates in/out smoothly
class HomeNetworkBanner extends StatelessWidget {
  final bool isConnected;

  const HomeNetworkBanner({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: isConnected
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: c.bannerBg,
                border: Border(bottom: BorderSide(color: c.bannerBorder)),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 14, color: c.errorMuted),
                  const SizedBox(width: 8),
                  Text(
                    words.homeNoConnection,
                    style: AppText.regular(fontSize: 12, color: c.errorMuted),
                  ),
                ],
              ),
            ),
    );
  }
}
