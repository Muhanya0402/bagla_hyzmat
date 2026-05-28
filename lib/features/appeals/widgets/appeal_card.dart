import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AppealCard extends StatefulWidget {
  final dynamic appeal;
  final VoidCallback onTap;
  final AppLocalizations words;

  const AppealCard({
    super.key,
    required this.appeal,
    required this.onTap,
    required this.words,
  });

  @override
  State<AppealCard> createState() => _AppealCardState();
}

class _AppealCardState extends State<AppealCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final String status = (widget.appeal['status'] ?? 'open').toString();
    final String subject = (widget.appeal['subject'] ?? '').toString();
    final String body = (widget.appeal['body'] ?? '').toString();
    final String date = _formatDate(widget.appeal['date_created']);
    final bool hasReply = (widget.appeal['reply'] ?? '').toString().isNotEmpty;
    final cfg = _statusCfg(status);

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
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.of(context).border),
          ),
          child: Row(
            children: [
              // ── Status accent bar ────────────────────────────────────
              Container(
                width: 3,
                height: 68,
                decoration: BoxDecoration(
                  color: cfg.accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subject.isEmpty
                                  ? widget.words.appealsNoSubject
                                  : subject,
                              style: AppText.semiBold(
                                fontSize: 13,
                                color: AppColors.of(context).ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(cfg: cfg),
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: AppText.regular(
                            fontSize: 12,
                            color: AppColors.of(context).inkMuted,
                          ).copyWith(height: 1.35),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: AppColors.of(context).inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            date,
                            style: AppText.regular(
                              fontSize: 11,
                              color: AppColors.of(context).inkSoft,
                            ),
                          ),
                          const Spacer(),
                          if (hasReply)
                            _HasReplyBadge(label: widget.words.appealsHasReply),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Chevron ──────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.of(context).inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) {
        return '${widget.words.appealsToday} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';
      }
      if (diff.inDays == 1) return widget.words.appealsYesterday;
      return '${dt.day.toString().padLeft(2, '0')}.'
          '${dt.month.toString().padLeft(2, '0')}.'
          '${dt.year}';
    } catch (_) {
      return '';
    }
  }

  _StatusCfg _statusCfg(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return _StatusCfg(
          accent: AppColors.of(context).amber,
          bg: AppColors.of(context).amberTint,
          text: AppColors.of(context).amber,
          label: widget.words.appealsStatusOpen,
        );
      case 'in_progress':
        return _StatusCfg(
          accent: AppColors.of(context).amber,
          bg: AppColors.of(context).amberTint,
          text: AppColors.of(context).amber,
          label: widget.words.appealsStatusProgress,
        );
      case 'resolved':
      case 'closed':
        return _StatusCfg(
          accent: AppColors.of(context).emerald,
          bg: AppColors.of(context).emeraldTint,
          text: AppColors.of(context).emerald,
          label: widget.words.appealsStatusClosed,
        );
      default:
        return _StatusCfg(
          accent: AppColors.of(context).inkSoft,
          bg: AppColors.of(context).borderSoft,
          text: AppColors.of(context).inkSoft,
          label: status,
        );
    }
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _StatusCfg {
  final Color accent;
  final Color bg;
  final Color text;
  final String label;
  const _StatusCfg({
    required this.accent,
    required this.bg,
    required this.text,
    required this.label,
  });
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final _StatusCfg cfg;
  const _StatusBadge({required this.cfg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: cfg.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            cfg.label,
            style: AppText.semiBold(fontSize: 10, color: cfg.text),
          ),
        ],
      ),
    );
  }
}

class _HasReplyBadge extends StatelessWidget {
  final String label;
  const _HasReplyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.of(context).emeraldTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.of(context).emerald.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.reply_rounded,
            size: 10,
            color: AppColors.of(context).emerald,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.semiBold(
              fontSize: 10,
              color: AppColors.of(context).emerald,
            ),
          ),
        ],
      ),
    );
  }
}
