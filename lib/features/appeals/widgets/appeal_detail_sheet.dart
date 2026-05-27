import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/auth_constants.dart';
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

  @override
  Widget build(BuildContext context) {
    final String subject =
        (appeal['subject'] ?? words.appealsNoSubject).toString();
    final String body = (appeal['body'] ?? '').toString();
    final String reply = (appeal['reply'] ?? '').toString();
    final String status = (appeal['status'] ?? 'open').toString();
    final String date = _formatDate(appeal['date_created']);
    final bool hasReply = reply.isNotEmpty;
    final cfg = _statusCfg(status);

    return Container(
      decoration: const BoxDecoration(
        color: AuthColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──────────────────────────────────────────────────
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
            const SizedBox(height: 18),

            // ── Subject + status ─────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: AppText.serif(fontSize: 18, letterSpacing: -0.2),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(cfg: cfg),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 11,
                  color: AuthColors.inkSoft,
                ),
                const SizedBox(width: 5),
                Text(
                  date,
                  style: AppText.regular(
                    fontSize: 12,
                    color: AuthColors.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Divider ──────────────────────────────────────────────────
            Container(height: 0.5, color: AuthColors.border),
            const SizedBox(height: 16),

            // ── Your request ─────────────────────────────────────────────
            _SectionLabel(text: words.appealsYourRequest),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuthColors.border),
              ),
              child: Text(
                body,
                style: AppText.regular(
                  fontSize: 14,
                  color: AuthColors.ink,
                ).copyWith(height: 1.5),
              ),
            ),

            // ── Reply / waiting ──────────────────────────────────────────
            if (hasReply) ...[
              const SizedBox(height: 18),
              _SectionLabel(text: words.appealsSupportReply),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AuthColors.emeraldTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AuthColors.emerald.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AuthColors.emerald,
                        borderRadius: BorderRadius.circular(9),
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
                          color: AuthColors.ink,
                        ).copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AuthColors.amberTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AuthColors.amber.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: AuthColors.amber,
                      size: 15,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      words.appealsWaitingReply,
                      style: AppText.medium(
                        fontSize: 13,
                        color: AuthColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Close button ─────────────────────────────────────────────
            const SizedBox(height: 18),
            _CloseButton(
              label: words.notifClose,
              onTap: () => Navigator.pop(context),
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
      return '${dt.day.toString().padLeft(2, '0')}.'
          '${dt.month.toString().padLeft(2, '0')}.'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  _StatusCfg _statusCfg(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return _StatusCfg(
          accent: AuthColors.amber,
          bg: AuthColors.amberTint,
          text: AuthColors.amber,
          label: words.appealsStatusOpen,
        );
      case 'in_progress':
        return _StatusCfg(
          accent: AuthColors.amber,
          bg: AuthColors.amberTint,
          text: AuthColors.amber,
          label: words.appealsStatusProgress,
        );
      case 'resolved':
      case 'closed':
        return _StatusCfg(
          accent: AuthColors.emerald,
          bg: AuthColors.emeraldTint,
          text: AuthColors.emerald,
          label: words.appealsStatusClosed,
        );
      default:
        return _StatusCfg(
          accent: AuthColors.inkSoft,
          bg: AuthColors.borderSoft,
          text: AuthColors.inkSoft,
          label: status,
        );
    }
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 10,
          decoration: BoxDecoration(
            color: AuthColors.emerald,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: AppText.semiBold(
            fontSize: 10,
            color: AuthColors.inkSoft,
          ).copyWith(letterSpacing: 0.8),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _StatusCfg cfg;
  const _StatusBadge({required this.cfg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            style: AppText.semiBold(fontSize: 11, color: cfg.text),
          ),
        ],
      ),
    );
  }
}

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
          height: 50,
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AuthColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppText.medium(
              fontSize: 14,
              color: AuthColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
