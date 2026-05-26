import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AppealCard extends StatelessWidget {
  final dynamic appeal;
  final VoidCallback onTap;
  final AppLocalizations words;

  const AppealCard({
    super.key,
    required this.appeal,
    required this.onTap,
    required this.words,
  });

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);

  @override
  Widget build(BuildContext context) {
    final String status = (appeal['status'] ?? 'open').toString();
    final String subject = (appeal['subject'] ?? '').toString();
    final String body = (appeal['body'] ?? '').toString();
    final String date = _formatDate(appeal['date_created']);
    final bool hasReply = (appeal['reply'] ?? '').toString().isNotEmpty;
    final _StatusCfg cfg = _statusCfg(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEF0F3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Цветная полоска статуса ──────────────────────────────────
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: cfg.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Тема + статус ──────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject.isEmpty ? words.appealsNoSubject : subject,
                          style: AppText.semiBold(
                            fontSize: 14,
                            color: const Color(0xFF0F1117),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(cfg: cfg),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Тело ──────────────────────────────────────────────
                  Text(
                    body,
                    style: AppText.regular(fontSize: 13, color: _grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // ── Дата + ответ ───────────────────────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: _grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: AppText.regular(fontSize: 11, color: _grey),
                      ),
                      const Spacer(),
                      if (hasReply)
                        _HasReplyBadge(label: words.appealsHasReply),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
        return '${words.appealsToday} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (diff.inDays == 1) return words.appealsYesterday;
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }

  _StatusCfg _statusCfg(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return _StatusCfg(_red, words.appealsStatusOpen);
      case 'in_progress':
        return _StatusCfg(const Color(0xFFE67E22), words.appealsStatusProgress);
      case 'resolved':
      case 'closed':
        return _StatusCfg(_green, words.appealsStatusClosed);
      default:
        return _StatusCfg(const Color(0xFF9AA3AF), status);
    }
  }
}

// ── Вспомогательные виджеты ───────────────────────────────────────────────────

class _StatusCfg {
  final Color color;
  final String label;
  const _StatusCfg(this.color, this.label);
}

class _StatusBadge extends StatelessWidget {
  final _StatusCfg cfg;
  const _StatusBadge({required this.cfg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: cfg.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            cfg.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cfg.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HasReplyBadge extends StatelessWidget {
  final String label;
  const _HasReplyBadge({required this.label});

  static const _green = Color(0xFF1A7A3C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.reply_rounded, size: 11, color: _green),
          const SizedBox(width: 4),
          Text(label, style: AppText.semiBold(fontSize: 10, color: _green)),
        ],
      ),
    );
  }
}
