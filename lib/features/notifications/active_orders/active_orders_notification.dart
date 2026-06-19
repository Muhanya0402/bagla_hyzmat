import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'active_order_snapshot.dart';

/// Менеджер «персистентного» уведомления с активными заказами.
///
/// Архитектура и решения см. в README этого модуля. Кратко:
///   - **Один источник правды** — список снимков в SharedPreferences под ключом
///     `_kOrdersKey`. Главный isolate пишет, background isolate читает.
///   - **Индекс текущей карточки** — отдельный prefs-ключ `_kIndexKey`. Кнопки
///     `‹` `›` в background isolate его правят и пересоздают уведомление.
///   - **Notification id** — фиксированный `_kNotifId`. Каждое
///     `createNotification` с тем же id обновляет существующее, а не создаёт
///     новое (это нативный поведение и Android, и iOS).
///   - **Action buttons** — обрабатываются в background isolate через
///     static `onActionReceivedMethod`. Из-за этого все зависимости должны
///     быть statically initialisable.
/// `@pragma('vm:entry-point')` на КЛАССЕ — обязательно для AOT.
/// `awesome_notifications` запускает action handler из native кода в
/// отдельном isolate'е, где tree-shaker'у нужно явно сказать
/// «не удаляй этот класс». Аннотации на отдельных static-методах
/// (`onActionReceivedMethod` ниже) недостаточно — нужно ещё и на классе.
@pragma('vm:entry-point')
abstract final class ActiveOrdersNotification {
  ActiveOrdersNotification._();

  // ── Constants ──────────────────────────────────────────────────────────
  static const _channelKey = 'active_orders';
  static const _channelGroupKey = 'active_orders_group';
  static const _kNotifId = 7001;

  // Prefs keys (используются и в main isolate, и в background handler).
  static const _kOrdersKey = 'active_orders_snapshots';
  static const _kIndexKey = 'active_orders_index';
  static const _kPendingActionKey = 'active_orders_pending_action';
  static const _kTitleKey = 'active_orders_title';
  static const _kCallLabelKey = 'active_orders_call_label';
  static const _kCompleteLabelKey = 'active_orders_complete_label';
  static const _kVerifyLabelKey = 'active_orders_verify_label';
  static const _kEnterCodeTitleKey = 'active_orders_enter_code_title';
  static const _kCodeSentBodyKey = 'active_orders_code_sent_body';
  static const _kCompletedBodyKey = 'active_orders_completed_body';
  static const _kPrefixIndexKey = 'active_orders_index_template';
  /// Префикс per-order ключа «код уже отправлен клиенту, ждём ввод».
  /// Полный ключ: `<prefix><orderId>`.
  static const _kCodeSentPrefix = 'active_orders_code_sent_';

  // Action keys — должны быть стабильными между релизами, потому что Android
  // может «доставить» action после рестарта приложения.
  static const _actPrev = 'ACTIVE_ORDERS_PREV';
  static const _actNext = 'ACTIVE_ORDERS_NEXT';
  static const _actCall = 'ACTIVE_ORDERS_CALL';
  /// «Завершить» — открывает заказ в приложении и форму подтверждения
  /// завершения (ввод кода). Завершение происходит в app, не в шторке.
  static const _actFinish = 'ACTIVE_ORDERS_FINISH';

  // ── Initialization ─────────────────────────────────────────────────────

  /// Вызывается один раз в main() после WidgetsFlutterBinding.ensureInitialized().
  /// Регистрирует канал, листенеры и просит разрешение на уведомления.
  static Future<void> initialize({
    required String channelName,
    required String channelDesc,
  }) async {
    await AwesomeNotifications().initialize(
      // Используем тот же drawable, что и для обычных push'ей.
      // На iOS поле игнорируется — там используется app icon.
      'resource://drawable/ic_notification',
      [
        NotificationChannel(
          channelKey: _channelKey,
          channelName: channelName,
          channelDescription: channelDesc,
          importance: NotificationImportance.Low,
          // Sticky — пользователь не может смахнуть свайпом, пока не
          // закроет приложение или не завершит заказы.
          locked: true,
          // Без звука — это не «новое» уведомление, а статус-плашка.
          playSound: false,
          enableVibration: false,
          channelShowBadge: false,
          defaultPrivacy: NotificationPrivacy.Public,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: _channelGroupKey,
          channelGroupName: 'Bagla',
        ),
      ],
      debug: kDebugMode,
    );

    // Регистрируем background handler для action buttons.
    // Это static — Awesome Notifications запустит его в отдельном isolate,
    // когда пользователь тапнет кнопку при закрытом приложении.
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );

