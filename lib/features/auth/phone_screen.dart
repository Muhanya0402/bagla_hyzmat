import 'dart:async';
import 'package:bagla/features/profile/lang_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/otp_screen.dart';
import 'package:bagla/features/auth/policy_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandGreen, brandRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  final _phoneMask = MaskTextInputFormatter(
    mask: '########',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool _policyAccepted = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 8,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _shake() => _shakeCtrl.forward(from: 0);

  bool _isValidPhone(String input) {
    final clean = '+993${input.replaceAll(RegExp(r'\D'), '')}';
    if (clean.length != 12) return false;
    final fourth = clean.substring(4, 5);
    return fourth == '6' || fourth == '7';
  }

  void _openPolicy(BuildContext ctx) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => PolicyScreen(
          onAccepted: () => setState(() => _policyAccepted = true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final isLoading = context.select<AuthProvider, bool>((a) => a.isLoading);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────────
              const SizedBox(height: 16),
              Row(
                children: [
                  const BaglaLogo(width: 72, height: 36),
                  const Spacer(),
                  const LangToggle(),
                ],
              ),

              const Spacer(),

              // ── Title ────────────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GradientUnderlineTitle(
                      accentWord: lang.isRu ? 'Войдите' : 'Giriň',
                      rest: lang.isRu ? ' в\nприложение' : ' programmä',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lang.isRu
                          ? 'Введите номер — отправим SMS-код для входа'
                          : 'Belgini giriziň — SMS kody ibereris',
                      style: AppText.regular(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Phone field ──────────────────────────────────────────────
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: _PhoneField(
                  controller: auth.phoneController,
                  formatter: _phoneMask,
                ),
              ),

              const SizedBox(height: 14),

              // ── Policy checkbox ──────────────────────────────────────────
              _PolicyCheckbox(
                accepted: _policyAccepted,
                isRu: lang.isRu,
                onChanged: (v) => setState(() => _policyAccepted = v),
                onTapTerms: () => _openPolicy(context),
                onTapPrivacy: () => _openPolicy(context),
              ),

              const SizedBox(height: 22),

              // ── Submit button ────────────────────────────────────────────
              _GradientButton(
                label: words.getCodeBtn.toUpperCase(),
                isLoading: isLoading,
                onPressed: () async {
                  if (!_policyAccepted) {
                    _shake();
                    return;
                  }
                  if (!_isValidPhone(auth.phoneController.text)) {
                    _shake();
                    return;
                  }
                  final ok = await auth.sendOTPOnly(context, lang);
                  if (ok && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OtpScreen()),
                    );
                  } else {
                    _shake();
                  }
                },
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Language Switcher
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
//  BaglaLogo — exported, reused in OtpScreen & PolicyScreen
// ─────────────────────────────────────────────────────────────────────────────

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
      fit: BoxFit.contain, // важно чтобы не обрезалось
    );
  }
}

class _LogoPainter extends CustomPainter {
  static const _green = Color(0xFF1A7A3C);
  static const _mid = Color(0xFF8B4A20);
  static const _red = Color(0xFFD32F1E);

  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width;
    final h = sz.height;
    final sw = h * 0.155;

    Shader grad(double x0, double x1) => const LinearGradient(
      colors: [_green, _mid, _red],
      stops: [0.0, 0.48, 1.0],
    ).createShader(Rect.fromLTWH(x0, 0, x1 - x0, h));

    final loopPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..shader = grad(0, w);

    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.3, h * 0.5), radius: h * 0.355),
      -2.9,
      5.5,
      false,
      loopPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.7, h * 0.5), radius: h * 0.355),
      0.24,
      5.5,
      false,
      loopPaint,
    );

    final cy = h * 0.5;
    final ah = h * 0.27;

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.32 + ah * 0.6, cy - ah)
        ..lineTo(w * 0.32 - ah * 0.3, cy)
        ..lineTo(w * 0.32 + ah * 0.6, cy + ah),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 0.88
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = grad(0, w * 0.5),
    );

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.68 - ah * 0.6, cy - ah)
        ..lineTo(w * 0.68 + ah * 0.3, cy)
        ..lineTo(w * 0.68 - ah * 0.6, cy + ah),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 0.88
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = grad(w * 0.5, w),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _GradientUnderlineTitle extends StatelessWidget {
  final String accentWord;
  final String rest;
  const _GradientUnderlineTitle({required this.accentWord, required this.rest});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: accentWord,
                style: AppText.bold(fontSize: 26, color: Colors.black),
              ),
              TextSpan(
                text: rest,
                style: AppText.bold(fontSize: 26, color: Colors.black),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: ShaderMask(
            shaderCallback: (b) => PhoneScreen.brandGradient.createShader(
              Rect.fromLTWH(0, 0, b.width, 3),
            ),
            child: Container(
              width: accentWord.length * 14.8,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final MaskTextInputFormatter formatter;
  const _PhoneField({required this.controller, required this.formatter});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: PhoneScreen.brandGreen, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            height: 52,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🇹🇲', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(
                  '+993',
                  style: AppText.semiBold(fontSize: 13, color: Colors.black45),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [formatter],
              style: AppText.semiBold(fontSize: 17),
              decoration: const InputDecoration(
                hintText: '6_ ___ ___',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCheckbox extends StatelessWidget {
  final bool accepted;
  final bool isRu;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;

  const _PolicyCheckbox({
    required this.accepted,
    required this.isRu,
    required this.onChanged,
    required this.onTapTerms,
    required this.onTapPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: PhoneScreen.brandGreen, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onChanged(!accepted),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: accepted ? PhoneScreen.brandGreen : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accepted ? PhoneScreen.brandGreen : Colors.black26,
                  width: 1.5,
                ),
              ),
              child: accepted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.55,
                ),
                children: [
                  TextSpan(text: isRu ? 'Соглашаюсь с ' : 'Ylalaşýaryn: '),
                  TextSpan(
                    text: isRu ? 'Условиями использования' : 'Ulanyş şertleri',
                    style: const TextStyle(
                      color: PhoneScreen.brandGreen,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = onTapTerms,
                  ),
                  TextSpan(text: isRu ? ' и ' : ' we '),
                  TextSpan(
                    text: isRu
                        ? 'Политикой конфиденциальности'
                        : 'Gizlinlik syýasaty',
                    style: const TextStyle(
                      color: PhoneScreen.brandRed,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = onTapPrivacy,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isLoading ? null : PhoneScreen.brandGradient,
          color: isLoading ? Colors.black12 : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
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
                ),
        ),
      ),
    );
  }
}
