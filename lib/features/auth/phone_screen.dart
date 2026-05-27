import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
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
    mask: '## ## ## ##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool _policyAccepted = false;

  // ── Empathic error state ─────────────────────────────────────────────────
  String? _phoneError;
  String? _policyError;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 6)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeCtrl);

    // Стартуем с пустого поля — не подтягиваем номер из прошлой сессии.
    final ctrl = context.read<AuthProvider>().phoneController;
    ctrl.clear();
    ctrl.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    if (_phoneError != null) {
      setState(() => _phoneError = null);
    }
  }

  @override
  void dispose() {
    context
        .read<AuthProvider>()
        .phoneController
        .removeListener(_onPhoneChanged);
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
          onAccepted: () => setState(() {
            _policyAccepted = true;
            _policyError = null;
          }),
        ),
      ),
    );
  }

  void _openCountryPicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AuthColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CountrySheet(),
    );
  }

  Future<void> _onSubmit() async {
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();
    final words = lang.words;

    // 1. policy
    if (!_policyAccepted) {
      setState(() => _policyError = words.errPolicyRequired);
      _shake();
      return;
    }

    // 2. phone format
    if (!_isValidPhone(auth.phoneController.text)) {
      setState(() => _phoneError = words.errPhoneFormat);
      _shake();
      return;
    }

    // 3. API (silent — экран сам отрисует ошибку)
    final ok = await auth.sendOTPOnly(context, lang, silent: true);

    if (!mounted) return;

    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OtpScreen()),
      );
      return;
    }

    // 4. API failed — определяем причину
    if (auth.lastErrorKind == AuthErrorKind.network) {
      showAuthNetworkBanner(
        context,
        title: words.errNetworkTitle,
        message: words.errNetwork,
      );
    } else {
      // server отказал — показываем рядом с полем
      setState(() => _phoneError = words.errPhoneFormat);
      _shake();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final isLoading = context.select<AuthProvider, bool>((a) => a.isLoading);

    final hasPhoneError = _phoneError != null;

    return Scaffold(
      backgroundColor: AuthColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ────────────────────────────────────────────────
                const SizedBox(height: 18),
                Row(
                  children: [
                    const BaglaLogo(width: 64, height: 32),
                    const Spacer(),
                    AuthLangSwitcher(
                      isRu: lang.isRu,
                      onToggle: lang.toggleLanguage,
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // ── Title (serif, editorial) ───────────────────────────────
                Text(
                  words.authPhoneTitle,
                  style: AppText.serif(fontSize: 34),
                ),
                const SizedBox(height: 12),
                Text(
                  words.authPhoneSubtitle,
                  style: AppText.regular(
                    fontSize: 14.5,
                    color: AuthColors.inkMuted,
                  ).copyWith(height: 1.5, letterSpacing: 0.1),
                ),

                const SizedBox(height: 36),

                // ── Phone field label ──────────────────────────────────────
                Text(
                  words.authPhoneFieldLabel,
                  style: AppText.medium(
                    fontSize: 12,
                    color: AuthColors.inkMuted,
                  ).copyWith(letterSpacing: 0.3),
                ),
                const SizedBox(height: 8),

                // ── Phone field + inline error ─────────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: _PhoneField(
                    controller: auth.phoneController,
                    formatter: _phoneMask,
                    hasError: hasPhoneError,
                    onTapCountry: () => _openCountryPicker(context),
                  ),
                ),
                AuthInlineError(message: _phoneError),

                const SizedBox(height: 18),

                // ── Policy checkbox + inline error ─────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: _PolicyCheckbox(
                    accepted: _policyAccepted,
                    hasError: _policyError != null,
                    onChanged: (v) => setState(() {
                      _policyAccepted = v;
                      if (v) _policyError = null;
                    }),
                    onTapTerms: () => _openPolicy(context),
                    onTapPrivacy: () => _openPolicy(context),
                  ),
                ),
                AuthInlineError(message: _policyError),

                const SizedBox(height: 28),

                // ── Submit button ──────────────────────────────────────────
                AuthGradientButton(
                  label: words.authSendCodeBtn,
                  isLoading: isLoading,
                  onPressed: _onSubmit,
                ),

                const SizedBox(height: 18),

                // ── Edge note ──────────────────────────────────────────────
                Center(
                  child: Text(
                    words.authSmsConsent,
                    textAlign: TextAlign.center,
                    style: AppText.regular(
                      fontSize: 11.5,
                      color: AuthColors.inkSoft,
                    ).copyWith(height: 1.4),
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Private widgets
// ═════════════════════════════════════════════════════════════════════════════

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final MaskTextInputFormatter formatter;
  final VoidCallback onTapCountry;
  final bool hasError;

  const _PhoneField({
    required this.controller,
    required this.formatter,
    required this.onTapCountry,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        hasError ? AuthColors.errorMuted : AuthColors.border;
    final fillColor = hasError ? AuthColors.errorTint : AuthColors.surface;
    final dividerColor =
        hasError ? AuthColors.errorMuted.withValues(alpha: 0.35) : AuthColors.borderSoft;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AuthColors.ink.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTapCountry,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
              height: 58,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: dividerColor, width: 1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇹🇲', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    '+993',
                    style: AppText.semiBold(
                      fontSize: 15,
                      color: AuthColors.ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AuthColors.inkMuted,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [formatter],
              style: AppText.medium(fontSize: 17, color: AuthColors.ink)
                  .copyWith(letterSpacing: 0.4),
              cursorColor: hasError ? AuthColors.errorMuted : AuthColors.ink,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                hintText: '__ __ __ __',
                hintStyle: AppText.regular(
                  fontSize: 17,
                  color: AuthColors.inkSoft,
                ).copyWith(letterSpacing: 0.4),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
  final bool hasError;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;

  const _PolicyCheckbox({
    required this.accepted,
    required this.hasError,
    required this.onChanged,
    required this.onTapTerms,
    required this.onTapPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;

    final boxBorder = accepted
        ? AuthColors.ink
        : hasError
            ? AuthColors.errorMuted
            : AuthColors.border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onChanged(!accepted),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: accepted ? AuthColors.ink : AuthColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: boxBorder, width: 1.2),
            ),
            child: accepted
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                color: AuthColors.inkMuted,
                height: 1.55,
              ),
              children: [
                TextSpan(text: words.authPolicyAgreePrefix),
                TextSpan(
                  text: words.authPolicyTerms,
                  style: const TextStyle(
                    color: AuthColors.ink,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AuthColors.ink,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onTapTerms,
                ),
                TextSpan(text: words.authPolicyAnd),
                TextSpan(
                  text: words.authPolicyPrivacy,
                  style: const TextStyle(
                    color: AuthColors.ink,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AuthColors.ink,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onTapPrivacy,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Country picker (single item, готов к расширению) ───────────────────────
class _CountrySheet extends StatelessWidget {
  const _CountrySheet();

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AuthColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              words.authCountryTitle,
              style: AppText.serif(fontSize: 22, letterSpacing: -0.3),
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AuthColors.border, width: 1),
              ),
              child: Row(
                children: [
                  const Text('🇹🇲', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          words.authCountryTurkmenistan,
                          style: AppText.semiBold(
                            fontSize: 15,
                            color: AuthColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+993',
                          style: AppText.regular(
                            fontSize: 13,
                            color: AuthColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AuthColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              words.authCountryAvailability,
              style: AppText.regular(
                fontSize: 12,
                color: AuthColors.inkSoft,
              ).copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