    // ⚠️ Без этого флэша баг «нажал в шторке — ничего не работает, пока
    // не зайду в приложение». Объяснение:
    //
    // Когда процесс приложения killed (Android battery saver, swap),
    // user тапает кнопку action в шторке → нативная часть awesome_notif
    // ставит action в очередь, но НЕ доставляет его автоматически в
    // `onActionReceivedMethod` при cold start. Action ждёт в нативной
    // очереди и достаётся только через явный `getInitialNotificationAction()`.
    //
    // Если не вытащить — пользователю кажется что кнопка не сработала.
    // Когда он откроет app и тапнет кнопку повторно (уже в alive-режиме),
    // только тогда оно отработает в main isolate'е.
    //
    // Делаем flush после `setListeners` — обработчик уже привязан, action
    // прокинется в него корректно. removeFromActionEvents=true — чистим
    // очередь, чтобы не сработало повторно в следующий запуск.
    final pending = await AwesomeNotifications().getInitialNotificationAction(
      removeFromActionEvents: true,
    );
    if (pending != null && pending.buttonKeyPressed.isNotEmpty) {
      // Запускаем в main isolate'е — здесь все плагины (url_launcher,
      // dio, flutter_secure_storage) уже зарегистрированы. Это надёжнее,
      // чем background isolate с урезанным engine'ом.
      unawaited(onActionReceivedMethod(pending));
    }

