import 'package:bagla/core/api_client.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/create_order_screen.dart';
import 'package:bagla/features/home/widgets/wallet_info_modal.dart';
import 'package:bagla/features/orders/order_card.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/providers/level_provider.dart';
import 'package:bagla/services/order_realtime_service.dart';
import 'package:bagla/services/order_service.dart';
import 'package:bagla/features/auth/phone_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const Color brandDark = Color(0xFF111111);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFilterIndex = 0;
  String? _selectedStatus;
  final OrderService _orderService = OrderService();

  // ── Realtime ───────────────────────────────────────────────────────────────
  final OrderRealtimeService _realtimeService = OrderRealtimeService();
  List<dynamic> _orders = [];
  bool _ordersLoading = true;
  bool _ordersError = false;
  int _httpOffset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  static const int _pageSize = 6;
  final ScrollController _scrollController = ScrollController();

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
      color: HomeScreen.brandGreen,
    ),
    _StatusFilter(
      label: "Доставлены",
      value: "completed",
      color: Color(0xFF1A7A3C),
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
      _initRealtime();
      _scrollController.addListener(_onScroll);
      final auth = context.read<AuthProvider>();
      if (auth.userId.isNotEmpty && auth.role == 'courier') {
        context.read<LevelProvider>().loadForUser(auth.userId).then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    final auth = context.read<AuthProvider>();
    final bool isShop = auth.role == 'shop';

    try {
      final more = await _orderService.getOrders(
        role: auth.role,
        userId: auth.userId,
        myOrdersOnly: isShop ? true : _selectedFilterIndex == 1,
        offset: _httpOffset,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          // Добавляем только те которых ещё нет (по id)
          for (final o in more) {
            final id = o['id'].toString();
            final exists = _orders.any((e) => e['id'].toString() == id);
            if (!exists) _orders.add(o);
          }
          _httpOffset += more.length;
          _hasMore = more.length == _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _realtimeService.disconnect();
    _scrollController.dispose();

    super.dispose();
  }

  // ── Инициализация WebSocket ────────────────────────────────────────────────
  void _initRealtime() {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) return;

    _setupRealtimeCallbacks();

    final bool isShop = auth.role == 'shop' || auth.role == 'business';
    _realtimeService.connect(
      role: auth.role,
      userId: auth.userId,
      myOrdersOnly: isShop || _selectedFilterIndex == 1,
    );
  }

  void _setupRealtimeCallbacks() {
    _realtimeService.onConnectionChanged = (isConnected) {
      if (mounted) setState(() {});
    };
    // Начальные данные — приходят при подключении (event: init)
    _realtimeService.onOrdersUpdate = (orders) {
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _ordersLoading = false;
        _ordersError = false;
      });
    };

    // Живые события — create / update / delete
    _realtimeService.onOrderEvent = (order, event) {
      if (!mounted) return;
      setState(() {
        final String id = order['id'].toString();
        if (event == 'create') {
          final exists = _orders.any((o) => o['id'].toString() == id);
          if (!exists) _orders.insert(0, order);
        } else if (event == 'update') {
          final idx = _orders.indexWhere((o) => o['id'].toString() == id);
          if (idx != -1) {
            _orders[idx] = order;
          } else {
            _orders.insert(0, order);
          }
        } else if (event == 'delete') {
          _orders.removeWhere((o) => o['id'].toString() == id);
        }
      });
    };
  }

  // ── Переподключение при смене фильтра ─────────────────────────────────────
  Future<void> _reconnectRealtime() async {
    await _realtimeService.disconnect();
    setState(() {
      _orders = [];
      _ordersLoading = true;
      _ordersError = false;
    });

    _setupRealtimeCallbacks();

    final auth = context.read<AuthProvider>();
    final bool isShop = auth.role == 'shop' || auth.role == 'business';
    await _realtimeService.connect(
      role: auth.role,
      userId: auth.userId,
      myOrdersOnly: isShop || _selectedFilterIndex == 1,
    );
  }

  // ── Pull-to-refresh (HTTP fallback) ───────────────────────────────────────
  Future<void> _handleRefresh() async {
    _httpOffset = 0;
    _hasMore = true;
    await context.read<AuthProvider>().refreshProfile();
    final auth = context.read<AuthProvider>();
    if (auth.userId.isNotEmpty && auth.role == 'courier') {
      await context.read<LevelProvider>().loadForUser(auth.userId);
    }
    try {
      final bool isShop = auth.role == 'shop' || auth.role == 'business';
      final orders = await _orderService.getOrders(
        role: auth.role,
        userId: auth.userId,
        myOrdersOnly: isShop ? true : _selectedFilterIndex == 1,
      );
      if (mounted) {
        setState(() {
          _orders = orders;
          _ordersLoading = false;
          _ordersError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _ordersError = true);
    }
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
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F5EE), Color(0xFFFFF0EE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                    color: HomeScreen.brandGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (b) => HomeScreen.brandGradient.createShader(b),
              child: Text(
                '🎁 Подарок за первый вход!',
                style: AppText.extraBold(fontSize: 20, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Мы начислили вам',
              style: AppText.regular(fontSize: 15, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: HomeScreen.brandGreen.withOpacity(0.2),
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
                      color: HomeScreen.brandGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '3 жетона',
                    style: AppText.extraBold(
                      fontSize: 28,
                      color: HomeScreen.brandGreen,
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: HomeScreen.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
            ),
          ],
        ),
      ),
    ).then((_) => _handleRefresh());
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

    final List<dynamic> filteredOrders = _filterByStatus(_orders);

    return Consumer<LevelProvider>(
      builder: (context, levelProvider, child) {
        if (isCourier && levelProvider.pendingLevelUp != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLevelUpOnHomeScreen(context, levelProvider);
          });
        }
        return child!;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: _buildLogoRow(authProv),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
          ),
          actions: [
            _AppBarIcon(
              icon: Icons.notifications_active_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                '/notifications',
              ).then((_) => _handleRefresh()),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _AppBarIcon(
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/profile',
                ).then((_) => _handleRefresh()),
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
                    child: _GradientText(
                      text: isShop ? 'Мои заказы' : 'Доступные заказы',
                      style: AppText.semiBold(
                        fontSize: 20,
                        color: Colors.black,
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
                child: _buildOrdersList(
                  filteredOrders,
                  isShop,
                  authProv,
                  words,
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
      ),
    );
  }

  // ── Список (заменяет FutureBuilder) ───────────────────────────────────────
  Widget _buildOrdersList(
    List<dynamic> orders,
    bool isShop,
    AuthProvider authProv,
    dynamic words,
  ) {
    if (_ordersLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: HomeScreen.brandGreen,
          strokeWidth: 2,
        ),
      );
    }
    if (_ordersError) {
      return _buildEmptyState(
        icon: Icons.wifi_off_rounded,
        text: 'Ошибка загрузки. Потяните вниз.',
      );
    }
    if (orders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox_rounded,
        text: isShop ? 'У вас пока нет заказов' : words.emptyList,
      );
    }
    return ListView.builder(
      controller: _scrollController, // 👈
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: orders.length + 1, // 👈 +1 для футера
      itemBuilder: (context, index) {
        // Футер — индикатор загрузки или конец списка
        if (index == orders.length) {
          // 👈
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: HomeScreen.brandGreen,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          if (!_hasMore && orders.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Все заказы загружены',
                  style: AppText.regular(
                    fontSize: 12,
                    color: const Color(0xFF9AA3AF),
                  ),
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
          ).then((_) => _handleRefresh()),
        );
      },
    );
  }

  // ── Logo row ───────────────────────────────────────────────────────────────
  Widget _buildLogoRow(AuthProvider authProv) {
    final bool isShop = authProv.role == 'shop' || authProv.role == 'business';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          _realtimeService.isConnected
              ? 'assets/images/bagla_logo.png'
              : 'assets/images/bagla_logo_gray.png',
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const BaglaLogo(width: 48, height: 24),
        ),
        const SizedBox(width: 8),
        if (isShop)
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => WalletInfoModal(balance: authProv.walletBalance),
            ).then((_) => _handleRefresh()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: HomeScreen.brandGreen.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                    color: HomeScreen.brandGreen,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${authProv.walletBalance.toStringAsFixed(2)} TMT',
                    style: AppText.semiBold(
                      fontSize: 13,
                      color: HomeScreen.brandGreen,
                    ),
                  ),
                ],
              ),
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
            ).then((_) => _handleRefresh()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: HomeScreen.brandGreen.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/point_icon.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.toll_rounded,
                      size: 20,
                      color: HomeScreen.brandGreen,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    authProv.balancePoints.toDouble().toStringAsFixed(2),
                    style: AppText.semiBold(
                      fontSize: 15,
                      color: HomeScreen.brandGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showLevelUpOnHomeScreen(BuildContext context, LevelProvider provider) {
    final pending = provider.pendingLevelUp;
    if (pending == null) return;
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black54,
            pageBuilder: (_, __, ___) => _LevelUpOverlay(
              provider: provider,
              onDismiss: () {
                provider.dismissLevelUp(pending.id);
                Navigator.of(context).pop();
              },
            ),
          ),
        )
        .then((_) => _handleRefresh());
  }

  Widget _buildSegmentedFilter() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Row(
        children: [
          _filterItem(0, 'Доступные заказы'),
          _filterItem(1, 'Мои заказы'),
        ],
      ),
    );
  }

  Widget _filterItem(int index, String label) {
    final bool sel = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedFilterIndex == index) return;
          setState(() {
            _selectedFilterIndex = index;
            _ordersLoading = true;
          });
          _reconnectRealtime(); // переподключаем WS с новым фильтром
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: sel ? HomeScreen.brandGradient : null,
            color: sel ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppText.medium(
              fontSize: 13,
              color: sel ? Colors.white : const Color(0xFF9AA3AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: _statusFilters.map((f) {
          final bool sel = _selectedStatus == f.value;
          return GestureDetector(
            onTap: () => setState(() => _selectedStatus = f.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? f.color.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? f.color.withOpacity(0.4)
                      : const Color(0xFFEEF0F3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sel) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: f.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    f.label,
                    style: sel
                        ? AppText.semiBold(fontSize: 12, color: f.color)
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

  Widget _buildStatusBanner(bool isBanned) {
    final Color color = isBanned
        ? HomeScreen.brandRed
        : const Color(0xFFE67E22);
    final Color bgColor = isBanned
        ? const Color(0xFFFFF0EE)
        : const Color(0xFFFFF8EE);
    final IconData icon = isBanned
        ? Icons.block_rounded
        : Icons.access_time_rounded;
    final String text = isBanned
        ? 'Аккаунт заблокирован'
        : 'Ожидание проверки модератора';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
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
      ).then((_) => _handleRefresh()),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: HomeScreen.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: HomeScreen.brandGreen.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Создать заказ',
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

  Widget _buildEmptyState({required IconData icon, required String text}) {
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
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            child: Icon(
              icon,
              size: 32,
              color: HomeScreen.brandGreen.withOpacity(0.25),
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: HomeScreen.brandGreen.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HomeScreen.brandGreen.withOpacity(0.12)),
        ),
        child: Icon(icon, color: HomeScreen.brandGreen, size: 19),
      ),
    );
  }
}

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _GradientText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => HomeScreen.brandGradient.createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

class _LevelUpOverlay extends StatelessWidget {
  final LevelProvider provider;
  final VoidCallback onDismiss;
  const _LevelUpOverlay({required this.provider, required this.onDismiss});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
