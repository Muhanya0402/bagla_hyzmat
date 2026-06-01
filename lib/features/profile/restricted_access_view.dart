import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/point_icon.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand constants (local, no external import needed)
// ─────────────────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF1A7A3C);
const _kRed = Color(0xFFD32F1E);
const _kGrey = Color(0xFF9AA3AF);
const _kBg = Color(0xFFF5F7FA);
const _kBorder = Color(0xFFEEF0F3);
const _kGradient = LinearGradient(colors: [_kGreen, _kRed]);

// ─────────────────────────────────────────────────────────────────────────────
// RestrictedAccessView — shown when account is under moderation
// ─────────────────────────────────────────────────────────────────────────────

class RestrictedAccessView extends StatelessWidget {
  final VoidCallback onActionPressed;
  final VoidCallback? onSignOut;
  /// Если null — используются локализованные дефолты из l10n.
  final String? title;
  final String? message;
  final String? buttonText;
  final String? statusHint;

  const RestrictedAccessView({
    super.key,
    required this.onActionPressed,
    this.onSignOut,
    this.title,
    this.message,
    this.buttonText,
    this.statusHint,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
    // Дефолты резолвятся из l10n — runtime, не const.
    final t = title ?? words.restrictedDefaultTitle;
    final m = message ?? words.restrictedDefaultMessage;
    final b = buttonText ?? words.restrictedDefaultButton;
    final h = statusHint ?? words.restrictedDefaultStatusHint;
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.errorTint,
                  ),
                  child: Icon(
                    Icons.lock_person_outlined,
                    size: 26,
                    color: c.errorMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t,
                  textAlign: TextAlign.center,
                  style: AppText.serif(fontSize: 17, color: c.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  m,
                  textAlign: TextAlign.center,
                  style: AppText.regular(fontSize: 13, color: c.inkMuted).copyWith(height: 1.55),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.bannerBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.bannerBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 13, color: c.amber),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          h,
                          style: AppText.medium(fontSize: 12, color: c.amber),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(height: 0.5, color: c.borderSoft),
                const SizedBox(height: 16),
                _ActionButton(label: b, onTap: onActionPressed),
              ],
            ),
          ),

          // ── Secondary: sign out ──────────────────────────────────────────
          if (onSignOut != null) ...[
            const SizedBox(height: 12),
            _SignOutButton(onTap: onSignOut!),
          ],
        ],
      ),
    );
  }
}

// ─── _ActionButton ────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _pressed ? c.ink.withValues(alpha: 0.82) : c.ink,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _pressed
                ? null
                : [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppText.semiBold(fontSize: 13, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ─── _SignOutButton ───────────────────────────────────────────────────────────

class _SignOutButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SignOutButton({required this.onTap});

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
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
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 140),
            style: AppText.medium(
              fontSize: 13,
              color: _pressed ? AppColors.of(context).errorMuted : AppColors.of(context).inkSoft,
            ),
            child: Text(
              context.watch<LanguageProvider>().words.restrictedSignOut,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TopUpFormView — active top-up form
// ─────────────────────────────────────────────────────────────────────────────

class TopUpFormView extends StatelessWidget {
  final TextEditingController controller;
  final int points;
  final double rate;
  final bool isLoading;
  final Function(String) onChanged;
  final VoidCallback onSubmit;
  final Widget summaryPanel;

  const TopUpFormView({
    super.key,
    required this.controller,
    required this.points,
    required this.rate,
    required this.isLoading,
    required this.onChanged,
    required this.onSubmit,
    required this.summaryPanel,
  });

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = points > 0 && !isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // Gradient accent bar
        Container(
          height: 3,
          width: 48,
          decoration: BoxDecoration(
            gradient: _kGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        // Amount field
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppText.extraBold(
            fontSize: 28,
            color: const Color(0xFF0F1117),
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: AppText.regular(
              fontSize: 28,
              color: const Color(0xFFD1D5DB),
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.all(8),
              child: PointIcon(size: 28),
            ),
            suffixText: 'жетонов',
            suffixStyle: AppText.regular(fontSize: 14, color: _kGrey),
            filled: true,
            fillColor: _kBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _kGreen.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),

        // Rate hint
        Text(
          '1 жетон = $rate TMT',
          style: AppText.regular(fontSize: 18, color: _kGreen),
        ),
        const SizedBox(height: 20),

        // Summary panel (passed from parent)
        summaryPanel,

        const SizedBox(height: 24),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: canSubmit ? _kGradient : null,
              color: canSubmit ? null : _kBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: canSubmit
                  ? [
                      BoxShadow(
                        color: _kGreen.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: canSubmit ? onSubmit : null,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: _kGreen,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'ПОПОЛНИТЬ',
                      style: AppText.bold(
                        fontSize: 14,
                        color: canSubmit ? Colors.white : _kGrey,
                      ).copyWith(letterSpacing: 0.5),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
