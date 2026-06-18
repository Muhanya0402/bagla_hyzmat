import 'dart:ui';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/features/notifications/notification_dto.dart';
import 'package:bagla/features/notifications/widgets/notification_helpers.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// ─── Public API ───────────────────────────────────────────────────────────────

class UnreadNotificationsModal extends StatelessWidget {
  final List<NotificationDto> notifications;

  /// Должен возвращать `Future` — модалка дождётся завершения, чтобы
  /// показать loading-state и не закрыться раньше, чем PATCH сервер
  /// отработает. Раньше тут был `VoidCallback`, async-функция
  /// уходила в fire-and-forget, пользователь видел «нажал — ничего».
  final Future<void> Function() onMarkAllRead;

  /// Called after the sheet closes. Caller handles screen navigation.
  final void Function(NotificationDto)? onNotificationTap;

  final AppLocalizations words;
  final bool isRu;

  const UnreadNotificationsModal({
    super.key,
    required this.notifications,
    required this.onMarkAllRead,
    required this.words,
    required this.isRu,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return _UnreadModalBody(
      notifications: notifications,
      onMarkAllRead: onMarkAllRead,
      onNotificationTap: onNotificationTap,
      words: words,
      isRu: isRu,
    );
  }
}

// ─── Body (stateful for local read tracking) ──────────────────────────────────

class _UnreadModalBody extends StatefulWidget {
  final List<NotificationDto> notifications;
  final Future<void> Function() onMarkAllRead;
  final void Function(NotificationDto)? onNotificationTap;
  final AppLocalizations words;
  final bool isRu;

  const _UnreadModalBody({
    required this.notifications,
    required this.onMarkAllRead,
    required this.onNotificationTap,
    required this.words,
    required this.isRu,
  });

  @override
  State<_UnreadModalBody> createState() => _UnreadModalBodyState();
}

class _UnreadModalBodyState extends State<_UnreadModalBody> {
  late final List<NotificationDto> _items;

  /// Идёт ли сейчас запрос «прочитать все». Используется чтобы:
  ///   1) показать спиннер вместо иконки на кнопке
  ///   2) заблокировать повторные тапы
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _items = List<NotificationDto>.from(widget.notifications);
  }

  Future<void> _onMarkAll() async {
    if (_marking) return; // защита от двойного тапа
    setState(() => _marking = true);

    // Захватываем navigator ДО await — после он может быть уже не валиден.
    final nav = Navigator.of(context);

    try {
      // Дожидаемся завершения server PATCH. Без await пользователь видел
      // «нажал — модалка закрылась, ничего не поменялось». Теперь модалка
      // не закроется пока сервер не подтвердит (или не упадёт).
      await widget.onMarkAllRead();
    } catch (_) {
      // Ошибку проглатываем — caller сам решает что с ней делать,
      // у нас тут только UI: закрыть модалку либо снять loading.
    }

    if (!mounted) return;
    nav.pop();
  }

  void _onTap(NotificationDto notif) {
    Navigator.pop(context);
    widget.onNotificationTap?.call(notif);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final screenH = MediaQuery.of(context).size.height;
    final c = AppColors.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        // sigma 2 — заметно дешевле, визуально близко.
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            border: Border(
              top: BorderSide(color: c.borderSoft, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ────────────────────────────────────────────────
              const SheetHandle(),
              const SizedBox(height: 14),

              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            widget.words.notifNewNotifications,
                            style: AppText.serif(
                              fontSize: 18,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${_items.length}',
                            style: AppText.semiBold(
                              fontSize: 15,
                              color: c.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _MarkAllButton(
                      label: widget.words.notifMarkAll,
                      onTap: _onMarkAll,
                      loading: _marking,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Divider ────────────────────────────────────────────────
              Container(height: 0.5, color: c.borderSoft),

              // ── List ───────────────────────────────────────────────────
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screenH * 0.42),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => Container(
                    height: 0.5,
                    margin: const EdgeInsets.only(left: 64),
                    color: c.borderSoft,
                  ),
                  itemBuilder: (_, i) => _NotifRow(
                    notif: _items[i],
                    isRu: widget.isRu,
                    words: widget.words,
                    onTap: () => _onTap(_items[i]),
                  ),
                ),
              ),

              // ── Divider ────────────────────────────────────────────────
              Container(height: 0.5, color: c.borderSoft),
              const SizedBox(height: 12),

              // ── Close button ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 16),
                child: _CloseButton(
                  label: widget.words.notifClose,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Notification row ──────────────────────────────────────────────────────────

class _NotifRow extends StatefulWidget {
  final NotificationDto notif;
  final bool isRu;
  final AppLocalizations words;
  final VoidCallback onTap;

  const _NotifRow({
    required this.notif,
    required this.isRu,
    required this.words,
    required this.onTap,
  });

  @override
  State<_NotifRow> createState() => _NotifRowState();
}

class _NotifRowState extends State<_NotifRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final n = widget.notif;
    final s = notifTypeStyle(n.type, c);

    final title = n.title(widget.isRu);
    final body = n.body(widget.isRu);
    final timeStr = notifFormatDate(
      n.raw['date_created']?.toString(),
      widget.words,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Type icon ──────────────────────────────────────────
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: s.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(notifTypeIcon(n.type), color: s.icon, size: 16),
              ),
              const SizedBox(width: 12),

              // ── Text ───────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppText.semiBold(fontSize: 13, color: c.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: AppText.regular(fontSize: 12, color: c.inkMuted)
                            .copyWith(height: 1.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ── Time + unread dot ──────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: AppText.regular(fontSize: 10, color: c.inkSoft),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mark-all button ──────────────────────────────────────────────────────────

class _MarkAllButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const _MarkAllButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  State<_MarkAllButton> createState() => _MarkAllButtonState();
}

class _MarkAllButtonState extends State<_MarkAllButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      // **opaque** — гарантированно ловим тап в любой точке prefix-padding'а,
      // а не только под иконкой/текстом (как было раньше с маленькой
      // паддингом 2/4 — пользователь мазал мимо).
      behavior: HitTestBehavior.opaque,
      // Используем `onTap` вместо `onTapUp`. onTapUp не срабатывает,
      // если палец чуть-чуть сдвинулся между down и up — для маленькой
      // кнопки это давало ощущение «нажал, не отработало». onTap имеет
      // более forgiving детекцию (gesture arena → tap recogniser).
      onTap: widget.loading ? null : widget.onTap,
      onTapDown: widget.loading ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.loading ? null : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          // Увеличили hit-area: было 2/4 → стало 10/8 + min height 36
          // (комфортный 44-точечный target по HIG/Material).
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: c.ink,
                  ),
                )
              else
                Icon(Icons.done_all_rounded, size: 13, color: c.ink),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: AppText.semiBold(fontSize: 12, color: c.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Close button ─────────────────────────────────────────────────────────────

class _CloseButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _CloseButton({required this.label, required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppText.medium(fontSize: 14, color: c.inkMuted),
          ),
        ),
      ),
    );
  }
}
