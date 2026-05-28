import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

// ─── Логотип ──────────────────────────────────────────────────────────────────

class BaglaLogo extends StatelessWidget {
  final double width;
  final double height;

  const BaglaLogo({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/bagla_logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

// ─── Кнопка назад ─────────────────────────────────────────────────────────────

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: Icon(Icons.arrow_back_ios_new, size: 14, color: c.ink),
      ),
    );
  }
}

// ─── Переключатель языка ──────────────────────────────────────────────────────

class AuthLangSwitcher extends StatelessWidget {
  final bool isRu;
  final VoidCallback onToggle;

  const AuthLangSwitcher({
    super.key,
    required this.isRu,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangTab(label: 'RU', active: isRu),
            _LangTab(label: 'TK', active: !isRu),
          ],
        ),
      ),
    );
  }
}

class _LangTab extends StatelessWidget {
  final String label;
  final bool active;

  const _LangTab({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      decoration: BoxDecoration(
        color: active ? c.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : c.inkMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Основная кнопка ──────────────────────────────────────────────────────────

class AuthGradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  const AuthGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bool active = enabled && !isLoading;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: active
            ? [
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.05),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : const [],
      ),
      child: ElevatedButton(
        onPressed: active ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? c.ink : c.border,
          disabledBackgroundColor: c.border,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : c.inkMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.5,
                  letterSpacing: 0.1,
                  fontFamily: 'Nunito',
                ),
              ),
      ),
    );
  }
}

// ─── Inline error text (под полем) ────────────────────────────────────────────

class AuthInlineError extends StatelessWidget {
  /// Если null — слот сворачивается без рывка (через AnimatedSize+Switcher).
  final String? message;
  const AuthInlineError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.1),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: message == null
            ? const SizedBox(width: double.infinity, key: ValueKey('none'))
            : Padding(
                key: ValueKey(message),
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: c.errorMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message!,
                        style: AppText.regular(
                          fontSize: 12.5,
                          color: c.errorMuted,
                        ).copyWith(height: 1.5, letterSpacing: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Top-toast: «Нет соединения» / сетевая ошибка ─────────────────────────────

/// Мягкий top-banner, спускается сверху. Auto-dismiss через [duration]
/// (по умолчанию 5с) либо по тапу.
void showAuthNetworkBanner(
  BuildContext context, {
  required String title,
  required String message,
  Duration duration = const Duration(seconds: 5),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  final controller = _BannerController();

  entry = OverlayEntry(
    builder: (ctx) => _AuthNetworkBanner(
      title: title,
      message: message,
      controller: controller,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);

  Future.delayed(duration, () {
    if (controller.isMounted) controller.hide();
  });
}

class _BannerController {
  VoidCallback? _hide;
  bool isMounted = false;
  void hide() => _hide?.call();
}

class _AuthNetworkBanner extends StatefulWidget {
  final String title;
  final String message;
  final _BannerController controller;
  final VoidCallback onDismissed;

  const _AuthNetworkBanner({
    required this.title,
    required this.message,
    required this.controller,
    required this.onDismissed,
  });

  @override
  State<_AuthNetworkBanner> createState() => _AuthNetworkBannerState();
}

class _AuthNetworkBannerState extends State<_AuthNetworkBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    widget.controller
      ..isMounted = true
      .._hide = _animateOut;

    _ctrl.forward();
  }

  Future<void> _animateOut() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.controller.isMounted = false;
    widget.onDismissed();
  }

  @override
  void dispose() {
    widget.controller.isMounted = false;
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final top = MediaQuery.of(context).padding.top + 8;
    return Positioned(
      left: 16,
      right: 16,
      top: top,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _animateOut,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: c.bannerBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.bannerBorder, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: c.bannerBorder, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.wifi_off_rounded,
                        size: 15,
                        color: c.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: AppText.semiBold(
                              fontSize: 13.5,
                              color: c.ink,
                            ).copyWith(letterSpacing: 0.1),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.message,
                            style: AppText.regular(
                              fontSize: 12.5,
                              color: c.inkMuted,
                            ).copyWith(height: 1.4, letterSpacing: 0.1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: c.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
