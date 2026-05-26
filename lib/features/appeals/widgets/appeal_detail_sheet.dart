import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AppealDetailSheet extends StatelessWidget {
  final dynamic appeal;
  final AppLocalizations words;

  const AppealDetailSheet({
    super.key,
    required this.appeal,
    required this.words,
  });

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);
  static const _gradient = LinearGradient(colors: [_green, _red]);

  @override
  Widget build(BuildContext context) {
    final String subject = (appeal['subject'] ?? words.appealsNoSubject)
        .toString();
    final String body = (appeal['body'] ?? '').toString();
    final String reply = (appeal['reply'] ?? '').toString();
    final String status = (appeal['status'] ?? 'open').toString();
    final String date = _formatDate(appeal['date_created']);
    final bool hasReply = reply.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0F3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Тема + статус ─────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: AppText.bold(
                      fontSize: 17,
                      color: const Color(0xFF0F1117),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(status: status, words: words),
              ],
            ),
            const SizedBox(height: 4),
            Text(date, style: AppText.regular(fontSize: 12, color: _grey)),
            const SizedBox(height: 16),

            // ── Разделитель ───────────────────────────────────────────
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: _gradient,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 16),

            // ── Запрос ────────────────────────────────────────────────
            _SectionLabel(text: words.appealsYourRequest),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEF0F3)),
              ),
              child: Text(
                body,
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                ).copyWith(height: 1.5),
              ),
            ),

            // ── Ответ / ожидание ──────────────────────────────────────
            if (hasReply) ...[
              const SizedBox(height: 20),
              _SectionLabel(text: words.appealsSupportReply),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: _gradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reply,
                        style: AppText.regular(
                          fontSize: 14,
                          color: const Color(0xFF0F1117),
                        ).copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE67E22).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFFE67E22),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      words.appealsWaitingReply,
                      style: AppText.medium(
                        fontSize: 13,
                        color: const Color(0xFFE67E22),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Кнопка закрыть ────────────────────────────────────────
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEEF0F3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  words.notifClose,
                  style: AppText.medium(fontSize: 14, color: _grey),
                ),
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
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ── Вспомогательные виджеты ───────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFF9AA3AF),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final AppLocalizations words;
  const _StatusBadge({required this.status, required this.words});

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'open':
        color = _red;
        label = words.appealsStatusOpen;
        break;
      case 'in_progress':
        color = const Color(0xFFE67E22);
        label = words.appealsStatusProgress;
        break;
      case 'resolved':
      case 'closed':
        color = _green;
        label = words.appealsStatusClosed;
        break;
      default:
        color = _grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
