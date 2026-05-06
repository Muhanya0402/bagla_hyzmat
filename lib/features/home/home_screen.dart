import 'package:bagla/core/api_client.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/notifications/unread_notifications_modal.dart';
import 'package:bagla/features/orders/create_order_screen.dart';
import 'package:bagla/features/home/home_app_bar.dart';
import 'package:bagla/features/home/location_filter.dart';
import 'package:bagla/features/home/widgets/wallet_info_modal.dart';
import 'package:bagla/features/orders/order_card.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:bagla/features/profile/top_up_modal.dart';
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
  // ── Фильтры статуса ───────────────────────────────────────────────────────
  int _selectedFilterIndex = 0;
  String? _selectedStatus;

  // ── Фильтр локации ────────────────────────────────────────────────────────
  String _provinceLabel = '';
  Etrap? _selectedEtrap;
  District? _selectedDistrict;
  List<Etrap> _etraps = [];
  List<District> _districts = [];
  bool _loadingEtraps = false;
  bool _loadingDistricts = false;
  String _provinceId = '';

  final AuthRepository _authRepo = AuthRepository();

  // ── Заказы / пагинация ────────────────────────────────────────────────────
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

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkWelcomeBonus();
      await _initLocationFilter(); // читаем из prefs — без запросов
      _initRealtime();
      _scrollController.addListener(_onScroll);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.userId.isNotEmpty && auth.role == 'courier') {
        context.read<LevelProvider>().loadForUser(auth.userId).then((_) {
          if (mounted) setState(() {});
        });
      }
      await _checkUnreadNotifications();
    });
  }

  Future<void> _checkUnreadNotifications() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) return;
    try {
      final service = NotificationService();
      final unread = await service.getUnread(auth.userId);
      if (unread.isEmpty || !mounted) return;

      // Небольшая задержка чтобы UI успел отрисоваться
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UnreadNotificationsModal(
          notifications: unread,
          onMarkAllRead: () async {
            await service.markAllAsRead(auth.userId);
          },
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
  // ЛОКАЦИЯ: читаем из SharedPreferences — без сетевых запросов
  // Данные сохраняются при логине через fetchProfileFromServer
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initLocationFilter() async {
    final auth = context.read<AuthProvider>();
    if (auth.role != 'courier') return;

    final isRu = context.read<LanguageProvider>().isRu;
    final prefs = await SharedPreferences.getInstance();

    _provinceId = prefs.getString('province_id') ?? '';
    _provinceLabel =
        prefs.getString(isRu ? 'province_ru' : 'province_tk') ?? '';

    final etrapId = prefs.getString('etrap_id') ?? '';
    final etrapRu = prefs.getString('etrap_ru') ?? '';
    final etrapTk = prefs.getString('etrap_tk') ?? '';

    final distId = prefs.getString('district_id') ?? '';
    final distRu = prefs.getString('district_ru') ?? '';
    final distTk = prefs.getString('district_tk') ?? '';

    if (etrapId.isNotEmpty) {
      _selectedEtrap = Etrap(
        id: etrapId,
        ru: etrapRu,
        tk: etrapTk,
        provinceId: _provinceId,
      );
      // Тихо грузим список районов для выбранного этрапа (для picker'а)
      _loadDistricts(etrapId, silent: true);
    }

    if (distId.isNotEmpty) {
      _selectedDistrict = District(id: distId, ru: distRu, tk: distTk);
    }

    if (mounted) setState(() {});
  }

  // ── Загрузка этрапов (для picker'а, лениво) ───────────────────────────────
  Future<void> _loadEtraps() async {
    if (_provinceId.isEmpty) return;
    setState(() => _loadingEtraps = true);
    try {
      final list = await _authRepo.getEtrapsByProvince(_provinceId);
      if (mounted) setState(() => _etraps = list);
    } catch (e) {
      debugPrint('_loadEtraps error: $e');
    } finally {
      if (mounted) setState(() => _loadingEtraps = false);
    }
  }

  // ── Загрузка районов для этрапа ───────────────────────────────────────────
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

  Future<void> _onEtrapSelected(Etrap etrap) async {
    setState(() {
      _selectedEtrap = etrap;
      _selectedDistrict = null;
      _districts = [];
    });
    await _loadDistricts(etrap.id);
    _reconnectRealtime();
  }

  void _onDistrictSelected(District district) {
    setState(() => _selectedDistrict = district);
    _reconnectRealtime();
  }

  void _clearDistrictFilter() {
    setState(() => _selectedDistrict = null);
    _reconnectRealtime();
  }

  void _showEtrapPicker() async {
    if (_etraps.isEmpty) await _loadEtraps();
    if (!mounted) return;

    final isRu = context.read<LanguageProvider>().isRu;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LocationPickerSheet(
        title: 'Выберите этрап',
        isLoading: _loadingEtraps,
        items: _etraps
            .map((e) => _PickerItem(id: e.id, label: e.label(isRu)))
            .toList(),
        selectedId: _selectedEtrap?.id,
        onSelect: (id) {
          Navigator.pop(context);
          final etrap = _etraps.firstWhere((e) => e.id == id);
          _onEtrapSelected(etrap);
        },
      ),
    );
  }

  void _showDistrictPicker() {
    final isRu = context.read<LanguageProvider>().isRu;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LocationPickerSheet(
        title: 'Выберите район',
        isLoading: _loadingDistricts,
        items: _districts
            .map((d) => _PickerItem(id: d.id, label: d.label(isRu)))
            .toList(),
        selectedId: _selectedDistrict?.id,
        onSelect: (id) {
          Navigator.pop(context);
          final dist = _districts.firstWhere((d) => d.id == id);
          _onDistrictSelected(dist);
        },
        onClear: _selectedDistrict != null
            ? () {
                Navigator.pop(context);
                _clearDistrictFilter();
              }
            : null,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ФИЛЬТРАЦИЯ ЗАКАЗОВ
  // ─────────────────────────────────────────────────────────────────────────

  List<dynamic> _applyFilters(List<dynamic> orders) {
    var result = orders;

    if (_selectedStatus != null) {
      result = result
          .where(
            (o) =>
                (o['order_status'] ?? '').toString().toLowerCase() ==
                _selectedStatus,
          )
          .toList();
    }

    final auth = context.read<AuthProvider>();
    if (auth.role == 'courier' && _selectedEtrap != null) {
      result = result.where((o) {
        final etrap = o['etrap'];
        if (etrap == null) return false;
        final etrapId = etrap is Map
            ? etrap['id']?.toString()
            : etrap.toString();
        return etrapId == _selectedEtrap!.id;
      }).toList();
    }

    if (auth.role == 'courier' && _selectedDistrict != null) {
      result = result.where((o) {
        final dist = o['district'];
        if (dist == null) return false;
        final distId = dist is Map ? dist['id']?.toString() : dist.toString();
        return distId == _selectedDistrict!.id;
      }).toList();
    }

    return result;
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
    _realtimeService.onConnectionChanged = (isConnected) {
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
  // WELCOME BONUS
  // ─────────────────────────────────────────────────────────────────────────

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
      debugPrint('welcome bonus error: $e');
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
                  errorBuilder: (_, _, _) => const Icon(
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
                  color: HomeScreen.brandGreen.withValues(alpha: 0.2),
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
                    errorBuilder: (_, _, _) => const Icon(
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

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final isRu = lang.isRu;

    final String currentStatus = authProv.status.toLowerCase().trim();
    final String role = authProv.role.toLowerCase().trim();

    final bool isActive = currentStatus == 'active';
    final bool isShop = role == 'shop' || role == 'business';
    final bool isCourier = role == 'courier';
    final bool isBanned = currentStatus == 'banned';
    final bool isPending = currentStatus == 'pending' && (isCourier || isShop);

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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _GradientText(
                text: isShop ? 'Мои заказы' : 'Доступные заказы',
                style: AppText.semiBold(fontSize: 20, color: Colors.black),
              ),
            ),

            // Фильтр локации — только если провинция загружена из prefs
            if (isCourier && _provinceLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
                child: _buildLocationFilter(isRu),
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
                  child: _buildCreateButton(context),
                ),
              )
            : null,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ВИДЖЕТ ФИЛЬТРА ЛОКАЦИИ
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLocationFilter(bool isRu) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          LocationChip(
            icon: Icons.map_outlined,
            label: _provinceLabel,
            isFixed: true,
          ),
          const SizedBox(width: 6),
          LocationChip(
            icon: Icons.location_city_outlined,
            label: _selectedEtrap != null
                ? _selectedEtrap!.label(isRu)
                : 'Этрап',
            isActive: _selectedEtrap != null,
            onTap: _showEtrapPicker,
          ),
          const SizedBox(width: 6),
          if (_selectedEtrap != null)
            LocationChip(
              icon: Icons.pin_drop_outlined,
              label: _selectedDistrict != null
                  ? _selectedDistrict!.label(isRu)
                  : 'Район',
              isActive: _selectedDistrict != null,
              onTap: _districts.isEmpty && !_loadingDistricts
                  ? null
                  : _showDistrictPicker,
              isLoading: _loadingDistricts,
              onClear: _selectedDistrict != null ? _clearDistrictFilter : null,
            ),
        ],
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
            ).then((_) => _handleRefresh()),
            child: _balanceChip(
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

  Widget _balanceChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: HomeScreen.brandGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: HomeScreen.brandGreen),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.semiBold(fontSize: 13, color: HomeScreen.brandGreen),
          ),
        ],
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

  void _showLevelUpOnHomeScreen(BuildContext context, LevelProvider provider) {
    final pending = provider.pendingLevelUp;
    if (pending == null) return;
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black54,
            pageBuilder: (_, _, _) => _LevelUpOverlay(
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
}

// ─────────────────────────────────────────────────────────────────────────────
// _LocationPickerSheet
// ─────────────────────────────────────────────────────────────────────────────

class _PickerItem {
  final String id;
  final String label;
  const _PickerItem({required this.id, required this.label});
}

class _LocationPickerSheet extends StatefulWidget {
  final String title;
  final bool isLoading;
  final List<_PickerItem> items;
  final String? selectedId;
  final void Function(String id) onSelect;
  final VoidCallback? onClear;

  const _LocationPickerSheet({
    required this.title,
    required this.isLoading,
    required this.items,
    required this.onSelect,
    this.selectedId,
    this.onClear,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((i) => i.label.toLowerCase().contains(_q))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, sc) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0F3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: AppText.bold(
                    fontSize: 16,
                    color: const Color(0xFF0F1117),
                  ),
                ),
                const Spacer(),
                if (widget.onClear != null)
                  GestureDetector(
                    onTap: widget.onClear,
                    child: Text(
                      'Сбросить',
                      style: AppText.medium(
                        fontSize: 13,
                        color: HomeScreen.brandRed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
              style: AppText.regular(
                fontSize: 14,
                color: const Color(0xFF0F1117),
              ),
              decoration: InputDecoration(
                hintText: 'Поиск...',
                hintStyle: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF9AA3AF),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF9AA3AF),
                  size: 20,
                ),
                suffixIcon: _q.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _q = '');
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF9AA3AF),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFEEF0F3)),
          Expanded(
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: HomeScreen.brandGreen,
                      strokeWidth: 2,
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      'Ничего не найдено',
                      style: AppText.regular(
                        fontSize: 14,
                        color: const Color(0xFF9AA3AF),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 52,
                      color: Color(0xFFF4F5F7),
                    ),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final isActive = item.id == widget.selectedId;
                      return InkWell(
                        onTap: () => widget.onSelect(item.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? HomeScreen.brandGreen.withValues(
                                          alpha: 0.08,
                                        )
                                      : const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.check_rounded
                                      : Icons.location_on_outlined,
                                  size: 16,
                                  color: isActive
                                      ? HomeScreen.brandGreen
                                      : const Color(0xFF9AA3AF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: isActive
                                      ? AppText.semiBold(
                                          fontSize: 14,
                                          color: const Color(0xFF0F1117),
                                        )
                                      : AppText.regular(
                                          fontSize: 14,
                                          color: const Color(0xFF0F1117),
                                        ),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: HomeScreen.brandGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _GradientText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (b) => HomeScreen.brandGradient.createShader(b),
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
