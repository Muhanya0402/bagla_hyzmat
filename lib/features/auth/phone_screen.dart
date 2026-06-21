import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/theme/theme_toggle_button.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:smart_auth/smart_auth.dart';

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

  // Cached so dispose() doesn't do an unsafe ancestor lookup via context.read.
  TextEditingController? _phoneCtrl;

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
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 6,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeCtrl);

    final ctrl = context.read<AuthProvider>().phoneController;
    ctrl.clear();
    ctrl.addListener(_onPhoneChanged);
    _phoneCtrl = ctrl;

    // Подставить номер с SIM (Android Phone Number Hint API). Показывает
    // системный шит выбора номера — без READ_PHONE-разрешений.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryPickSimNumber());
  }

  /// Phone Number Hint (Android): системный диалог выбирает номер SIM,
  /// мы подставляем его в поле. На iOS / без Google Play — тихий no-op
  /// (там работает клавиатурный autofill по `autofillHints`).
  Future<void> _tryPickSimNumber() async {
    final ctrl = _phoneCtrl;
    if (ctrl == null || ctrl.text.isNotEmpty) return; // не перетираем ввод
    try {
      final res = await SmartAuth.instance.requestPhoneNumberHint();
      if (!mounted || !res.hasData) return;
      final raw = res.data;
      if (raw == null || raw.isEmpty) return;

      // E.164 (+99365xxxxxx) → 8 цифр номера ТМ.
      var digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith('993')) digits = digits.substring(3);
      if (digits.length > 8) digits = digits.substring(digits.length - 8);
      if (digits.isEmpty) return;

      // Прогоняем через маску `## ## ## ##`, синхронизируя её состояние.
      final formatted = _phoneMask.formatEditUpdate(
        const TextEditingValue(),
        TextEditingValue(
          text: digits,
          selection: TextSelection.collapsed(offset: digits.length),
        ),
      );
      ctrl.value = formatted;
    } catch (_) {
      // нет Play Services / отмена / iOS — игнорируем.
    }
  }

  void _onPhoneChanged() {
    if (_phoneError != null) {
      setState(() => _phoneError = null);
    }
  }

  @override
  void dispose() {
    _phoneCtrl?.removeListener(_onPhoneChanged);
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _shake() {
    HapticFeedback.mediumImpact(); // тактильный фидбек на ошибку
    _shakeCtrl.forward(from: 0);
  }

  /// Допустимые первые цифры мобильного номера Туркменистана (после +993).
  /// Вынесено в константу (A13): при добавлении нового префикса оператором
  /// достаточно поправить здесь, а не искать magic-строки в логике.
  static const _validMobilePrefixes = {'6', '7'};

  bool _isValidPhone(String input) {
    final clean = '+993${input.replaceAll(RegExp(r'\D'), '')}';
    if (clean.length != 12) return false;
    final fourth = clean.substring(4, 5);
    return _validMobilePrefixes.contains(fourth);
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
    final c = AppColors.of(ctx);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: c.bg,
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
    } else if (auth.lastErrorKind == AuthErrorKind.serverBusy) {
      // Номер корректный (прошёл _isValidPhone), но сервер не отправил код.
      // НЕ показываем «не хватает цифр» — это вводит в заблуждение.
      showAuthNetworkBanner(
        context,
        title: words.errorCodeSend,
        message: words.errorCodeSendHint,
      );
    } else {
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
    final c = AppColors.of(context);

    final hasPhoneError = _phoneError != null;

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
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
                            const SizedBox(width: 8),
                            const ThemeToggleIcon(),
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
                            color: c.inkMuted,
                          ).copyWith(height: 1.5, letterSpacing: 0.1),
                        ),

                        const SizedBox(height: 36),

                        // ── Phone field label ──────────────────────────────────────
                        Text(
                          words.authPhoneFieldLabel,
                          style: AppText.medium(
                            fontSize: 12,
                            color: c.inkMuted,
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
                            onTapPolicy: () => _openPolicy(context),
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
                              color: c.inkSoft,
                            ).copyWith(height: 1.4),
                          ),
                        ),

                        const Spacer(flex: 3),
                      ],
                    ),
                  ),
                ),
              ),
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
    final c = AppColors.of(context);
    final borderColor = hasError ? c.errorMuted : c.border;
    final fillColor = hasError ? c.errorTint : c.surface;
    final dividerColor = hasError
        ? c.errorMuted.withValues(alpha: 0.35)
        : c.borderSoft;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.03),
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
                    style: AppText.semiBold(fontSize: 15, color: c.ink),
                  ),
                  // Chevron убран: страна одна (Туркменистан), выбор фейковый.
                  // Вернуть, когда появятся другие страны.
                ],
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              // Нормализатор ДО маски: срезает код страны 993 при массовой
              // вставке (autofill/paste/SIM-hint), оставляя 8 цифр. Обычный
              // посимвольный ввод пропускает без изменений.
              inputFormatters: [const _TmPhoneNormalizer(), formatter],
              // Autofill: система предложит сохранённый номер над клавиатурой.
              autofillHints: const [AutofillHints.telephoneNumberDevice],
              textInputAction: TextInputAction.done,
              style: AppText.medium(
                fontSize: 17,
                color: c.ink,
              ).copyWith(letterSpacing: 0.4),
              cursorColor: hasError ? c.errorMuted : c.ink,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                hintText: '__ __ __ __',
                hintStyle: AppText.regular(
                  fontSize: 17,
                  color: c.inkSoft,
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

/// Срезает код страны Туркменистана (993) при МАССОВОЙ вставке номера
/// (autofill-чип клавиатуры, paste, SIM Phone-Number-Hint), оставляя
/// локальные 8 цифр. Обычный посимвольный ввод (≤8 цифр) пропускается
/// без изменений — его обрабатывает маска `## ## ## ##`.
///
/// Пример: «+99364012282» / «99364012282» → «64012282» → маска «64 01 22 82».
class _TmPhoneNormalizer extends TextInputFormatter {
  const _TmPhoneNormalizer();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Обычный ввод — не трогаем, пусть маска форматирует как раньше.
    if (digits.length <= 8) return newValue;

    var d = digits;
    if (d.startsWith('993')) d = d.substring(3); // код страны
    if (d.length > 8) d = d.substring(d.length - 8); // на всякий случай — хвост
    return TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: d.length),
    );
  }
}

