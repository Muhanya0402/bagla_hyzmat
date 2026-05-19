import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/courier_filter_modal.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/notifications/unread_notifications_modal.dart';
import 'package:bagla/features/orders/create_order_screen.dart';
import 'package:bagla/features/home/home_app_bar.dart';
import 'package:bagla/features/orders/order_card.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/models/district.dart';
import 'package:bagla/models/etrap.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/providers/level_provider.dart';
import 'package:bagla/services/order_realtime_service.dart';
import 'package:bagla/services/order_service.dart';
import 'package:bagla/features/auth/phone_screen.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // ── Сегментный фильтр ─────────────────────────────────────────────────────
  int _selectedFilterIndex = 0;
  String? _selectedStatus;

  // ── Локация курьера (сохранённая из профиля) ──────────────────────────────
  String _provinceId = '';
  String _provinceLabel = '';
  String _etrapId = '';
  String _etrapLabel = '';

  Etrap? _selectedEtrap;
  District? _selectedDistrict;
  List<District> _districts = [];
  bool _loadingEtraps = false;
  bool _loadingDistricts = false;

  // ── Фильтры ───────────────────────────────────────────────────────────────
  CourierFilters _filters = const CourierFilters();
  final _cache = ClassifierCache();

  final AuthRepository _authRepo = AuthRepository();
  final OrderService _orderService = OrderService();
  final OrderRealtimeService _realtimeService = OrderRealtimeService();

  List<dynamic> _orders = [];
  bool _ordersLoading = true;
  bool _ordersError = false;
  int _httpOffset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  static const int _pageSize = 6;
  final ScrollController _scrollController = ScrollController();

  int _activeOrdersCount = 0;
  static const int _maxActiveOrders = 3;

  static const List<_StatusFilter> _statusFilters = [
    _StatusFilter(label: 'Все', value: null, color: Color(0xFF9AA3AF)),
    _StatusFilter(
      label: 'Свободные',
      value: 'published',
      color: HomeScreen.brandRed,
    ),
    _StatusFilter(
      label: 'В работе',
      value: 'active',
      color: HomeScreen.brandGreen,
    ),
    _StatusFilter(
      label: 'Доставлены',
      value: 'completed',
      color: Color(0xFF1A7A3C),
    ),
    _StatusFilter(
      label: 'Отменены',
      value: 'canceled',
      color: Color(0xFF9AA3AF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initLocationFilter();
      _initRealtime();
      _scrollController.addListener(_onScroll);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.userId.isNotEmpty && auth.role == 'courier') {
        context.read<LevelProvider>().loadForUser(auth.userId).then((_) {
          if (mounted) setState(() {});
        });
        _loadActiveOrdersCount(auth.userId);
      }
      await _checkUnreadNotifications();
    });
  }

  Future<void> _loadActiveOrdersCount(String userId) async {
    final count = await _orderService.getActiveOrdersCount(userId);
    if (mounted) setState(() => _activeOrdersCount = count);
  }

  Future<void> _checkUnreadNotifications() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) return;
    try {
      final service = NotificationService();
      final unread = await service.getUnread(auth.userId);
      if (unread.isEmpty || !mounted) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UnreadNotificationsModal(
          notifications: unread,
          onMarkAllRead: () async => service.markAllAsRead(auth.userId),
        ),
      );
    } catch (e) {
      debugPrint('checkUnreadNotifications error: $e');
    }
  }

  @override
  void dispose() {
    _realtimeService.disconnect();
    _scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ЛОКАЦИЯ
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initLocationFilter() async {
    final auth = context.read<AuthProvider>();
    if (auth.role != 'courier') return;

    final isRu = context.read<LanguageProvider>().isRu;
    final prefs = await SharedPreferences.getInstance();

    _provinceId = prefs.getString('province_id') ?? '';
    _provinceLabel =
        prefs.getString(isRu ? 'province_ru' : 'province_tk') ?? '';
    _etrapId = prefs.getString('etrap_id') ?? '';
    _etrapLabel = prefs.getString(isRu ? 'etrap_ru' : 'etrap_tk') ?? '';

    final savedTransport = prefs.getString('transport_type') ?? 'any';
    _filters = _filters.copyWith(transportFilter: savedTransport);

    if (_etrapId.isNotEmpty) {
      _selectedEtrap = Etrap(
        id: _etrapId,
        ru: prefs.getString('etrap_ru') ?? '',
        tk: prefs.getString('etrap_tk') ?? '',
        provinceId: _provinceId,
      );
      _loadDistricts(_etrapId, silent: true);
    }
    _selectedDistrict = null;
    if (mounted) setState(() {});
  }

  Future<void> _loadDistricts(String etrapId, {bool silent = false}) async {
    if (!silent) setState(() => _loadingDistricts = true);
    try {
      final list = await _authRepo.getDistrictsByEtrap(etrapId);
      if (mounted) setState(() => _districts = list);
    } catch (e) {
      debugPrint('_loadDistricts error: $e');
    } finally {
      if (mounted && !silent) setState(() => _loadingDistricts = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ЗАДАЧА 3: список заказчиков с именем
  // id = shop_phone, label = "Имя (телефон)" или просто телефон
  // ─────────────────────────────────────────────────────────────────────────

  List<CourierFilterItem> _buildShopItems() {
    // Собираем уникальных заказчиков.
    // В заказе может быть поле shop_name (имя магазина) — используем его если есть.
    final seen = <String>{};
    final result = <CourierFilterItem>[];
    for (final o in _orders) {
      final phone = (o['shop_phone'] ?? '').toString().trim();
      if (phone.isEmpty || !seen.add(phone)) continue;

      // ЗАДАЧА 3: имя берём из shop_name или из данных shopId
      final name = (o['shop_name'] ?? o['shop_title'] ?? '').toString().trim();
      final label = name.isNotEmpty ? '$name ($phone)' : phone;

      result.add(CourierFilterItem(id: phone, label: label));
    }
    result.sort((a, b) => a.label.compareTo(b.label));
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ФИЛЬТРАЦИЯ ЗАКАЗОВ
  // ─────────────────────────────────────────────────────────────────────────

  List<dynamic> _applyFilters(List<dynamic> orders) {
    var r = orders;

    if (_selectedStatus != null) {
      r = r
          .where(
            (o) =>
                (o['order_status'] ?? '').toString().toLowerCase() ==
                _selectedStatus,
          )
          .toList();
    }

    final role = context.read<AuthProvider>().role;

    if (role == 'courier' && _selectedEtrap != null) {
      r = r.where((o) {
        final e = o['etrap'];
        return e is Map && e['id']?.toString() == _selectedEtrap!.id;
      }).toList();
    }
    if (role == 'courier' && _selectedDistrict != null) {
      r = r.where((o) {
        final d = o['district'];
        return d is Map && d['id']?.toString() == _selectedDistrict!.id;
      }).toList();
    }

    if (role == 'courier') {
      if (_filters.transportFilter != 'any') {
        r = r.where((o) {
          final t = o['transport_type']?.toString() ?? '';
          return t.isEmpty || t == 'any' || t == _filters.transportFilter;
        }).toList();
      }

      if (_filters.shopProvince != null) {
        r = r.where((o) {
          final p = o['shop_province'];
          return p is Map && p['id']?.toString() == _filters.shopProvince!.id;
        }).toList();
      }
      if (_filters.shopEtrap != null) {
        r = r.where((o) {
          final e = o['shop_etrap'];
          return e is Map && e['id']?.toString() == _filters.shopEtrap!.id;
        }).toList();
      }
      if (_filters.shopDistrict != null) {
        r = r.where((o) {
          final d = o['shop_district'];
          return d is Map && d['id']?.toString() == _filters.shopDistrict!.id;
        }).toList();
      }

      if (_filters.deliveryProvince != null) {
        r = r.where((o) {
          final p = o['province'];
          return p is Map &&
              p['id']?.toString() == _filters.deliveryProvince!.id;
        }).toList();
      }
      if (_filters.deliveryEtrap != null) {
        r = r.where((o) {
          final e = o['etrap'];
          return e is Map && e['id']?.toString() == _filters.deliveryEtrap!.id;
        }).toList();
      }
      if (_filters.deliveryDistrict != null) {
        r = r.where((o) {
          final d = o['district'];
          return d is Map &&
              d['id']?.toString() == _filters.deliveryDistrict!.id;
        }).toList();
      }

      // ЗАДАЧА 3: фильтр по shop_phone (id элемента = phone)
      if (_filters.shop != null) {
        r = r
            .where(
              (o) =>
                  (o['shop_phone'] ?? '').toString().trim() ==
                  _filters.shop!.id,
            )
            .toList();
      }
    }

    return r;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ПАГИНАЦИЯ
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final auth = context.read<AuthProvider>();
    final isShop = auth.role == 'shop' || auth.role == 'business';
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
          for (final o in more) {
            final id = o['id'].toString();
            if (!_orders.any((e) => e['id'].toString() == id)) _orders.add(o);
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

  // ─────────────────────────────────────────────────────────────────────────
  // REALTIME
  // ─────────────────────────────────────────────────────────────────────────

  void _initRealtime() {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) return;
    _setupRealtimeCallbacks();
    final isShop = auth.role == 'shop' || auth.role == 'business';
    _realtimeService.connect(
      role: auth.role,
      userId: auth.userId,
      myOrdersOnly: isShop || _selectedFilterIndex == 1,
    );
  }

  void _setupRealtimeCallbacks() {
    _realtimeService.onConnectionChanged = (_) {
      if (mounted) setState(() {});
    };
    _realtimeService.onOrdersUpdate = (orders) {
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _ordersLoading = false;
        _ordersError = false;
      });
    };
    _realtimeService.onOrderEvent = (order, event) {
      if (!mounted) return;
      setState(() {
        final id = order['id'].toString();
        if (event == 'create') {
          if (!_orders.any((o) => o['id'].toString() == id)) {
            _orders.insert(0, order);
          }
        } else if (event == 'update') {
          final idx = _orders.indexWhere((o) => o['id'].toString() == id);
          idx != -1 ? _orders[idx] = order : _orders.insert(0, order);
          final auth = context.read<AuthProvider>();
          if (auth.role == 'courier') _loadActiveOrdersCount(auth.userId);
        } else if (event == 'delete') {
          _orders.removeWhere((o) => o['id'].toString() == id);
        }
      });
    };
  }

  Future<void> _reconnectRealtime() async {
    await _realtimeService.disconnect();
    setState(() {
      _orders = [];
      _ordersLoading = true;
      _ordersError = false;
      _httpOffset = 0;
      _hasMore = true;
    });
    _setupRealtimeCallbacks();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final isShop = auth.role == 'shop' || auth.role == 'business';
    await _realtimeService.connect(
      role: auth.role,
      userId: auth.userId,
      myOrdersOnly: isShop || _selectedFilterIndex == 1,
    );
  }

  Future<void> _handleRefresh() async {
    _httpOffset = 0;
    _hasMore = true;
    await context.read<AuthProvider>().refreshProfile();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.userId.isNotEmpty && auth.role == 'courier') {
      await context.read<LevelProvider>().loadForUser(auth.userId);
      _loadActiveOrdersCount(auth.userId);
    }
    try {
      final isShop = auth.role == 'shop' || auth.role == 'business';
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

  // ─────────────────────────────────────────────────────────────────────────
  // ОТКРЫТИЕ МОДАЛКИ ФИЛЬТРОВ
  // ЗАДАЧА 1: модалка в отдельном файле
  // ЗАДАЧА 2: defaultProvince/defaultEtrap из сохранённых prefs
  // ─────────────────────────────────────────────────────────────────────────

  void _showFilterModal() {
    final isRu = context.read<LanguageProvider>().isRu;

    // ЗАДАЧА 2: дефолт из профиля курьера
    final defaultProvince = _provinceId.isNotEmpty
        ? CourierFilterItem(id: _provinceId, label: _provinceLabel)
        : null;
    final defaultEtrap = _etrapId.isNotEmpty
        ? CourierFilterItem(id: _etrapId, label: _etrapLabel)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => CourierFilterModal(
        initial: _filters,
        isRu: isRu,
        cache: _cache,
        authRepo: _authRepo,
        shopItems: _buildShopItems(),
        defaultProvince: defaultProvince,
        defaultEtrap: defaultEtrap,
        onApply: (newFilters) {
          setState(() => _filters = newFilters);
          Navigator.pop(modalCtx);
        },
        onClear: () {
          setState(() => _filters = const CourierFilters());
          Navigator.pop(modalCtx);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;

    final String currentStatus = authProv.status.toLowerCase().trim();
    final String role = authProv.role.toLowerCase().trim();

    final bool isActive = currentStatus == 'active';
    final bool isShop = role == 'shop' || role == 'business';
    final bool isCourier = role == 'courier';
    final bool isClient = role == 'client';
    final bool isBanned = currentStatus == 'banned';
    final bool isPending = currentStatus == 'pending' && (isCourier || isShop);
    final bool needsRoleSelection = isClient && currentStatus == 'published';

    final List<dynamic> filteredOrders = _applyFilters(_orders);

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
            HomeAppBarIcon(
              icon: Icons.notifications_active_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                '/notifications',
              ).then((_) => _handleRefresh()),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: HomeAppBarIcon(
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
            if (needsRoleSelection)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _RoleSelectionBanner(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/user_type_selection',
                  ).then((_) => _handleRefresh()),
                ),
              ),

            if (isCourier)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildSegmentedFilter(words),
              ),

            if (isBanned || isPending)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildStatusBanner(isBanned),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  _GradientText(
                    text: isShop ? words.myOrders : words.availiblorders,
                    style: AppText.semiBold(fontSize: 20, color: Colors.black),
                  ),
                  const Spacer(),
                  if (isCourier) ...[
                    _FilterButton(
                      activeCount: _filters.activeCount,
                      onTap: _showFilterModal,
                    ),
                    const SizedBox(width: 8),
                    _ActiveOrdersCounter(
                      current: _activeOrdersCount,
                      max: _maxActiveOrders,
                    ),
                  ],
                ],
              ),
            ),

            if (isShop || _selectedFilterIndex == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
                child: _buildStatusFilterRow(),
              ),

            const SizedBox(height: 10),

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
                  child: _buildCreateButton(context, words),
                ),
              )
            : null,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // СПИСОК ЗАКАЗОВ
  // ─────────────────────────────────────────────────────────────────────────

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
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: orders.length + 1,
      itemBuilder: (context, index) {
        if (index == orders.length) {
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

  // ─────────────────────────────────────────────────────────────────────────
  // ПРОЧИЕ ВИДЖЕТЫ
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLogoRow(AuthProvider authProv) {
    final String role = authProv.role.toLowerCase().trim();
    final String status = authProv.status.toLowerCase().trim();
    final bool isClient = role == 'client';
    final bool needsRoleSelection = isClient && status == 'published';
    final bool isCourier = role == 'courier';

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
          errorBuilder: (_, _, _) => const BaglaLogo(width: 48, height: 24),
        ),
        const SizedBox(width: 8),
        if (needsRoleSelection)
          GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              '/user_type_selection',
            ).then((_) => _handleRefresh()),
            child: const SizedBox(),
          )
        else if (isCourier)
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
      ],
    );
  }

  Widget _buildSegmentedFilter(AppLocalizations words) {
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
          _filterItem(0, words.availiblorders),
          _filterItem(1, words.myOrders),
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
          _reconnectRealtime();
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
                color: sel ? f.color.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? f.color.withValues(alpha: 0.4)
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
    final color = isBanned ? HomeScreen.brandRed : const Color(0xFFE67E22);
    final bgColor = isBanned
        ? const Color(0xFFFFF0EE)
        : const Color(0xFFFFF8EE);
    final icon = isBanned ? Icons.block_rounded : Icons.access_time_rounded;
    final text = isBanned
        ? 'Аккаунт заблокирован'
        : 'Ожидание проверки модератора';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
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
              color: color.withValues(alpha: 0.12),
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

  Widget _buildCreateButton(BuildContext context, AppLocalizations words) {
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
              color: HomeScreen.brandGreen.withValues(alpha: 0.25),
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
              words.createOrder,
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
              color: HomeScreen.brandGreen.withValues(alpha: 0.25),
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

  void _showLevelUpOnHomeScreen(BuildContext ctx, LevelProvider provider) {
    final pending = provider.pendingLevelUp;
    if (pending == null) return;
    Navigator.of(ctx)
        .push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black54,
            pageBuilder: (_, _, _) => _LevelUpOverlay(
              provider: provider,
              onDismiss: () {
                provider.dismissLevelUp(pending.id);
                Navigator.of(ctx).pop();
              },
            ),
          ),
        )
        .then((_) => _handleRefresh());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательные виджеты (остаются в home_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const _FilterButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool has = activeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: has
              ? HomeScreen.brandGreen.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: has
                ? HomeScreen.brandGreen.withValues(alpha: 0.35)
                : const Color(0xFFEEF0F3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: has ? HomeScreen.brandGreen : const Color(0xFF9AA3AF),
            ),
            if (has)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: HomeScreen.brandGreen,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelectionBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _RoleSelectionBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F5EE), Color(0xFFFFF0EE)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: HomeScreen.brandGreen.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: HomeScreen.brandGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    words.roleSelectionTitle,
                    style: AppText.bold(
                      fontSize: 14,
                      color: const Color(0xFF0F1117),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    words.roleActionPrompt,
                    style: AppText.regular(
                      fontSize: 12,
                      color: const Color(0xFF9AA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: HomeScreen.brandGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: HomeScreen.brandGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrdersCounter extends StatelessWidget {
  final int current;
  final int max;
  const _ActiveOrdersCounter({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final bool isFull = current >= max;
    final Color c = isFull ? HomeScreen.brandRed : HomeScreen.brandGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined, size: 13, color: c),
          const SizedBox(width: 5),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$current',
                  style: AppText.bold(fontSize: 13, color: c),
                ),
                TextSpan(
                  text: '/$max',
                  style: AppText.regular(
                    fontSize: 13,
                    color: c.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _GradientText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (b) => HomeScreen.brandGradient.createShader(b),
    child: Text(text, style: style.copyWith(color: Colors.white)),
  );
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
