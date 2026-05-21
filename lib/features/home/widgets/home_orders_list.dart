import 'package:bagla/features/home/widgets/home_widgets.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/features/orders/order_card.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/l10n/app_localizations.dart';

class HomeOrdersList extends StatelessWidget {
  final List<dynamic> orders;
  final bool isLoading;
  final bool hasError;
  final bool isShop;
  final bool loadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final AuthProvider authProv;
  final AppLocalizations words;
  final VoidCallback onRefresh;

  const HomeOrdersList({
    super.key,
    required this.orders,
    required this.isLoading,
    required this.hasError,
    required this.isShop,
    required this.loadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.authProv,
    required this.words,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: HomeColors.green,
          strokeWidth: 2,
        ),
      );
    }
    if (hasError) {
      return const HomeEmptyState(
        icon: Icons.wifi_off_rounded,
        text: 'Ошибка загрузки. Потяните вниз.',
      );
    }
    if (orders.isEmpty) {
      return HomeEmptyState(
        icon: Icons.inbox_rounded,
        text: isShop ? 'У вас пока нет заказов' : words.emptyList,
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: orders.length + 1,
      itemBuilder: (context, index) {
        if (index == orders.length) {
          if (loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: HomeColors.green,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          if (!hasMore && orders.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Все заказы загружены',
                  style: AppText.regular(fontSize: 12, color: HomeColors.grey),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return OrderCard(
          order: orders[index],
          role: isShop ? 'shop' : 'courier',
          currentUserId: authProv.userId,
          userPhone: authProv.phone,
          onUpdate: onRefresh,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/order_detail'),
              builder: (_) => OrderDetailScreen(
                order: orders[index],
                role: isShop ? 'shop' : 'courier',
                currentUserId: authProv.userId,
                onUpdate: onRefresh,
              ),
            ),
          ).then((_) => onRefresh()),
        );
      },
    );
  }
}
