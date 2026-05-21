import 'package:bagla/features/auth/auth_constants.dart';
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
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          size: 16,
          color: Colors.black87,
        ),
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
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.black12),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: active ? AuthColors.gradient : null,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: active ? Colors.white : Colors.black38,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Градиентная кнопка ───────────────────────────────────────────────────────

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
    final bool active = enabled && !isLoading;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: active ? AuthColors.gradient : null,
          color: active ? null : Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: active ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.black38,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
