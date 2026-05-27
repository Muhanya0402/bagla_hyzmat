import 'dart:ui';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/notifications/widgets/notification_helpers.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// ─── Public API ───────────────────────────────────────────────────────────────

class UnreadNotificationsModal extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final VoidCallback onMarkAllRead;

  /// Called after the sheet closes. Caller handles screen navigation.
  final Function(Map<String, dynamic>)? onNotificationTap;

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
  final List<Map<String, dynamic>> notifications;
  final VoidCallback onMarkAllRead;
  final Function(Map<String, dynamic>)? onNotificationTap;
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
  late final List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.notifications);
  }

  void _onMarkAll() {
    widget.onMarkAllRead();
    if (mounted) Navigator.pop(context);
  }

  void _onTap(Map<String, dynamic> notif) {
    Navigator.pop(context);
    widget.onNotificationTap?.call(notif);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          decoration: const BoxDecoration(
            color: AuthColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: AuthColors.borderSoft, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ────────────────────────────────────────────────
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AuthColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
                              color: AuthColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _MarkAllButton(
                      label: widget.words.notifMarkAll,
                      onTap: _onMarkAll,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Divider ────────────────────────────────────────────────
              Container(height: 0.5, color: AuthColors.borderSoft),

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
                    color: AuthColors.borderSoft,
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
              Container(height: 0.5, color: AuthColors.borderSoft),
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
  final Map<String, dynamic> notif;
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

  ({Color icon, Color bg}) _style(String type) {
    switch (type) {
      case 'daily_bonus':
        return (icon: AuthColors.amber, bg: AuthColors.amberTint);
      case 'new_order':
      case 'order_status':
        return (icon: AuthColors.emerald, bg: AuthColors.emeraldTint);
      case 'account_status':
        return (icon: AuthColors.errorMuted, bg: AuthColors.errorTint);
      default:
        return (icon: AuthColors.inkSoft, bg: AuthColors.borderSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (widget.notif['type'] ?? '').toString();
    final s = _style(type);
    final title =
        widget.notif[widget.isRu ? 'title_ru' : 'title_tk']?.toString() ??
        widget.notif['title']?.toString() ??
        '';
    final body =
        widget.notif[widget.isRu ? 'body_ru' : 'body_tk']?.toString() ??
        widget.notif['body']?.toString() ??
        '';
    final timeStr = notifFormatDate(
      widget.notif['date_created']?.toString(),
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
                child: Icon(notifTypeIcon(type), color: s.icon, size: 16),
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
                      style: AppText.semiBold(
                        fontSize: 13,
                        color: AuthColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: AppText.regular(
                          fontSize: 12,
                          color: AuthColors.inkMuted,
                        ).copyWith(height: 1.3),
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
                    style: AppText.regular(
                      fontSize: 10,
                      color: AuthColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AuthColors.accent,
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
  const _MarkAllButton({required this.label, required this.onTap});

  @override
  State<_MarkAllButton> createState() => _MarkAllButtonState();
}

class _MarkAllButtonState extends State<_MarkAllButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.done_all_rounded,
                size: 13,
                color: AuthColors.emerald,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: AppText.semiBold(
                  fontSize: 12,
                  color: AuthColors.emerald,
                ),
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
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuthColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppText.medium(fontSize: 14, color: AuthColors.inkMuted),
          ),
        ),
      ),
    );
  }
}