class _PolicyCheckbox extends StatelessWidget {
  final bool accepted;
  final bool hasError;
  final ValueChanged<bool> onChanged;

  /// Один колбэк: оба документа открывают один и тот же PolicyScreen.
  /// Раньше было два визуально раздельных линка (Terms / Privacy),
  /// которые вели в одно место — вводило в заблуждение.
  final VoidCallback onTapPolicy;

  const _PolicyCheckbox({
    required this.accepted,
    required this.hasError,
    required this.onChanged,
    required this.onTapPolicy,
  });

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    final c = AppColors.of(context);

    final boxBorder = accepted
        ? c.ink
        : hasError
        ? c.errorMuted
        : c.border;

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
              color: accepted ? c.ink : c.surface,
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
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                color: c.inkMuted,
                height: 1.55,
              ),
              children: [
                TextSpan(text: words.authPolicyAgreePrefix),
                // Единый подчёркнутый линк: «Условия использования и
                // Политику конфиденциальности» → один PolicyScreen.
                TextSpan(
                  text:
                      '${words.authPolicyTerms}${words.authPolicyAnd}${words.authPolicyPrivacy}',
                  style: TextStyle(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: c.ink,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onTapPolicy,
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
    final c = AppColors.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(topPadding: 0, bottomPadding: 18),
            Text(
              words.authCountryTitle,
              style: AppText.serif(fontSize: 22, letterSpacing: -0.3),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border, width: 1),
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
                          style: AppText.semiBold(fontSize: 15, color: c.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+993',
                          style: AppText.regular(
                            fontSize: 13,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c.ink,
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
                color: c.inkSoft,
              ).copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
