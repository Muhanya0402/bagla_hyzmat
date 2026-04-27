import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/home_screen.dart';
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
  String? _selectedReason;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  final List<_ReasonOption> _reasons = [
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
      id: 'other',
      label: 'Другая причина',
      icon: Icons.help_outline_rounded,
    ),
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;

    final comment = _commentController.text.trim();
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

    if (mounted) Navigator.pop(context); // сначала закрываем модалку
    if (widget.onSuccess != null) widget.onSuccess!(); // потом колбэк
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
            // Drag handle
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

            Text(
              "Причина отмены",
              style: AppText.semiBold(
                fontSize: 17,
                color: const Color(0xFF0F1117),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Выберите причину и добавьте комментарий",
              style: AppText.regular(
                fontSize: 13,
                color: const Color(0xFF9AA3AF),
              ),
            ),
            const SizedBox(height: 16),

            // Варианты причин
            ..._reasons.map((reason) => _buildReasonTile(reason)),

            const SizedBox(height: 16),

            // Поле комментария
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Дополнительный комментарий (необязательно)...",
                hintStyle: AppText.regular(
                  fontSize: 13,
                  color: const Color(0xFF9AA3AF),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: HomeScreen.brandRed),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),

            // Кнопки
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEEF0F3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text("Назад", style: AppText.medium(fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectedReason == null || _isLoading
                        ? null
                        : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 46,
                      decoration: BoxDecoration(
                        color: _selectedReason == null
                            ? HomeScreen.brandRed.withOpacity(0.3)
                            : HomeScreen.brandRed,
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
                              "Отменить заказ",
                              style: AppText.medium(
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

  Widget _buildReasonTile(_ReasonOption reason) {
    final bool isSelected = _selectedReason == reason.label;
    return GestureDetector(
      onTap: () => setState(() => _selectedReason = reason.label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? HomeScreen.brandRed.withOpacity(0.05)
              : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? HomeScreen.brandRed.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? HomeScreen.brandRed.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                reason.icon,
                size: 18,
                color: isSelected
                    ? HomeScreen.brandRed
                    : const Color(0xFF9AA3AF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason.label,
                style: isSelected
                    ? AppText.semiBold(fontSize: 14, color: HomeScreen.brandRed)
                    : AppText.regular(
                        fontSize: 14,
                        color: const Color(0xFF0F1117),
                      ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: HomeScreen.brandRed,
                size: 20,
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
