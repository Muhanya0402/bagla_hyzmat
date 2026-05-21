import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/features/home/widgets/wallet_info_modal.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/features/auth/phone_screen.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/services/order_realtime_service.dart';
import 'package:flutter/material.dart';

/// Иконка-кнопка в AppBar
class HomeAppBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const HomeAppBarIcon({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: HomeColors.green.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HomeColors.green.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: HomeColors.green, size: 19),
      ),
    );
  }
}

/// Левая часть AppBar — логотип + баланс
class HomeLogoRow extends StatelessWidget {
  final AuthProvider authProv;
  final OrderRealtimeService realtimeService;
  final VoidCallback onRefresh;

  const HomeLogoRow({
    super.key,
    required this.authProv,
    required this.realtimeService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final bool isShop = authProv.role == 'shop' || authProv.role == 'business';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          realtimeService.isConnected
              ? 'assets/images/bagla_logo.png'
              : 'assets/images/bagla_logo_gray.png',
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const BaglaLogo(width: 48, height: 24),
        ),
        const SizedBox(width: 8),
        if (isShop)
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => WalletInfoModal(balance: authProv.walletBalance),
            ).then((_) => onRefresh()),
            child: _BalanceChip(
              icon: Icons.account_balance_wallet_rounded,
              label: '${authProv.walletBalance.toStringAsFixed(2)} TMT',
            ),
          )
        else
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => TopUpModal(
                userId: authProv.userId,
                role: authProv.role,
                status: authProv.status,
              ),
            ).then((_) => onRefresh()),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/point_icon.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.toll_rounded,
                    size: 20,
                    color: HomeColors.green,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  authProv.balancePoints.toDouble().toStringAsFixed(2),
                  style: AppText.semiBold(
                    fontSize: 15,
                    color: HomeColors.green,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BalanceChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: HomeColors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: HomeColors.green),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.semiBold(fontSize: 13, color: HomeColors.green),
          ),
        ],
      ),
    );
  }
}
