import 'package:bagla/features/home/widgets/home_widgets.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:flutter/material.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_constants.dart';
import 'package:bagla/features/orders/order_card.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/l10n/app_localizations.dart';

class _OrderExpandRoute<T> extends PageRouteBuilder<T> {
  _OrderExpandRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (ctx, _, _) => builder(ctx),
          transitionsBuilder: (_, anim, _, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        );
}

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
  final bool swipeEnabled;
  final int selectedFilterIndex;
  final ValueChanged<int>? onSwipe;

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
    this.swipeEnabled = false,
    this.selectedFilterIndex = 0,
    this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (!swipeEnabled || onSwipe == null) return content;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -300 && selectedFilterIndex == 0) {
          onSwipe!(1);
        } else if (v > 300 && selectedFilterIndex == 1) {
          onSwipe!(0);
        }
      },
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
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
          onTap: () {
            if (authProv.role == 'client') {
              showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => RolePickerEmbedded(
                  onClose: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                ),
              ).then((_) => onRefresh());
              return;
            }
            Navigator.push(
              context,
              _OrderExpandRoute(
                settings: const RouteSettings(name: '/order_detail'),
                builder: (_) => OrderDetailScreen(
                  order: orders[index],
                  role: isShop ? 'shop' : 'courier',
                  currentUserId: authProv.userId,
                  onUpdate: onRefresh,
                ),
              ),
            ).then((_) => onRefresh());
          },
        );
      },
    );
  }
}
