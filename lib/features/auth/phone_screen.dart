import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
import 'package:bagla/features/profile/lang_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/otp_screen.dart';
import 'package:bagla/features/auth/policy_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

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
                  BaglaLogo(width: 72, height: 36),
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
                    _GradientUnderlineTitle(accentWord: words.welcomeToApp),
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
              AuthGradientButton(
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

class _GradientUnderlineTitle extends StatelessWidget {
  final String accentWord;
  const _GradientUnderlineTitle({required this.accentWord});

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
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: ShaderMask(
            shaderCallback: (b) => AuthColors.gradient.createShader(
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
        border: Border.all(color: AuthColors.green, width: 1.5),
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
                hintText: '__ ___ ___',
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
          left: BorderSide(color: AuthColors.green, width: 3),
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
                color: accepted ? AuthColors.green : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accepted ? AuthColors.green : Colors.black26,
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
                      color: AuthColors.green,
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
                      color: AuthColors.red,
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