    // Запросить разрешение если ещё не дано.
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Обновить список активных заказов и пересоздать уведомление.
  ///
  /// Если `orders.isEmpty` — уведомление **скрывается**.
  /// Иначе показывается карточка с `currentIndex` (по умолчанию 0,
  /// либо последнее сохранённое значение если оно ещё валидно).
  ///
  /// Должно вызываться:
  ///   - при стартовой загрузке home (handleRefresh)
  ///   - при WS-событии create/update/delete
  ///   - при смене статуса заказа из приложения
  static Future<void> sync({
    required List<ActiveOrderSnapshot> orders,
    required String title,
    required String Function(int index, int total) indexTemplate,
    required String callBtnLabel,
    required String completeBtnLabel,
    required String verifyBtnLabel,
    required String enterCodeTitle,
    required String codeSentBody,
    required String completedBody,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (orders.isEmpty) {
      await prefs.remove(_kOrdersKey);
      await prefs.remove(_kIndexKey);
      await AwesomeNotifications().cancel(_kNotifId);
      return;
    }

    // Сохраняем снимки и все локализованные шаблоны для background handler.
    await prefs.setString(_kOrdersKey, ActiveOrderSnapshot.encodeList(orders));
    await prefs.setString(_kTitleKey, title);
    await prefs.setString(_kCallLabelKey, callBtnLabel);
    await prefs.setString(_kCompleteLabelKey, completeBtnLabel);
    await prefs.setString(_kVerifyLabelKey, verifyBtnLabel);
    await prefs.setString(_kEnterCodeTitleKey, enterCodeTitle);
    await prefs.setString(_kCodeSentBodyKey, codeSentBody);
    await prefs.setString(_kCompletedBodyKey, completedBody);
    // Шаблон индекса — упрощённо сохраняем формат «{i} / {n}», который
    // background handler сможет применить без l10n.
    await prefs.setString(_kPrefixIndexKey, indexTemplate(0, 0));

    // Чистим code_sent флаги для заказов, которых больше нет в списке
    // (например, заказ завершился и пропал из активных).
    final currentIds = orders.map((o) => o.id).toSet();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_kCodeSentPrefix)) continue;
      final orderId = key.substring(_kCodeSentPrefix.length);
      if (!currentIds.contains(orderId)) await prefs.remove(key);
    }

    // Текущий индекс: если стал out-of-range (заказ убрался), сбрасываем.
    int idx = prefs.getInt(_kIndexKey) ?? 0;
    if (idx >= orders.length) idx = 0;
    await prefs.setInt(_kIndexKey, idx);

    await _renderAt(idx);
  }

  /// Скрыть уведомление полностью (например, на logout).
  static Future<void> hide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOrdersKey);
    await prefs.remove(_kIndexKey);
    await AwesomeNotifications().cancel(_kNotifId);
  }

  /// Проверить и обработать pending action, поставленный из background.
  /// Вызывается main isolate'ом при app resume — чтобы выполнить действия
  /// типа «complete order», которые ненадёжно делать из background isolate.
  ///
  /// Возвращает code последнего pending action или null.
  static Future<String?> consumePendingAction() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingActionKey);
    if (raw == null) return null;
    await prefs.remove(_kPendingActionKey);
    return raw;
  }

  // ── Internal: render ───────────────────────────────────────────────────

  /// Создаёт/обновляет уведомление, показывая заказ с индексом `idx`.
  /// Вызывается и из main isolate (sync), и из background (action handler).
  static Future<void> _renderAt(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    final list = ActiveOrderSnapshot.decodeList(prefs.getString(_kOrdersKey));
    if (list.isEmpty || idx < 0 || idx >= list.length) {
      await AwesomeNotifications().cancel(_kNotifId);
      return;
    }

    final order = list[idx];
    final title = prefs.getString(_kTitleKey) ?? 'Bagla';
    final callLabel = prefs.getString(_kCallLabelKey) ?? 'Call';
    final completeLabel = prefs.getString(_kCompleteLabelKey) ?? 'Done';
    // Простой формат шаблона: «Заказ {i} из {n}»
    final indexLine = 'Заказ ${idx + 1} из ${list.length}';

    // ── Стратегия actionType ─────────────────────────────────────────────
    //
    // ‹ / › — `SilentBackgroundAction`: исполняется в отдельном dart-isolate
    //   ВНЕ жизненного цикла app и НЕ прерывается даже при killed-app. Ему
    //   нужны только SharedPreferences и AwesomeNotifications (createNotification
    //   без UI) — оба работают в background isolate. Бесшумное перелистывание
    //   без открытия app. (Раньше тут стоял `SilentAction`, который по докам
    //   пакета крутится на ГЛАВНОМ isolate и прерывается при terminate — из-за
    //   чего стрелки были ненадёжны.)
    //
    // Call / Finish — `Default`: будят app в main isolate. «Позвонить»
    //   запускает диалер (url_launcher), «Завершить» открывает сам заказ
    //   и форму подтверждения завершения в приложении (через pending action).
    //   На killed-app `SilentAction` молча падает — `Default` надёжно
    //   выводит app на передний план.
    final actions = <NotificationActionButton>[
      if (list.length > 1)
        NotificationActionButton(
          key: _actPrev,
          label: '‹',
          actionType: ActionType.SilentBackgroundAction,
          autoDismissible: false,
        ),
      // Позвонить — только если есть телефон в снимке.
      if (order.phoneToCall.isNotEmpty)
        NotificationActionButton(
          key: _actCall,
          label: callLabel,
          actionType: ActionType.Default,
          autoDismissible: false,
        ),
      // «Завершить» — открывает приложение на этом заказе и форму
      // подтверждения завершения (ввод кода). Никакого ввода кода в шторке.
      if (order.status == 'active')
        NotificationActionButton(
          key: _actFinish,
          label: completeLabel,
          actionType: ActionType.Default,
          autoDismissible: false,
        ),
      if (list.length > 1)
        NotificationActionButton(
          key: _actNext,
          label: '›',
          actionType: ActionType.SilentBackgroundAction,
          autoDismissible: false,
        ),
    ];

    final body = '#${order.shortId}\n${order.addressLine}';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _kNotifId,
        channelKey: _channelKey,
        title: '$title  ·  $indexLine',
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Status,
        // Цвет brand-tint (использует <color name="notification_color"> из
        // Android resources). Чтобы он применился, drawable должен быть
        // monochrome — это уже сделано в шаге с ic_notification.
        autoDismissible: false,
        // Sticky — пользователь не может смахнуть, пока в БД есть active orders.
        locked: true,
        // wakeUpScreen=false: если приходит из background, не будит screen,
        // показывается тихо.
        wakeUpScreen: false,
        showWhen: false,
        payload: {'orderId': order.id},
      ),
      actionButtons: actions,
    );
  }

  // ── Background handler ─────────────────────────────────────────────────

  /// Запускается в отдельном isolate'е при тапе action button.
  ///
  /// **Ограничения background isolate'а:**
  ///   - НЕТ доступа к Provider, Dio, любым main-isolate синглтонам
  ///   - SharedPreferences — единственный надёжный способ обмена с main
  ///   - url_launcher с tel: работает (вызывает системный intent)
  ///   - HTTP вызовы технически возможны, но Xiaomi/Huawei могут гасить
  ///     isolate раньше чем запрос успеет — поэтому делаем pending-action
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction action) async {
    final key = action.buttonKeyPressed;
    if (key.isEmpty) return; // тап по самому уведомлению — открывает app

    final prefs = await SharedPreferences.getInstance();
    final list = ActiveOrderSnapshot.decodeList(prefs.getString(_kOrdersKey));
    if (list.isEmpty) return;

    int idx = prefs.getInt(_kIndexKey) ?? 0;
    if (idx >= list.length) idx = 0;

    switch (key) {
      case _actPrev:
        idx = (idx - 1 + list.length) % list.length;
        await prefs.setInt(_kIndexKey, idx);
        await _renderAt(idx);
        break;

      case _actNext:
        idx = (idx + 1) % list.length;
        await prefs.setInt(_kIndexKey, idx);
        await _renderAt(idx);
        break;

      case _actCall:
        final phone = list[idx].phoneToCall;
        if (phone.isEmpty) return;
        try {
          await launchUrl(Uri(scheme: 'tel', path: phone));
        } on PlatformException catch (_) {
          // На некоторых девайсах нет diallera — silent fail.
        }
        break;

      case _actFinish:
        // «Завершить»: НЕ завершаем втихую и НЕ вводим код в шторке.
        // Ставим pending action — кнопка Default уже выводит app на
        // передний план, контроллер home на resume загрузит заказ и
        // откроет форму подтверждения завершения.
        await prefs.setString(
          _kPendingActionKey,
          'open_finish:${list[idx].id}',
        );
        break;
    }
  }
}
