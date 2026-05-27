import 'dart:async';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/core/app_text_styles.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const int _resendDuration = 60;
  static const int _disableMs = 700;

  int _seconds = _resendDuration;
  Timer? _timer;
  DateTime? _backgroundTime;

  // ── Error UX state ───────────────────────────────────────────────────────
  String? _otpError;
  bool _forceError = false; // подсветка через errorPinTheme
  bool _disabled = false; // кнопка временно неактивна после ошибки

  // Горизонтальный shake всего пин-блока
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // несколько мягких качаний влево-вправо
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7, end: 7), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    // Очищаем ошибку при редактировании
    context.read<AuthProvider>().otpController.addListener(_onOtpChanged);
  }

  void _onOtpChanged() {
    // Сбрасываем сообщение об ошибке ТОЛЬКО когда пользователь начинает
    // вводить новый код. Программный clear() после shake'а оставляет
    // text='' — на него реагировать нельзя, иначе текст исчезнет мгновенно.
    final text = context.read<AuthProvider>().otpController.text;
    if (text.isNotEmpty && (_otpError != null || _forceError)) {
      setState(() {
        _otpError = null;
        _forceError = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundTime = DateTime.now();
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTime != null && _seconds > 0) {
        final elapsed = DateTime.now().difference(_backgroundTime!).inSeconds;
        final remaining = _seconds - elapsed;
        setState(() => _seconds = remaining > 0 ? remaining : 0);
        _backgroundTime = null;
        if (_seconds > 0) _tickAfterResume();
      }
    }
  }

  void _tickAfterResume() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds == 0) {
        _timer?.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = _resendDuration);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds == 0) {
        _timer?.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    context.read<AuthProvider>().otpController.removeListener(_onOtpChanged);
    WidgetsBinding.instance.removeObserver(this);
    _shakeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _onVerify({required bool fromAutoComplete}) async {
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();
    final words = lang.words;

    // Если ручной submit, но пина ещё нет — игнор
    if (!fromAutoComplete && auth.otpController.text.length < 4) return;
    if (_disabled) return;

    final ok = await auth.verifyOtpAndLogin(context, lang, silent: true);

    if (!mounted) return;

    if (ok) return; // успешно — навигация внутри AuthProvider

    // ── Ошибка ────────────────────────────────────────────────────────────
    if (auth.lastErrorKind == AuthErrorKind.network) {
      showAuthNetworkBanner(
        context,
        title: words.errNetworkTitle,
        message: words.errNetwork,
      );
      return;
    }

    // Неверный код: shake + inline + temporary disable
    setState(() {
      _otpError = words.errOtpInvalid;
      _forceError = true;
      _disabled = true;
    });
    _shakeCtrl.forward(from: 0);

    // После shake'а: чистим ячейки и убираем красный фон,
    // НО оставляем _otpError видимым — он пропадёт, когда пользователь
    // начнёт вводить новый код (см. _onOtpChanged).
    Future.delayed(const Duration(milliseconds: 480), () {
      if (!mounted) return;
      auth.otpController.clear();
      setState(() => _forceError = false);
    });

    Future.delayed(const Duration(milliseconds: _disableMs), () {
      if (!mounted) return;
      setState(() => _disabled = false);
    });
  }

  Future<void> _onResend(
    AuthProvider auth,
    LanguageProvider lang,
    dynamic words,
  ) async {
    await auth.sendOTPOnly(context, lang, silent: true);
    if (!mounted) return;
    if (auth.lastErrorKind == AuthErrorKind.network) {
      showAuthNetworkBanner(
        context,
        title: words.errNetworkTitle,
        message: words.errNetwork,
      );
    } else {
      _startTimer();
    }
  }

  // ── Pin themes — минимальные «карточки бумаги», серифные цифры ──────────
  PinTheme get _defaultTheme => PinTheme(
        width: 56,
        height: 64,
        textStyle: AppText.serif(fontSize: 26, letterSpacing: 0),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AuthColors.border, width: 1),
        ),
      );

  PinTheme get _focusedTheme => _defaultTheme.copyWith(
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AuthColors.ink, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AuthColors.ink.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      );

  PinTheme get _submittedTheme => _defaultTheme.copyWith(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F0E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AuthColors.accent, width: 1),
        ),
      );

  // Muted terracotta вместо неонового красного.
  PinTheme get _errorTheme => _defaultTheme.copyWith(
        textStyle: AppText.serif(
          fontSize: 26,
          letterSpacing: 0,
          color: AuthColors.errorMuted,
        ),
        decoration: BoxDecoration(
          color: AuthColors.errorTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AuthColors.errorMuted, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final isLoading = context.select<AuthProvider, bool>((a) => a.isLoading);

    final buttonDisabled = _disabled || isLoading;

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
                    const AuthBackButton(),
                    const Spacer(),
                    const BaglaLogo(width: 56, height: 28),
                    const Spacer(),
                    AuthLangSwitcher(
                      isRu: lang.isRu,
                      onToggle: lang.toggleLanguage,
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // ── Title (calm serif) ─────────────────────────────────────
                Text(
                  words.authOtpTitle,
                  style: AppText.serif(fontSize: 34),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: AppText.regular(
                      fontSize: 14.5,
                      color: AuthColors.inkMuted,
                    ).copyWith(height: 1.5, letterSpacing: 0.1),
                    children: [
                      TextSpan(text: words.authOtpSubtitle),
                      TextSpan(
                        text: auth.phoneController.text.isNotEmpty
                            ? '+993 ${auth.phoneController.text}'
                            : '+993 6X XX XX XX',
                        style: const TextStyle(
                          color: AuthColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Pinput (горизонтальный shake при ошибке) ───────────────
                Center(
                  child: AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(_shakeAnim.value, 0),
                      child: child,
                    ),
                    child: Pinput(
                      length: 4,
                      controller: auth.otpController,
                      defaultPinTheme: _defaultTheme,
                      focusedPinTheme: _focusedTheme,
                      submittedPinTheme: _submittedTheme,
                      errorPinTheme: _errorTheme,
                      forceErrorState: _forceError,
                      separatorBuilder: (_) => const SizedBox(width: 12),
                      showCursor: true,
                      cursor: Container(
                        width: 1.5,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AuthColors.ink,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      onCompleted: (_) =>
                          _onVerify(fromAutoComplete: true),
                    ),
                  ),
                ),

                // ── Inline error message ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AuthInlineError(message: _otpError),
                ),

                const SizedBox(height: 20),

                // ── Timer / Resend (минимальный inline) ────────────────────
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _seconds > 0
                        ? _SubtleTimer(
                            seconds: _seconds,
                            key: const ValueKey('timer'),
                          )
                        : _ResendLink(
                            key: const ValueKey('resend'),
                            onPressed: () => _onResend(auth, lang, words),
                          ),
                  ),
                ),

                const Spacer(flex: 3),

                // ── Confirm button ─────────────────────────────────────────
                AuthGradientButton(
                  label: words.authConfirmBtn,
                  isLoading: isLoading,
                  enabled: !buttonDisabled,
                  onPressed: () => _onVerify(fromAutoComplete: false),
                ),

                const SizedBox(height: 28),
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

class _SubtleTimer extends StatelessWidget {
  final int seconds;
  const _SubtleTimer({required this.seconds, super.key});

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    final mm = '0:${seconds.toString().padLeft(2, '0')}';

    return RichText(
      text: TextSpan(
        style: AppText.regular(
          fontSize: 13.5,
          color: AuthColors.inkSoft,
        ).copyWith(height: 1.4, letterSpacing: 0.1),
        children: [
          TextSpan(text: words.authOtpResendInPrefix),
          TextSpan(
            text: mm,
            style: const TextStyle(
              color: AuthColors.ink,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResendLink extends StatelessWidget {
  final VoidCallback onPressed;
  const _ResendLink({required this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          words.authOtpResendLink,
          style: AppText.semiBold(
            fontSize: 13.5,
            color: AuthColors.ink,
          ).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: AuthColors.ink,
            decorationThickness: 1.2,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
