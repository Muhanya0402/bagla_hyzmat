import 'package:bagla/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bagla/models/district.dart';
import 'package:bagla/models/etrap.dart';
import 'package:bagla/features/home/widgets/courier_filter_modal.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/notifications/unread_notifications_modal.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/providers/level_provider.dart';
import 'package:bagla/services/order_realtime_service.dart';
import 'package:bagla/services/order_service.dart';
import 'package:bagla/features/auth/auth_repository.dart';

mixin HomeScreenController<T extends StatefulWidget> on State<T> {
  int selectedFilterIndex = 0;
  String? selectedStatus;

  String provinceId = '';
  String provinceLabel = '';
  String etrapId = '';
  String etrapLabel = '';

  Etrap? selectedEtrap;
  District? selectedDistrict;
  List<District> districts = [];
  bool loadingDistricts = false;

  CourierFilters filters = const CourierFilters();
  final classifierCache = ClassifierCache();

  final authRepo = AuthRepository();
  final orderService = OrderService();
  final realtimeService = OrderRealtimeService();

  List<dynamic> orders = [];
  bool ordersLoading = true;
  bool ordersError = false;
  int httpOffset = 0;
  bool hasMore = true;
  bool loadingMore = false;
  static const int pageSize = 6;
  final scrollController = ScrollController();

  int activeOrdersCount = 0;
  void initController() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initLocationFilter();

      // 1. Принудительно запускаем лоадер и загружаем данные по HTTP
      if (mounted) {
        setState(() => ordersLoading = true);
      }
      await handleRefresh(); // Этот метод сделает HTTP запрос и наполнит список

      // 2. Только после первичной загрузки подключаем веб-сокеты
      initRealtime();

      scrollController.addListener(onScroll);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.userId.isNotEmpty && auth.role == 'courier') {
        context.read<LevelProvider>().loadForUser(auth.userId).then((_) {
          if (mounted) setState(() {});
        });
        loadActiveOrdersCount(auth.userId);
      }
      await checkUnreadNotifications();
    });
  }

  Future<void> changeFilterIndex(int index) async {
    if (selectedFilterIndex == index) {
      return; // Если нажали на ту же вкладку — ничего не делаем
    }

    setState(() {
      selectedFilterIndex = index;
      ordersLoading =
          true; // Показываем красивый лоадер, пока грузятся новые данные
      orders = []; // Очищаем старые заказы, чтобы списки не смешивались
      httpOffset = 0;
      hasMore = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      final isShop = auth.role == 'shop';
      final myOrdersOnlyParam = isShop ? true : index == 1;

      // 1. Скачиваем актуальные заказы для выбранной вкладки по HTTP
      final fetchedOrders = await orderService.getOrders(
        role: auth.role,
        userId: auth.userId,
        myOrdersOnly: myOrdersOnlyParam,
      );

      if (mounted) {
        setState(() {
          orders = fetchedOrders;
          ordersLoading = false;
          ordersError = false;
          httpOffset = fetchedOrders.length;
        });
      }

      // 2. Переподключаем веб-сокеты на нужный тип заказов (Все или Только мои)
      debugPrint(
        '🔌 WS: Переподключение из-за смены вкладки на индекс $index (myOrdersOnly: $myOrdersOnlyParam)',
      );
      realtimeService.connect(
        role: auth.role,
        userId: auth.userId,
        myOrdersOnly: myOrdersOnlyParam,
      );
    } catch (e) {
      debugPrint('Ошибка при смене вкладки: $e');
      if (mounted) {
        setState(() {
          ordersLoading = false;
          ordersError = true;
        });
      }
    }
  }

  void disposeController() {
    realtimeService.disconnect();
    scrollController.dispose();
  }

  Future<void> loadActiveOrdersCount(String userId) async {
    final count = await orderService.getActiveOrdersCount(userId);
    if (mounted) setState(() => activeOrdersCount = count);
  }

  Future<void> checkUnreadNotifications() async {
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

  Future<void> initLocationFilter() async {
    final auth = context.read<AuthProvider>();
    if (auth.role != 'courier') return;

    final isRu = context.read<LanguageProvider>().isRu;
    final prefs = await SharedPreferences.getInstance();

    provinceId = prefs.getString('province_id') ?? '';
    provinceLabel = prefs.getString(isRu ? 'province_ru' : 'province_tk') ?? '';
    etrapId = prefs.getString('etrap_id') ?? '';
    etrapLabel = prefs.getString(isRu ? 'etrap_ru' : 'etrap_tk') ?? '';

    final savedTransport = prefs.getString('transport_type') ?? 'any';
    filters = filters.copyWith(transportFilter: savedTransport);

    if (etrapId.isNotEmpty) {
      selectedEtrap = Etrap(
        id: etrapId,
        ru: prefs.getString('etrap_ru') ?? '',
        tk: prefs.getString('etrap_tk') ?? '',
        provinceId: provinceId,
      );
      loadDistricts(etrapId, silent: true);
    }
    selectedDistrict = null;
    if (mounted) setState(() {});
  }

  Future<void> loadDistricts(String etrapId, {bool silent = false}) async {
    if (!silent) setState(() => loadingDistricts = true);
    try {
      final list = await authRepo.getDistrictsByEtrap(etrapId);
      if (mounted) setState(() => districts = list);
    } catch (e) {
      debugPrint('_loadDistricts error: $e');
    } finally {
      if (mounted && !silent) setState(() => loadingDistricts = false);
    }
  }

  List<CourierFilterItem> buildShopItems() {
    final seen = <String>{};
    final result = <CourierFilterItem>[];
    for (final o in orders) {
      final phone = (o['shop_phone'] ?? '').toString().trim();
      if (phone.isEmpty || !seen.add(phone)) continue;

      final name = (o['shop_name'] ?? o['shop_title'] ?? '').toString().trim();
      final label = name.isNotEmpty ? '$name ($phone)' : phone;

      result.add(CourierFilterItem(id: phone, label: label));
    }
    result.sort((a, b) => a.label.compareTo(b.label));
    return result;
  }

  List<dynamic> applyFilters(List<dynamic> targetOrders) {
    var r = targetOrders;

    if (selectedStatus != null) {
      r = r
          .where(
            (o) =>
                (o['order_status'] ?? '').toString().toLowerCase() ==
                selectedStatus,
          )
          .toList();
    }

    final role = context.read<AuthProvider>().role;

    if (role == 'courier' && selectedEtrap != null) {
      r = r.where((o) {
        final e = o['etrap'];
        return e is Map && e['id']?.toString() == selectedEtrap!.id;
      }).toList();
    }
    if (role == 'courier' && selectedDistrict != null) {
      r = r.where((o) {
        final d = o['district'];
        return d is Map && d['id']?.toString() == selectedDistrict!.id;
      }).toList();
    }

    if (role == 'courier') {
      if (filters.transportFilter != 'any') {
        r = r.where((o) {
          final t = o['transport_type']?.toString() ?? '';
          return t.isEmpty || t == 'any' || t == filters.transportFilter;
        }).toList();
      }

      if (filters.shopProvince != null) {
        r = r.where((o) {
          final p = o['shop_province'];
          return p is Map && p['id']?.toString() == filters.shopProvince!.id;
        }).toList();
      }
      if (filters.shopEtrap != null) {
        r = r.where((o) {
          final e = o['shop_etrap'];
          return e is Map && e['id']?.toString() == filters.shopEtrap!.id;
        }).toList();
      }
      if (filters.shopDistrict != null) {
        r = r.where((o) {
          final d = o['shop_district'];
          return d is Map && d['id']?.toString() == filters.shopDistrict!.id;
        }).toList();
      }

      if (filters.deliveryProvince != null) {
        r = r.where((o) {
          final p = o['province'];
          return p is Map &&
              p['id']?.toString() == filters.deliveryProvince!.id;
        }).toList();
      }
      if (filters.deliveryEtrap != null) {
        r = r.where((o) {
          final e = o['etrap'];
          return e is Map && e['id']?.toString() == filters.deliveryEtrap!.id;
        }).toList();
      }
      if (filters.deliveryDistrict != null) {
        r = r.where((o) {
          final d = o['district'];
          return d is Map &&
              d['id']?.toString() == filters.deliveryDistrict!.id;
        }).toList();
      }

      if (filters.shop != null) {
        r = r
            .where(
              (o) =>
                  (o['shop_phone'] ?? '').toString().trim() == filters.shop!.id,
            )
            .toList();
      }
    }

    return r;
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;

    setState(() => loadingMore = true);

    final auth = context.read<AuthProvider>();
    final isShop = auth.role == 'shop' || auth.role == 'business';

    try {
      // Корректный offset — это текущее количество элементов.
      // Если сокет добавил новые элементы сверху, httpOffset должен это учитывать.
      final currentOffset = orders.length;

      final more = await orderService.getOrders(
        role: auth.role,
        userId: auth.userId,
        myOrdersOnly: isShop ? true : selectedFilterIndex == 1,
        offset:
            currentOffset, // Используем динамический offset вместо жесткого httpOffset
        limit: pageSize,
      );

      if (mounted) {
        setState(() {
          if (more.isEmpty) {
            hasMore = false;
          } else {
            for (final o in more) {
              final id = o['id'].toString();
              // Защита от дубликатов: добавляем только если сокет или предыдущий запрос его не добавил
              if (!orders.any((e) => e['id'].toString() == id)) {
                orders.add(o);
              }
            }
            // Если пришло меньше, чем размер страницы, значит данные на бэкенде кончились
            hasMore = more.length == pageSize;
          }
          loadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке старых заказов (loadMore): $e');
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  void initRealtime() {
    final auth = context.read<AuthProvider>();

    // Если на старте ID пустой, мы увидим это в консоли
    if (auth.userId.isEmpty) {
      debugPrint(
        '⚠️ HomeScreenController: Инициализация сокетов отменена, userId пуст!',
      );
      return;
    }

    setupRealtimeCallbacks();
    final isShop = auth.role == 'shop' || auth.role == 'business';

    debugPrint(
      '🔌 HomeScreenController: Подключение к сокетам для пользователя ${auth.userId}',
    );
    realtimeService.connect(
      role: auth.role,
      userId: auth.userId,
      myOrdersOnly: isShop || selectedFilterIndex == 1,
    );
  }

  void setupRealtimeCallbacks() {
    realtimeService.onConnectionChanged = (_) {
      if (mounted) setState(() {});
    };

    // Оставляем пустым, так как за первичные данные теперь отвечает HTTP-клиент
    realtimeService.onOrdersUpdate = null;

    realtimeService.onOrderEvent = (order, event) {
      if (!mounted) return;

      setState(() {
        final id = order['id'].toString();

        if (event == 'create') {
          if (!orders.any((o) => o['id'].toString() == id)) {
            orders.insert(0, order);
          }
        } else if (event == 'update') {
          final idx = orders.indexWhere((o) => o['id'].toString() == id);
          if (idx != -1) {
            orders[idx] = order;
          } else {
            // Если заказа не было в списке, но он обновился под наши критерии — добавляем вверх
            orders.insert(0, order);
          }

          final auth = context.read<AuthProvider>();
          if (auth.role == 'courier') {
            loadActiveOrdersCount(auth.userId);
          }
        } else if (event == 'delete') {
          orders.removeWhere((o) => o['id'].toString() == id);
        }
      });

      // Переприменяем локальные фильтры (по велаятам/этрапам),
      // чтобы новый или обновленный сокет-заказ сразу правильно отфильтровался на экране
      applyFilters(orders);
    };
  }

  Future<void> reconnectRealtime() async {
    await realtimeService.disconnect();
    setState(() {
      orders = [];
      ordersLoading = true;
      ordersError = false;
      httpOffset = 0;
      hasMore = true;
    });
    setupRealtimeCallbacks();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final isShop = auth.role == 'shop';
    await realtimeService.connect(
      role: auth.role,
      userId: auth.userId,
      myOrdersOnly: isShop || selectedFilterIndex == 1,
    );
  }

  Future<void> handleRefresh() async {
    httpOffset = 0;
    hasMore = true;
    await context.read<AuthProvider>().refreshProfile();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.userId.isNotEmpty && auth.role == 'courier') {
      await context.read<LevelProvider>().loadForUser(auth.userId);
      loadActiveOrdersCount(auth.userId);
    }
    try {
      final isShop = auth.role == 'shop';
      final fetchedOrders = await orderService.getOrders(
        role: auth.role,
        userId: auth.userId,
        myOrdersOnly: isShop ? true : selectedFilterIndex == 1,
      );
      if (mounted) {
        setState(() {
          orders = fetchedOrders;
          ordersLoading = false;
          ordersError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => ordersError = true);
    }
  }

  void showFilterModal() {
    final isRu = context.read<LanguageProvider>().isRu;

    final defaultProvince = provinceId.isNotEmpty
        ? CourierFilterItem(id: provinceId, label: provinceLabel)
        : null;
    final defaultEtrap = etrapId.isNotEmpty
        ? CourierFilterItem(id: etrapId, label: etrapLabel)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => CourierFilterModal(
        initial: filters,
        isRu: isRu,
        cache: classifierCache,
        authRepo: authRepo,
        shopItems: buildShopItems(),
        defaultProvince: defaultProvince,
        defaultEtrap: defaultEtrap,
        onApply: (newFilters) {
          setState(() => filters = newFilters);
          Navigator.pop(modalCtx);
        },
        onClear: () {
          setState(() => filters = const CourierFilters());
          Navigator.pop(modalCtx);
        },
      ),
    );
  }
}
