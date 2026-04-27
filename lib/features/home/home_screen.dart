import 'package:bagla/core/api_client.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/create_order_screen.dart';
import 'package:bagla/features/orders/order_card.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const Color brandBlue = Color(0xFF1B3A6B);
  static const Color brandGreen = Color(0xFF27AE60);
  static const Color brandRed = Color(0xFFB00020);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFilterIndex = 0;
  String? _selectedStatus;
  final OrderService _orderService = OrderService();

  static const List<_StatusFilter> _statusFilters = [
    _StatusFilter(label: "Все", value: null, color: Color(0xFF9AA3AF)),
    _StatusFilter(
      label: "Свободные",
      value: "published",
      color: HomeScreen.brandRed,
    ),
    _StatusFilter(
      label: "В работе",
      value: "active",
      color: HomeScreen.brandBlue,
    ),
    _StatusFilter(
      label: "Доставлены",
      value: "completed",
      color: HomeScreen.brandGreen,
    ),
    _StatusFilter(
      label: "Отменены",
      value: "canceled",
      color: Color(0xFF9AA3AF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWelcomeBonus();
    });
  }

  Future<void> _checkWelcomeBonus() async {
    final authProv = context.read<AuthProvider>();
    try {
      final response = await ApiClient().dio.get(
        '/items/customers/${authProv.userId}',
        queryParameters: {'fields': 'welcome_bonus_shown'},
      );
      final bool shown = response.data['data']['welcome_bonus_shown'] ?? false;
      if (!shown && mounted) {
        await ApiClient().dio.patch(
          '/items/customers/${authProv.userId}',
          data: {'welcome_bonus_shown': true},
        );
        _showWelcomeBonusModal();
      }
    } catch (e) {
      debugPrint('Ошибка проверки welcome bonus: $e');
    }
  }

  void _showWelcomeBonusModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/point_icon.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.toll_rounded,
                    size: 48,
                    color: Color(0xFF27AE60),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '🎁 Подарок за первый вход!',
              style: AppText.extraBold(
                fontSize: 20,
                color: const Color(0xFF1B3A6B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Мы начислили вам',
              style: AppText.regular(fontSize: 15, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF27AE60).withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/point_icon.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.toll_rounded,
                      size: 32,
                      color: Color(0xFF27AE60),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '3 жетона',
                    style: AppText.extraBold(
                      fontSize: 28,
                      color: const Color(0xFF27AE60),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Используйте жетоны для выполнения заказов внутри приложения',
              style: AppText.regular(
                fontSize: 13,
                color: Colors.black38,
              ).copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'ОТЛИЧНО!',
                  style: AppText.bold(
                    fontSize: 15,
                    color: Colors.white,
                  ).copyWith(letterSpacing: .5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await context.read<AuthProvider>().refreshProfile();
    setState(() {});
  }

  List<dynamic> _filterByStatus(List<dynamic> orders) {
    if (_selectedStatus == null) return orders;
    return orders
        .where(
          (o) =>
              (o['order_status'] ?? '').toString().toLowerCase() ==
              _selectedStatus,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final words = context.watch<LanguageProvider>().words;

    final String currentStatus = authProv.status.toLowerCase().trim();
    final String role = authProv.role.toLowerCase().trim();

    final bool isActive = currentStatus == 'active';
    final bool isShop = role == 'shop' || role == 'business';
    final bool isCourier = role == 'courier';
    final bool isBanned =
        currentStatus == 'archived' || currentStatus == 'banned';
    final bool isPending = currentStatus == 'pending' && (isCourier || isShop);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: _buildLogo(authProv),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/notifications'),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: HomeScreen.brandBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HomeScreen.brandBlue.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: HomeScreen.brandBlue,
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: HomeScreen.brandBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HomeScreen.brandBlue.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: HomeScreen.brandBlue,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCourier)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildSegmentedFilter(),
            ),
          if (isBanned || isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildStatusBanner(isBanned),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 0, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    isShop ? "Мои заказы" : "Доступные заказы",
                    style: AppText.semiBold(
                      fontSize: 20,
                      color: HomeScreen.brandBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (isShop || _selectedFilterIndex == 1)
                  _buildStatusFilterRow(),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: HomeScreen.brandGreen,
              backgroundColor: Colors.white,
              onRefresh: _handleRefresh,
              child: FutureBuilder<List<dynamic>>(
                key: ValueKey(
                  '${isShop ? 'shop' : _selectedFilterIndex}-${authProv.userId}',
                ),
                future: _orderService.getOrders(
                  role: authProv.role,
                  userId: authProv.userId,
                  myOrdersOnly: isShop ? true : (_selectedFilterIndex == 1),
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: HomeScreen.brandGreen,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildScrollableEmptyState(
                      icon: Icons.wifi_off_rounded,
                      text: "Ошибка загрузки. Потяните вниз.",
                    );
                  }
                  final orders = _filterByStatus(snapshot.data ?? []);
                  if (orders.isEmpty) {
                    return _buildScrollableEmptyState(
                      icon: Icons.inbox_rounded,
                      text: isShop ? "У вас пока нет заказов" : words.emptyList,
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    itemCount: orders.length,
                    itemBuilder: (context, index) => OrderCard(
                      order: orders[index],
                      role: isShop ? 'shop' : 'courier',
                      currentUserId: authProv.userId,
                      userPhone: authProv.phone,
                      onUpdate: _handleRefresh,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(
                            order: orders[index],
                            role: isShop ? 'shop' : 'courier',
                            currentUserId: authProv.userId,
                            onUpdate: _handleRefresh,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: (isShop && isActive)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildCreateButton(context),
              ),
            )
          : null,
    );
  }

  Widget _buildLogo(AuthProvider authProv) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/bagla_logo.png',
          width: 56,
          height: 56,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Container(width: 6, height: 22, color: Colors.red),
        ),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) => TopUpModal(
                userId: authProv.userId,
                role: authProv.role,
                status: authProv.status,
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/point_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
              Text(
                "${authProv.balancePoints}",
                style: AppText.semiBold(
                  fontSize: 18,
                  color: HomeScreen.brandGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: _statusFilters.map((filter) {
          final bool isSelected = _selectedStatus == filter.value;
          return GestureDetector(
            onTap: () => setState(() => _selectedStatus = filter.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? filter.color.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? filter.color.withOpacity(0.4)
                      : const Color(0xFFEEF0F3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: filter.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    filter.label,
                    style: isSelected
                        ? AppText.semiBold(fontSize: 12, color: filter.color)
                        : AppText.medium(
                            fontSize: 12,
                            color: const Color(0xFF9AA3AF),
                          ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSegmentedFilter() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF0F3), width: 1),
      ),
      child: Row(
        children: [
          _filterItem(0, "Доступные заказы"),
          _filterItem(1, "Мои заказы"),
        ],
      ),
    );
  }

  Widget _filterItem(int index, String label) {
    final bool isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? HomeScreen.brandGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppText.medium(
              fontSize: 13,
              color: isSelected ? Colors.white : const Color(0xFF9AA3AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(bool isBanned) {
    final Color color = isBanned
        ? HomeScreen.brandRed
        : const Color(0xFFE67E22);
    final Color bgColor = isBanned
        ? const Color(0xFFFFF0F0)
        : const Color(0xFFFFF8EE);
    final IconData icon = isBanned
        ? Icons.block_rounded
        : Icons.access_time_rounded;
    final String text = isBanned
        ? "Аккаунт заблокирован"
        : "Ожидание проверки модератора";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.medium(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
      ).then((_) => setState(() {})),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: HomeScreen.brandGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              "Создать заказ",
              style: AppText.medium(
                fontSize: 15,
                color: Colors.white,
              ).copyWith(letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableEmptyState({
    required IconData icon,
    required String text,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEEF0F3), width: 1),
            ),
            child: Icon(
              icon,
              size: 32,
              color: HomeScreen.brandBlue.withOpacity(0.2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            text,
            style: AppText.medium(fontSize: 14, color: const Color(0xFF9AA3AF)),
          ),
        ),
      ],
    );
  }
}

class _StatusFilter {
  final String label;
  final String? value;
  final Color color;

  const _StatusFilter({
    required this.label,
    required this.value,
    required this.color,
  });
}
