import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/services/order_service.dart';
import 'package:flutter/material.dart';

class CancelReasonModal extends StatefulWidget {
  final String orderId;
  final String currentUserId;
  final OrderService service;
  final VoidCallback? onSuccess;

  const CancelReasonModal({
    super.key,
    required this.orderId,
    required this.currentUserId,
    required this.service,
    this.onSuccess,
  });

  @override
  State<CancelReasonModal> createState() => _CancelReasonModalState();
}

class _CancelReasonModalState extends State<CancelReasonModal> {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);
  static const _bg = Color(0xFFF5F7FA);
  static const _gradient = LinearGradient(colors: [_green, _red]);

  String? _selectedReason;
  final _commentCtrl = TextEditingController();
  bool _isLoading = false;

  static const _reasons = [
    _ReasonOption(
      id: 'client_refused',
      label: 'Клиент отказался',
      icon: Icons.person_off_outlined,
    ),
    _ReasonOption(
      id: 'courier_late',
      label: 'Доставщик не успел',
      icon: Icons.timer_off_outlined,
    ),
    _ReasonOption(
      id: 'wrong_address',
      label: 'Неверный адрес',
      icon: Icons.location_off_outlined,
    ),
    _ReasonOption(
      id: 'other',
      label: 'Другая причина',
      icon: Icons.help_outline_rounded,
    ),
  ];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    final comment = _commentCtrl.text.trim();
    final fullReason =
        _selectedReason! + (comment.isNotEmpty ? ': $comment' : '');

    setState(() => _isLoading = true);
    await widget.service.updateStatus(
      widget.orderId,
      'canceled',
      cancelReason: fullReason,
      shopId: widget.currentUserId,
    );
    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
    widget.onSuccess?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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

            // Gradient accent bar
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: _gradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Причина отмены',
              style: AppText.bold(fontSize: 17, color: const Color(0xFF0F1117)),
            ),
            const SizedBox(height: 4),
            Text(
              'Выберите причину и добавьте комментарий',
              style: AppText.regular(fontSize: 13, color: _grey),
            ),
            const SizedBox(height: 16),

            // Reason tiles
            ..._reasons.map(
              (r) => _ReasonTile(
                reason: r,
                isSelected: _selectedReason == r.label,
                onTap: () => setState(() => _selectedReason = r.label),
              ),
            ),

            const SizedBox(height: 14),

            // Comment field
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              style: AppText.regular(
                fontSize: 14,
                color: const Color(0xFF0F1117),
              ),
              decoration: InputDecoration(
                hintText: 'Дополнительный комментарий (необязательно)...',
                hintStyle: AppText.regular(fontSize: 13, color: _grey),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _red.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),

            // Buttons row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEEF0F3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Назад',
                        style: AppText.medium(fontSize: 14, color: _grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: (_selectedReason == null || _isLoading)
                        ? null
                        : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 48,
                      decoration: BoxDecoration(
                        color: _selectedReason == null
                            ? _red.withOpacity(0.25)
                            : _red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Отменить заказ',
                              style: AppText.semiBold(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                    ),
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
  final _ReasonOption reason;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _red.withOpacity(0.05) : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _red.withOpacity(0.35) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? _red.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                reason.icon,
                size: 18,
                color: isSelected ? _red : _grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason.label,
                style: isSelected
                    ? AppText.semiBold(fontSize: 14, color: _red)
                    : AppText.regular(
                        fontSize: 14,
                        color: const Color(0xFF0F1117),
                      ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: isSelected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: _red,
                      size: 20,
                      key: ValueKey('check'),
                    )
                  : const SizedBox(width: 20, key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonOption {
  final String id;
  final String label;
  final IconData icon;
  const _ReasonOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}
