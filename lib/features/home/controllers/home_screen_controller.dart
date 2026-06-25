import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'dart:async';

import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/notifications/active_orders/active_order_snapshot.dart';
import 'package:bagla/features/notifications/active_orders/active_orders_notification.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/orders/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bagla/models/district.dart';
import 'package:bagla/models/etrap.dart';
import 'package:bagla/features/home/widgets/courier_filter_modal.dart';
import 'package:bagla/features/notifications/notification_dto.dart';
import 'package:bagla/features/notifications/notification_service.dart';
import 'package:bagla/features/notifications/unread_notifications_modal.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/features/levels/level_provider.dart';
import 'package:bagla/features/orders/order_realtime_service.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/features/auth/auth_repository.dart';

mixin HomeScreenController<T extends StatefulWidget> on State<T> {
  int selectedFilterIndex = 0;
  String? selectedStatus;

  String provinceId = '';
  String provinceLabel = '';
  String etrapId = '';
  String etrapLabel = '';

  // Двуязычные лейблы для построения default-фильтров (province/etrap)
  // — иначе CourierFilterItem попадал в фильтр с лейблом фиксированного
  // языка, и после смены RU↔TK картинка в модалке оставалась на старом.
  String provinceLabelRu = '';
  String provinceLabelTk = '';
  String etrapLabelRu = '';
  String etrapLabelTk = '';
  bool _filtersEverApplied = false;

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
  bool ordersReloading = false; // true while switching tabs — shows shimmer
  bool ordersError = false;

  /// Монотонный токен загрузки заказов. Каждая инициация загрузки
  /// (`handleRefresh`, `changeFilterIndex`, применение фильтров) увеличивает
  /// его и запоминает свою копию. Ответ применяется к `orders` ТОЛЬКО если
  /// токен всё ещё актуален — иначе это «протухший» ответ предыдущей вкладки.
  ///
  /// Чинит баг: курьер переключается на «Мои заказы» (дефолт «В работе»),
  /// но в фоне ещё не завершился стартовый `handleRefresh` для «Доступные».
  /// Поздний ответ затирал `orders` published-заказами, а `selectedStatus`
  /// уже = 'active' → applyFilters давал пусто. Список появлялся только
  /// после ручного переключения статуса.
  int _ordersReqToken = 0;
  int httpOffset = 0;
  bool hasMore = true;
  bool loadingMore = false;
  static const int pageSize = 6;
  final scrollController = ScrollController();

  int activeOrdersCount = 0;

  /// AppLifecycleListener — современная замена WidgetsBindingObserver
  /// для подписки на resumed/paused. Не требует override'ить весь
  /// интерфейс наблюдателя.
  AppLifecycleListener? _lifecycleListener;

  void initController() {
    // Слушаем resume — это момент когда пользователь возвращается в
    // приложение из background. Здесь применяем pending action из
    // persistent notification (например, «Завершить» нажатый из шторки).
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_drainPendingAction()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initAuth = context.read<AuthProvider>();

      // ⚠️ Дожидаемся загрузки prefs ДО handleRefresh.
      //
      // AuthProvider.loadUserData() вызывается в конструкторе async, без
      // await — на момент первого frame `auth.userId/role` ещё пустые
      // (default 'client'). В таком состоянии handleRefresh видит
      // `isCourier = false` → `LevelProvider.loadForUser` скипается
      // в Future.wait → level-bar пустой.
      //
      // Юзер делает pull-to-refresh → к тому времени auth уже загружен →
      // level загружается. Отсюда баг «уровни не обновляются при входе,
      // надо скроллить сверху вниз».
      //
      // loadUserData идемпотентен (читает те же prefs), повторный вызов
      // безопасен.
      await initAuth.loadUserData();
      if (!mounted) return;

      final initRole = initAuth.role.toLowerCase().trim();
      if (initRole == 'shop' || initRole == 'business') {
        selectedFilterIndex = 1;
      }
      await initLocationFilter();

      // 1. Принудительно запускаем лоадер и загружаем данные по HTTP
      if (mounted) {
        setState(() => ordersLoading = true);
      }
      await handleRefresh(); // Этот метод сделает HTTP запрос и наполнит список

      // 2. WebSocket connect — параллельно (не ждём handleRefresh).
      initRealtime();

      scrollController.addListener(onScroll);
      if (!mounted) return;
      // LevelProvider + active count теперь в Future.wait внутри handleRefresh —
      // отдельные вызовы больше не нужны.
      // checkUnreadNotifications — асинхронно, не блокирует UI стартом.
      unawaited(checkUnreadNotifications());

      // Cold-start: экшен из шторки («Завершить») записан в prefs ещё на
      // этапе initialize — вычитываем его теперь, когда home готов.
      unawaited(_drainPendingAction());
    });
  }

  bool _drainingPending = false;

  /// Дренаж pending action с повтором. Кнопка `Default` выводит app на
  /// передний план (срабатывает onResume) часто РАНЬШЕ, чем хэндлер
  /// уведомления успевает записать pending action в prefs. Поэтому проверяем
  /// сразу и ещё раз через короткую задержку. `consumePendingAction` удаляет
  /// ключ, так что повторный вызов безопасен (двойной навигации не будет).
  Future<void> _drainPendingAction() async {
    if (_drainingPending) return;
    _drainingPending = true;
    try {
      await _processPendingAction();
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await _processPendingAction();
    } finally {
      _drainingPending = false;
    }
  }

  Future<void> changeFilterIndex(int index) async {
    if (selectedFilterIndex == index) return;

    // Новая загрузка — инвалидируем любые ещё-летящие ответы (в т.ч.
    // стартовый handleRefresh для «Доступные»), чтобы они не затёрли orders.
    final token = ++_ordersReqToken;

    final isCourier = context.read<AuthProvider>().isCourier;

    // Shimmer skeleton — даёт визуальный feedback что данные грузятся.
    setState(() {
      selectedFilterIndex = index;
      // Статус-фильтр при смене вкладки:
      //  - курьер → «Мои заказы»: дефолт «В работе» (active) — самый частый
      //    сценарий (активные доставки), а не «Все»;
      //  - иначе («Доступные», или магазин): сбрасываем на «Все» (null).
      // Сброс важен: иначе выбранный в «Мои заказы» статус протекал в
      // «Доступные» (там все published) и отсекал их — список казался пустым.
      selectedStatus = (isCourier && index == 1) ? 'active' : null;
      ordersReloading = true;
      httpOffset = 0;
      hasMore = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      final myOrdersOnlyParam = index == 1;

      // 1. Скачиваем актуальные заказы для выбранной вкладки по HTTP
      final fetchedOrders = await orderService.getOrders(
        role: auth.role,
        userId: auth.userId,
        myOrdersOnly: myOrdersOnlyParam,
        transportFilter: filters.transportFilter,
        shopProvinceId: filters.shopProvince?.id,
        shopEtrapId: filters.shopEtrap?.id,
        shopDistrictId: filters.shopDistrict?.id,
        deliveryProvinceId: filters.deliveryProvince?.id,
        deliveryEtrapId: filters.deliveryEtrap?.id,
        deliveryDistrictId: filters.deliveryDistrict?.id,
        shopPhone: filters.shop?.id,
        orderStatus: null, // фильтр по статусу — клиентский, applyFilters()
        categoryFilter: filters.category?.id,
      );

      if (mounted && token == _ordersReqToken) {
        setState(() {
          orders = fetchedOrders;
          ordersLoading = false;
          ordersReloading = false;
          ordersError = false;
          httpOffset = fetchedOrders.length;
        });
        _refreshShopCache(); // ← кеш заказчиков для фильтра
      }

      // 2. Переподключаем веб-сокеты на нужный тип заказов (Все или Только мои)
      // плюс с актуальными фильтрами курьера — иначе WS будет слать заказы,
      // которые HTTP бы отфильтровал, и UI начнёт «дёргаться».
      debugPrint(
        '🔌 WS: Переподключение из-за смены вкладки на индекс $index (myOrdersOnly: $myOrdersOnlyParam)',
      );
      realtimeService.reconnectWithFilters(
        role: auth.role,
        userId: auth.userId,
        myOrdersOnly: myOrdersOnlyParam,
        transportFilter: filters.transportFilter,
        shopProvinceId: filters.shopProvince?.id,
        shopEtrapId: filters.shopEtrap?.id,
        shopDistrictId: filters.shopDistrict?.id,
        deliveryProvinceId: filters.deliveryProvince?.id,
        deliveryEtrapId: filters.deliveryEtrap?.id,
        deliveryDistrictId: filters.deliveryDistrict?.id,
        shopPhone: filters.shop?.id,
        orderStatus: null, // фильтр по статусу — клиентский, applyFilters()
        categoryFilter: filters.category?.id,
      );
    } catch (e) {
      debugPrint('Ошибка при смене вкладки: $e');
      if (mounted && token == _ordersReqToken) {
        setState(() {
          ordersLoading = false;
          ordersReloading = false;
          ordersError = true;
        });
      }
    }
  }

  void disposeController() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    realtimeService.disconnect();
    scrollController.dispose();
  }

  // ── Pending action processor ───────────────────────────────────────────

  /// Парсит и выполняет pending action, поставленный из background isolate'а
  /// в `ActiveOrdersNotification.onActionReceivedMethod`.
  ///
  /// Формат строки в prefs: `<verb>:<orderId>`. Поддерживается:
  ///   - `open_finish:<id>` — открыть заказ и форму подтверждения завершения
  ///   - `complete:<id>` — PATCH status='completed'
  ///   - (расширяемо: `cancel:<id>`, `accept:<id>`)
  ///
  /// На любую ошибку — silent fail. Если PATCH провалится, пользователь
  /// увидит непросроченный статус и сможет нажать кнопку снова.
  Future<void> _processPendingAction() async {
    final action = await ActiveOrdersNotification.consumePendingAction();
    if (action == null || action.isEmpty) return;
    if (!mounted) return;

    final colonIdx = action.indexOf(':');
    if (colonIdx <= 0 || colonIdx >= action.length - 1) return;
    final verb = action.substring(0, colonIdx);
    final orderId = action.substring(colonIdx + 1);

    final auth = context.read<AuthProvider>();

    switch (verb) {
      case 'open_finish':
        // Кнопка «Завершить» из sticky-уведомления: открываем сам заказ и
        // форму подтверждения завершения (ввод кода), а не завершаем втихую.
        final order = await orderService.getOrderById(orderId);
        if (!mounted) return;
        if (order != null) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                order: order,
                role: auth.role,
                currentUserId: auth.userId,
                autoOpenFinish: true,
                onUpdate: handleRefresh,
              ),
            ),
          );
        }
        break;

      case 'complete':
        // Legacy путь — без verification code. Оставлен для обратной
        // совместимости (если кто-то задаст pending action из другого места).
        final ok = await orderService.updateStatus(
          orderId,
          'completed',
          userId: auth.userId,
        );
        if (!mounted) return;
        if (ok) await handleRefresh();
        break;

      case 'completed':
        // Notification handler уже успешно вызвал verifyDeliveryCode —
        // статус заказа уже 'completed' на сервере. Нам остаётся только
        // обновить UI + cashback (как делает order_detail_screen).
        unawaited(orderService.applyCashbackIfOnTime(
          orderId: orderId,
          courierId: auth.userId,
        ));
        await handleRefresh();
        break;
    }
  }

  Future<void> loadActiveOrdersCount(String userId) async {
    final count = await orderService.getActiveOrdersCount(userId);
    if (mounted) setState(() => activeOrdersCount = count);
  }

  Future<void> checkUnreadNotifications() async {
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();
    final words = lang.words;
    final isRu = lang.isRu;
    if (auth.userId.isEmpty) return;
    try {
      final service = NotificationService();
      final unreadRaw = await service.getUnread(auth.userId);
      if (unreadRaw.isEmpty || !mounted) return;
      final unread = unreadRaw.map(NotificationDto.fromMap).toList();
      // Минимальная задержка чтобы дать UI отрендерить home — но не блокер.
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      // Кэшируем ссылки на messenger/AppColors/words ДО показа модалки.
      // После переавторизации цепочка `ScaffoldMessenger.of(context)` внутри
      // async-колбэка может race'иться с route-transition и потерять SnackBar.
      // Захват ссылок здесь гарантирует, что toast уйдёт в нужный messenger.
      final messenger = ScaffoldMessenger.of(context);
      final c = AppColors.of(context);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UnreadNotificationsModal(
          notifications: unread,
          onMarkAllRead: () async {
            await service.markAllAsRead(auth.userId);
            // mounted-check НЕ нужен — мы используем закэшированный messenger,
            // а не lookup через context. Это и есть весь смысл фикса.
            _showMarkAllConfirmToastWith(
              messenger: messenger,
              c: c,
              words: words,
              count: unread.length,
            );
          },
          words: words,
          isRu: isRu,
        ),
      );
    } catch (e) {
      debugPrint('checkUnreadNotifications error: $e');
    }
  }

  /// Anthropic-style confirmation toast после "Прочитать все" на модалке.
  /// Без undo — модалка уже закрыта, эта операция считается финальной.
  ///
  /// Принимает messenger/c/words явно — нельзя полагаться на
  /// `ScaffoldMessenger.of(context)` в async-колбэке, потому что после
  /// re-auth контекст может уже относиться к новому виджет-дереву.
  void _showMarkAllConfirmToastWith({
    required ScaffoldMessengerState messenger,
    required AppColors c,
    required AppLocalizations words,
    required int count,
  }) {
    messenger.clearSnackBars();
    final text = words.notifMarkAllToast.replaceAll('{n}', '$count');
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.emeraldTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.done_all_rounded, size: 18, color: c.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppText.medium(fontSize: 13, color: c.ink),
              ),
            ),
          ],
        ),
        backgroundColor: c.surface,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.ink.withValues(alpha: 0.15), width: 1),
        ),
      ),
    );
  }

  Future<void> initLocationFilter() async {
    final auth = context.read<AuthProvider>();
    if (auth.role != 'courier') return;

    final isRu = context.read<LanguageProvider>().isRu;
    final prefs = await SharedPreferences.getInstance();

    provinceId = prefs.getString('province_id') ?? '';
    provinceLabelRu = prefs.getString('province_ru') ?? '';
    provinceLabelTk = prefs.getString('province_tk') ?? '';
    // `provinceLabel` оставлен для обратной совместимости — single-lang
    // на момент инициализации. UI читает двуязычный через CourierFilterItem.
    provinceLabel = isRu ? provinceLabelRu : provinceLabelTk;

    etrapId = prefs.getString('etrap_id') ?? '';
    etrapLabelRu = prefs.getString('etrap_ru') ?? '';
    etrapLabelTk = prefs.getString('etrap_tk') ?? '';
    etrapLabel = isRu ? etrapLabelRu : etrapLabelTk;

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

  /// Снимок магазинов для модалки. Пополнение кеша делается в
  /// `_refreshShopCache()` на каждой загрузке orders — здесь только
  /// возвращаем текущий снимок.
  List<CourierFilterItem> buildShopItems() {
    classifierCache.mergeFromOrders(orders);
    return classifierCache.sortedShopItems;
  }

  /// Пополнить кеш магазинов из текущего `orders`. Вызывается на каждой
  /// точке загрузки orders (handleRefresh, смена вкладки, пагинация,
  /// WS-push) — гарантирует, что кеш растёт даже если пользователь
  /// никогда не открывал фильтр.
  ///
  /// Без этого вызова: юзер на пустой вкладке открывает фильтр →
  /// `buildShopItems()` строит из пустого `orders` → кеш не пополняется →
  /// tile «Магазин» disabled, выбрать заказчика нельзя.
  void _refreshShopCache() {
    classifierCache.mergeFromOrders(orders);
  }

  List<dynamic> applyFilters(List<dynamic> targetOrders) {
    if (selectedStatus == null) return targetOrders;
    return targetOrders
        .where(
          (o) =>
              (o['order_status'] ?? '').toString().toLowerCase() ==
              selectedStatus,
        )
        .toList();
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;

    setState(() => loadingMore = true);

    final auth = context.read<AuthProvider>();

    try {
      // Корректный offset — это текущее количество элементов.
      // Если сокет добавил новые элементы сверху, httpOffset должен это учитывать.

      final more = await orderService.getOrders(
        role: auth.role,
        userId: auth.userId,
        myOrdersOnly: selectedFilterIndex == 1,
        offset: orders.length,
        limit: pageSize,
        transportFilter: filters.transportFilter,
        shopProvinceId: filters.shopProvince?.id,
        shopEtrapId: filters.shopEtrap?.id,
        shopDistrictId: filters.shopDistrict?.id,
        deliveryProvinceId: filters.deliveryProvince?.id,
        deliveryEtrapId: filters.deliveryEtrap?.id,
        deliveryDistrictId: filters.deliveryDistrict?.id,
        shopPhone: filters.shop?.id,
        orderStatus: null, // фильтр по статусу — клиентский, applyFilters()
        categoryFilter: filters.category?.id,
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
        _refreshShopCache(); // ← кеш заказчиков для фильтра
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

    debugPrint(
      '🔌 HomeScreenController: Подключение к сокетам для пользователя ${auth.userId}',
    );
    realtimeService.connect(
      role: auth.role,
      userId: auth.userId,
      myOrdersOnly: selectedFilterIndex == 1,
      transportFilter: filters.transportFilter,
      shopProvinceId: filters.shopProvince?.id,
      shopEtrapId: filters.shopEtrap?.id,
      shopDistrictId: filters.shopDistrict?.id,
      deliveryProvinceId: filters.deliveryProvince?.id,
      deliveryEtrapId: filters.deliveryEtrap?.id,
      deliveryDistrictId: filters.deliveryDistrict?.id,
      shopPhone: filters.shop?.id,
      orderStatus: null, // WS подписан на все статусы, фильтр на клиенте
      categoryFilter: filters.category?.id,
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

      _refreshShopCache(); // ← кеш заказчиков для фильтра (WS create/update)

      // Переприменяем локальные фильтры (по велаятам/этрапам),
      // чтобы новый или обновленный сокет-заказ сразу правильно отфильтровался на экране
      applyFilters(orders);
      // WS-событие может означать что новый заказ ушёл в active или
      // существующий завершился. Пересинхронизируем уведомление.
      unawaited(_syncActiveOrdersNotification());
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
    await realtimeService.connect(
      role: auth.role,
      userId: auth.userId,
      myOrdersOnly: selectedFilterIndex == 1,
      transportFilter: filters.transportFilter,
      shopProvinceId: filters.shopProvince?.id,
      shopEtrapId: filters.shopEtrap?.id,
      shopDistrictId: filters.shopDistrict?.id,
      deliveryProvinceId: filters.deliveryProvince?.id,
      deliveryEtrapId: filters.deliveryEtrap?.id,
      deliveryDistrictId: filters.deliveryDistrict?.id,
      shopPhone: filters.shop?.id,
      orderStatus: null, // WS подписан на все статусы, фильтр на клиенте
      categoryFilter: filters.category?.id,
    );
  }

  Future<void> handleRefresh() async {
    httpOffset = 0;
    hasMore = true;

    // Токен этой загрузки. Если до её завершения стартует другая (смена
    // вкладки/фильтра) — наш ответ устарел и применять его нельзя.
    final token = ++_ordersReqToken;

    final auth = context.read<AuthProvider>();
    final isCourier = auth.userId.isNotEmpty && auth.role == 'courier';
    // Если профиль только что прилетел из verifyOTP — не дёргаем сервер
    // ещё раз. Экономия одного HTTP'а и ~200–500 ms на старте.
    final skipProfile = auth.consumeFreshProfileFlag();

    // Все 4 операции независимы друг от друга — пуляем параллельно.
    // Раньше шло последовательно: profile → level → ordersCount → orders.
    // Теперь все четыре конкуррентно (макс. сумма = max времени из них).
    final results = await Future.wait<dynamic>([
      // 0: profile (skip если свежий)
      if (skipProfile) Future.value(null) else auth.refreshProfile(),
      // 1: orders. ВАЖНО: на ошибке возвращаем `null`, не пустой список,
      // чтобы отличить «реально нет заказов» от «запрос провалился».
      // Раньше catchError → [] → setState затирал существующие orders
      // на любой временной ошибке (401-cooldown, network blip и т.п.) →
      // только что созданный заказ исчезал у пользователя.
      orderService
          .getOrders(
            role: auth.role,
            userId: auth.userId,
            myOrdersOnly: selectedFilterIndex == 1,
            transportFilter: filters.transportFilter,
            shopProvinceId: filters.shopProvince?.id,
            shopEtrapId: filters.shopEtrap?.id,
            shopDistrictId: filters.shopDistrict?.id,
            deliveryProvinceId: filters.deliveryProvince?.id,
            deliveryEtrapId: filters.deliveryEtrap?.id,
            deliveryDistrictId: filters.deliveryDistrict?.id,
            shopPhone: filters.shop?.id,
            orderStatus: null, // фильтр по статусу — клиентский, applyFilters()
            categoryFilter: filters.category?.id,
          )
          .then<List<dynamic>?>((v) => v)
          .catchError((_) => null),
      // 2: courier level
      if (isCourier)
        context.read<LevelProvider>().loadForUser(auth.userId)
      else
        Future.value(null),
      // 3: courier active orders count
      if (isCourier)
        orderService.getActiveOrdersCount(auth.userId)
      else
        Future.value(0),
    ]);

    if (!mounted) return;

    // `null` означает «запрос провалился» — НЕ затираем существующие orders.
    // `[]` означает «у пользователя реально нет заказов» — обновляем UI.
    final fetchedOrdersOrNull = results[1] as List<dynamic>?;
    final activeCount = (results[3] as int?) ?? 0;

    // Ответ устарел: пока ждали, пользователь сменил вкладку/фильтр и уже
    // запущена новая загрузка. Применять этот `orders` нельзя — затрём
    // актуальные данные. Счётчик активных заказов обновить всё же можно.
    final ordersStale = token != _ordersReqToken;

    setState(() {
      // Счётчик активных заказов не зависит от вкладки — обновляем всегда.
      activeOrdersCount = activeCount;
      if (ordersStale) {
        // orders/ordersLoading/ordersError — ими владеет новый запрос, не трогаем.
        return;
      }
      if (fetchedOrdersOrNull != null) {
        orders = fetchedOrdersOrNull;
        ordersError = false;
      } else {
        // Запрос упал. Оставляем существующие `orders` (как раз тот случай
        // когда WS только что добавил новый заказ, а refresh не пришёл).
        // Помечаем UI как «ошибка», но контент сохраняем.
        ordersError = true;
      }
      ordersLoading = false;
    });
    if (!ordersStale) _refreshShopCache(); // ← кеш заказчиков для фильтра
    // Не блокируем UI — fire-and-forget. Менеджер сам ничего не делает,
    // если активных заказов 0 (просто отменяет уведомление).
    unawaited(_syncActiveOrdersNotification());
  }

  /// Синхронизировать persistent notification «Активные заказы».
  ///
  /// Фильтрует текущий список `orders` под активные позиции
  /// текущего пользователя, конвертирует в `ActiveOrderSnapshot`'ы,
  /// передаёт менеджеру. На logout вызывается `hide()`.
  ///
  /// Ограничение: использует `orders` из текущей UI-вкладки. Если курьер
  /// на «Все» — активные заказы там отсутствуют по дизайну, уведомление
  /// будет пустым. Это OK для MVP — обычно курьер сидит на «Мои».
  /// В Phase 2 можно сделать отдельный fetch активных заказов независимо
  /// от UI-фильтра.
  Future<void> _syncActiveOrdersNotification() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) {
      await ActiveOrdersNotification.hide();
      return;
    }
    final lang = context.read<LanguageProvider>();
    final isRu = lang.isRu;
    final words = lang.words;

    final snapshots = <ActiveOrderSnapshot>[];
    for (final raw in orders) {
      if (raw is! Map) continue;
      final dto = OrderDto.fromMap(Map<String, dynamic>.from(raw));

      // Курьер: показываем только взятые им active.
      // Магазин: показываем published + active (его заказы в работе).
      if (auth.isCourier && dto.status != 'active') continue;
      if (auth.isShop && dto.status != 'published' && dto.status != 'active') {
        continue;
      }
      if (auth.isClient) continue;

      snapshots.add(
        ActiveOrderSnapshot(
          id: dto.id,
          shortId: dto.shortId,
          addressLine: dto.deliveryAddress(isRu),
          // Курьеру звоним клиенту, магазину — курьеру.
          phoneToCall: auth.isCourier ? dto.clientPhone : dto.courierPhone,
          status: dto.status,
          // courierId нужен для `generateDeliveryCode` из notification.
          // У курьера это его собственный userId (он же courier для своих
          // активных заказов). У магазина — пустая строка (он не завершает).
          courierId: auth.isCourier ? auth.userId : '',
        ),
      );
    }

    await ActiveOrdersNotification.sync(
      orders: snapshots,
      title: words.activeOrdersNotifTitle,
      indexTemplate: (i, n) => words.activeOrdersIndex
          .replaceAll('{i}', '${i + 1}')
          .replaceAll('{n}', '$n'),
      callBtnLabel: words.activeOrdersBtnCall,
      completeBtnLabel: words.activeOrdersBtnComplete,
      verifyBtnLabel: words.activeOrdersBtnVerify,
      enterCodeTitle: words.activeOrdersEnterCodeTitle,
      codeSentBody: words.activeOrdersCodeSentBody,
      completedBody: words.activeOrdersCompleted,
    );
  }

  /// Переподключить WS с актуальным состоянием `filters` + `selectedStatus`.
  /// Вызывается после применения/сброса фильтров в модалке.
  Future<void> _reconnectWsWithCurrentFilters() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await realtimeService.reconnectWithFilters(
      role: auth.role,
      userId: auth.userId,
      myOrdersOnly: selectedFilterIndex == 1,
      transportFilter: filters.transportFilter,
      shopProvinceId: filters.shopProvince?.id,
      shopEtrapId: filters.shopEtrap?.id,
      shopDistrictId: filters.shopDistrict?.id,
      deliveryProvinceId: filters.deliveryProvince?.id,
      deliveryEtrapId: filters.deliveryEtrap?.id,
      deliveryDistrictId: filters.deliveryDistrict?.id,
      shopPhone: filters.shop?.id,
      orderStatus: null, // WS подписан на все статусы, фильтр на клиенте
      categoryFilter: filters.category?.id,
    );
  }

  void showFilterModal() {
    final isRu = context.read<LanguageProvider>().isRu;
    final words = context.read<LanguageProvider>().words;

    // Передаём оба языка — модалка возьмёт нужный в зависимости от
    // текущего locale. Без двуязычных лейблов после смены RU↔TK
    // тут оставался застывший язык на момент initLocationFilter.
    final defaultProvince = provinceId.isNotEmpty
        ? CourierFilterItem(
            id: provinceId,
            label: provinceLabel, // legacy fallback
            labelRu: provinceLabelRu,
            labelTk: provinceLabelTk,
          )
        : null;
    final defaultEtrap = etrapId.isNotEmpty
        ? CourierFilterItem(
            id: etrapId,
            label: etrapLabel,
            labelRu: etrapLabelRu,
            labelTk: etrapLabelTk,
          )
        : null;

    // Строим shopItems ДО очистки orders
    final shopItems = buildShopItems();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => CourierFilterModal(
        initial: filters,
        applyDefaults: !_filtersEverApplied,
        isRu: isRu,
        cache: classifierCache,
        authRepo: authRepo,
        shopItems: shopItems,
        defaultProvince: defaultProvince,
        defaultEtrap: defaultEtrap,
        onApply: (newFilters) {
          _filtersEverApplied = true; // ← добавить
          setState(() {
            filters = newFilters;
            orders = [];
            ordersLoading = true;
            httpOffset = 0;
            hasMore = true;
          });
          Navigator.pop(modalCtx);
          handleRefresh();
          // WS — на новые фильтры. Иначе сокет будет слать заказы по старым.
          _reconnectWsWithCurrentFilters();
        },
        onClear: () {
          _filtersEverApplied = true; // ← добавить
          setState(() {
            filters = const CourierFilters();
            selectedStatus = null;
            orders = [];
            ordersLoading = true;
            httpOffset = 0;
            hasMore = true;
          });
          Navigator.pop(modalCtx);
          handleRefresh();
          _reconnectWsWithCurrentFilters();
        },
        words: words,
      ),
    );
  }
}
