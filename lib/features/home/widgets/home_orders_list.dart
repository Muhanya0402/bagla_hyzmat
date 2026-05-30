import 'package:animations/animations.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/home/widgets/home_widgets.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
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
      // Cards don't need to survive being scrolled out of view.
      addAutomaticKeepAlives: false,
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

        // Клиент — только модальный выбор роли, без Container Transform.
        if (authProv.role == 'client') {
          return OrderCard(
            order: orders[index],
            role: 'courier',
            currentUserId: authProv.userId,
            userPhone: authProv.phone,
            onUpdate: onRefresh,
            onTap: () => showModalBottomSheet(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => RolePickerEmbedded(
                onClose: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              ),
            ).then((_) => onRefresh()),
          );
        }

        // Курьер / магазин — Container Transform из карточки в экран деталей.
        final c = AppColors.of(context);
        final role = isShop ? 'shop' : 'courier';
        final order = orders[index];

        // RepaintBoundary isolates each card's repaint from its neighbours.
        return RepaintBoundary(child: OpenContainer<void>(
          tappable: false,
          transitionDuration: const Duration(milliseconds: 340),
          transitionType: ContainerTransitionType.fadeThrough,
          // Цвет фона закрытой карточки = surface (совпадает с OrderCard)
          closedColor: c.surface,
          // Цвет открытого экрана = bg (совпадает с OrderDetailScreen.bg)
          openColor: c.bg,
          middleColor: c.bg,
          // Скругление совпадает с BorderRadius карточки → плавное раскрытие
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          openShape: const RoundedRectangleBorder(),
          closedElevation: 0,
          openElevation: 0,
          // onClosed заменяет .then((_) => onRefresh()) от Navigator.push
          onClosed: (_) => onRefresh(),
          closedBuilder: (_, openContainer) => OrderCard(
            order: order,
            role: role,
            currentUserId: authProv.userId,
            userPhone: authProv.phone,
            onUpdate: onRefresh,
            // onTap передаёт управление OpenContainer для запуска анимации
            onTap: openContainer,
          ),
          openBuilder: (_, _) => OrderDetailScreen(
            order: order,
            role: role,
            currentUserId: authProv.userId,
            onUpdate: onRefresh,
          ),
        ));
      },
    );
  }
}
