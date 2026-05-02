import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/features/auth/phone_screen.dart'; // BaglaLogo
import 'package:flutter/material.dart';
import '../../features/auth/auth_repository.dart';

// Brand shortcuts
const _green = Color(0xFF1A7A3C);
const _red = Color(0xFFD32F1E);
const _brandGradient = LinearGradient(
  colors: [_green, _red],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

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
          _SheetHandle(),
          const SizedBox(height: 20),

          // ── Header ──────────────────────────────────────────────────────
          if (!isClient && !isRestricted) ...[
            Row(
              children: [
                // Gradient icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => _brandGradient.createShader(b),
                      child: Text(
                        'Пополнить баланс',
                        style: AppText.bold(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    Text(
                      '1 жетон = $rate TMT',
                      style: AppText.regular(
                        fontSize: 13,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Thin gradient divider
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: _brandGradient,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Body ────────────────────────────────────────────────────────
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
                  summaryPanel: _SummaryPanel(points: _points, rate: rate),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary panel (extracted widget so it rebuilds cleanly)
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryPanel extends StatelessWidget {
  final int points;
  final int rate;
  const _SummaryPanel({required this.points, required this.rate});

  @override
  Widget build(BuildContext context) {
    final bool active = points > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: active ? _green.withOpacity(0.06) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? _green.withOpacity(0.2) : const Color(0xFFEEF0F3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Итого к оплате',
            style: AppText.regular(fontSize: 15, color: Colors.black54),
          ),
          ShaderMask(
            shaderCallback: (b) =>
                (active
                        ? _brandGradient
                        : const LinearGradient(
                            colors: [Color(0xFF9AA3AF), Color(0xFF9AA3AF)],
                          ))
                    .createShader(b),
            child: Text(
              '${points * rate} TMT',
              style: AppText.extraBold(fontSize: 22, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
