import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/profile/registration_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/language_provider.dart';
import '../../providers/role_provider.dart';

class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final roleProv = context.watch<RoleProvider>();
    final words = lang.words;
    final bool hasSelection =
        roleProv.selectedRole == 'shop' || roleProv.selectedRole == 'courier';

    return Scaffold(
      backgroundColor: AuthColors.bg,
      appBar: AppBar(
        backgroundColor: AuthColors.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AuthColors.border),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: AuthColors.ink,
              size: 16,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AuthColors.border),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              // ── Заголовок ──────────────────────────────────────────────
              Text(
                words.selectRole,
                style: AppText.serif(fontSize: 30, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                words.roleSubtitle,
                style: AppText.regular(
                  fontSize: 14,
                  color: AuthColors.inkMuted,
                ).copyWith(height: 1.5),
              ),

              const SizedBox(height: 28),

              // ── Карточка: Магазин ──────────────────────────────────────
              _RoleCard(
                title: words.roleClient,
                desc: words.roleClientDesc,
                roleId: 'shop',
                asset: 'assets/images/onboarding/merchant_welcome.png',
                placeholderColor: AuthColors.bannerBg,
                placeholderIcon: Icons.storefront_outlined,
                isSelected: roleProv.selectedRole == 'shop',
                onTap: () => roleProv.selectRole('shop'),
              ),

              const SizedBox(height: 12),

              // ── Карточка: Курьер ───────────────────────────────────────
              _RoleCard(
                title: words.roleCourier,
                desc: words.roleCourierDesc,
                roleId: 'courier',
                asset: 'assets/images/onboarding/courier_welcome.png',
                placeholderColor: const Color(0xFFE6E0D3),
                placeholderIcon: Icons.pedal_bike_outlined,
                isSelected: roleProv.selectedRole == 'courier',
                onTap: () => roleProv.selectRole('courier'),
              ),

              const Spacer(),

              // ── Кнопка подтверждения ───────────────────────────────────
              _ConfirmButton(
                label: words.saveBtn,
                enabled: hasSelection,
                onTap: hasSelection
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegistrationDetailsScreen(
                            role: roleProv.selectedRole,
                          ),
                        ),
                      )
                    : null,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Role card
// ═════════════════════════════════════════════════════════════════════════════

class _RoleCard extends StatefulWidget {
  final String title;
  final String desc;
  final String roleId;
  final String asset;
  final Color placeholderColor;
  final IconData placeholderIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.desc,
    required this.roleId,
    required this.asset,
    required this.placeholderColor,
    required this.placeholderIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected ? AuthColors.ink : AuthColors.borderSoft,
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AuthColors.emerald.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AuthColors.ink.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // ── Изображение ────────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: widget.placeholderColor),
                      Image(
                        image: AssetImage(widget.asset),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(
                            widget.placeholderIcon,
                            size: 30,
                            color: AuthColors.ink.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Текст ──────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        style: AppText.semiBold(
                          fontSize: 15,
                          color: AuthColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.desc,
                        style: AppText.regular(
                          fontSize: 12,
                          color: AuthColors.inkMuted,
                        ).copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Индикатор выбора ───────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AuthColors.ink
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isSelected
                        ? AuthColors.emerald
                        : AuthColors.border,
                    width: 1.5,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Confirm button
// ═════════════════════════════════════════════════════════════════════════════

class _ConfirmButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _ConfirmButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: widget.enabled ? AuthColors.ink : AuthColors.borderSoft,
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: AuthColors.ink.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppText.semiBold(
              fontSize: 15,
              color: widget.enabled ? Colors.white : AuthColors.inkSoft,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
