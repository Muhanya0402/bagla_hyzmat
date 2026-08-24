import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class CancelReasonModal extends StatefulWidget {
  final AppLocalizations words;
  final String title;
  final String subtitle;
  final List<ReasonOption> reasons;

  /// Что делать по нажатию. Возвращает `true`, если действие удалось —
  /// тогда модалка закроется. Показ ошибок остаётся на вызывающей стороне:
  /// у отмены магазином и отказа курьера они разные.
  final Future<bool> Function(String reasonId, String comment) onSubmit;

  const CancelReasonModal({
    super.key,
    required this.words,
    required this.title,
    required this.subtitle,
    required this.reasons,
    required this.onSubmit,
  });

  @override
  State<CancelReasonModal> createState() => _CancelReasonModalState();
}

class _CancelReasonModalState extends State<CancelReasonModal> {
  String? _selectedId;
  final _commentCtrl = TextEditingController();
  bool _isLoading = false;

  bool get _isOther => _selectedId == 'other';

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedId == null) return;
    setState(() => _isLoading = true);
    final ok = await widget.onSubmit(_selectedId!, _commentCtrl.text.trim());
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.reasons;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          bottomInset > 0 ? bottomInset + 16 : bottomPadding + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(topPadding: 0),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c.errorMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppText.serif(fontSize: 17, color: c.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1.5),
                  child: Icon(Icons.info_outline_rounded, size: 11, color: c.accent),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.subtitle,
                    style: AppText.regular(fontSize: 12, color: c.inkMuted).copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reasons.asMap().entries.map((entry) {
                    final i = entry.key;
                    final r = entry.value;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i > 0)
                          Container(height: 0.5, color: c.borderSoft),
                        _ReasonTile(
                          reason: r,
                          isSelected: _selectedId == r.id,
                          onTap: () => setState(() => _selectedId = r.id),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _isOther
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: _commentCtrl,
                        maxLines: 3,
                        autofocus: true,
                        style: AppText.regular(fontSize: 14, color: c.ink),
                        decoration: InputDecoration(
                          hintText: widget.words.cancelReasonComment,
                          hintStyle: AppText.regular(fontSize: 13, color: c.inkSoft),
                          filled: true,
                          fillColor: c.bg,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: c.errorMuted.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),

            // ── Actions row ───────────────────────────────────────────────────
            Row(
              children: [
                _BackButton(
                  label: widget.words.back,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ConfirmButton(
                    label: widget.words.cancelOrder,
                    enabled: _selectedId != null,
                    isLoading: _isLoading,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reason tile ───────────────────────────────────────────────────────────────
class _ReasonTile extends StatelessWidget {
  final ReasonOption reason;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        color: isSelected ? c.errorTint : Colors.transparent,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? c.errorMuted : Colors.transparent,
                border: Border.all(
                  color: isSelected ? c.errorMuted : c.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 10)
                  : null,
            ),
            const SizedBox(width: 10),
            Icon(
              reason.icon,
              size: 15,
              color: isSelected ? c.errorMuted : c.inkSoft,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reason.label,
                style: isSelected
                    ? AppText.medium(fontSize: 13, color: c.ink)
                    : AppText.regular(fontSize: 13, color: c.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────
class _BackButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _BackButton({required this.label, required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
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
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppText.medium(fontSize: 13, color: c.inkMuted),
          ),
        ),
      ),
    );
  }
}

// ── Confirm button with spring press ──────────────────────────────────────────
class _ConfirmButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _ConfirmButton({
    required this.label,
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final active = widget.enabled && !widget.isLoading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          decoration: BoxDecoration(
            color: !widget.enabled
                ? c.errorMuted.withValues(alpha: 0.28)
                : widget.isLoading
                ? c.errorMuted.withValues(alpha: 0.5)
                : c.errorMuted,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: c.errorMuted.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  widget.label,
                  style: AppText.semiBold(fontSize: 13, color: Colors.white),
                ),
        ),
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────
class ReasonOption {
  final String id;
  final String label;
  final IconData icon;

  const ReasonOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}
