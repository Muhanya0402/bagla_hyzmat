import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/auth/auth_repository.dart';

class TopUpModal extends StatefulWidget {
  final String userId;
  final String role;
  final String status;

  const TopUpModal({
    super.key,
    required this.userId,
    required this.role,
    required this.status,
  });

  @override
  State<TopUpModal> createState() => _TopUpModalState();
}

class _TopUpModalState extends State<TopUpModal> {
  final TextEditingController _controller = TextEditingController();
  final AuthRepository _authRepo = AuthRepository();

  int _points = 0;
  bool _isLoading = false;
  static const int rate = 2;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final success = await _authRepo.requestTopUp(
      userId: widget.userId,
      points: _points,
      amountTmt: (_points * rate).toDouble(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.role.toLowerCase().trim();
    final String status = widget.status.toLowerCase().trim();

    final bool isClient = role == 'client';
    final bool isRestricted =
        (role == 'shop' || role == 'business' || role == 'courier') &&
        status == 'pending';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          const SizedBox(height: 24),
          isClient
              ? RolePickerEmbedded(onClose: () => Navigator.pop(context))
              : isRestricted
              ? RestrictedAccessView(
                  onActionPressed: () => Navigator.pop(context),
                )
              : TopUpFormView(
                  controller: _controller,
                  points: _points,
                  rate: rate,
                  isLoading: _isLoading,
                  onChanged: (val) =>
                      setState(() => _points = int.tryParse(val) ?? 0),
                  onSubmit: _submit,
                  summaryPanel: _buildSummaryPanel(),
                ),
        ],
      ),
    );
  }

  Widget _buildHandle() => Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: const Color(0xFFE5E7EB),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildSummaryPanel() {
    final bool active = _points > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF27AE60).withOpacity(0.06)
            : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? const Color(0xFF27AE60).withOpacity(0.2)
              : const Color(0xFFEEF0F3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Итого к оплате",
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF1B3A6B),
            ),
          ),
          Text(
            "${_points * rate} TMT",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF27AE60),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Встроенный выбор роли ---
