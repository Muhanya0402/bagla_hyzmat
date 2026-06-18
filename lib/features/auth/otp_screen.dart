import 'dart:async';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/theme/theme_toggle_button.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';
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

  // Кэшируем ссылку в initState, чтобы не обращаться к context в dispose().
  late final TextEditingController _otpController;

  // ── Error UX state ───────────────────────────────────────────────────────
  String? _otpError;
  bool _forceError = false; // подсветка через errorPinTheme
  bool _disabled = false; // кнопка временно неактивна после ошибки

  // Горизонтальный shake всего пин-блока
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  // Пульс активной ячейки (glow + переливающийся border) — бесконечный loop.
  late final AnimationController _pulseCtrl;
  // Success-морфинг (ячейки → галочка) при верном коде.
  late final AnimationController _successCtrl;
  bool _success = false;

  // Авто-чтение SMS-кода (A1). User Consent API — системный диалог
  // «разрешить чтение SMS?», НЕ требует SMS-подписи приложения и
  // изменений бэкенд-шаблона. Работает только на реальном Android-девайсе.
  final SmsRetriever _smsRetriever = _OtpSmsRetriever(SmartAuth.instance);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();

    _otpController = context.read<AuthProvider>().otpController;
    // Стартуем с пустого поля — не подтягиваем код из прошлой сессии
    // (например, после logout + login другим аккаунтом).
    _otpController.clear();
    _otpController.addListener(_onOtpChanged);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7, end: 7), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    // Бесконечный пульс активной ячейки (1.1с в одну сторону, reverse).
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  void _onOtpChanged() {
    final text = _otpController.text;
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
    _otpController.removeListener(_onOtpChanged);
    WidgetsBinding.instance.removeObserver(this);
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    _timer?.cancel();
    _smsRetriever.dispose();
    super.dispose();
  }

  Future<void> _onVerify({required bool fromAutoComplete}) async {
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();
    final words = lang.words;

    if (!fromAutoComplete && auth.otpController.text.length < 4) return;
    if (_disabled || _success) return;

    // autoNavigate: false — навигацию делаем САМИ после success-морфинга,
    // чтобы пользователь увидел анимацию «галочки».
    final ok = await auth.verifyOtpAndLogin(
      context,
      lang,
      silent: true,
      autoNavigate: false,
    );

    if (!mounted) return;

    if (ok) {
      // ── Success-морфинг (#3) ──────────────────────────────────────────
      HapticFeedback.lightImpact();
      _pulseCtrl.stop();
      setState(() => _success = true);
      await _successCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      // Реплицируем AuthProvider._navigate — всегда на /home.
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      return;
    }

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
    HapticFeedback.heavyImpact(); // усиленный фидбек на неверный код (#4)
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

  // ── Pin themes — принимают AppColors, не обращаются к static constants ───
  PinTheme _defaultTheme(AppColors c) => PinTheme(
    width: 56,
    height: 64,
    textStyle: AppText.serif(fontSize: 26, letterSpacing: 0, color: c.ink),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.border, width: 1),
    ),
  );

  /// Активная ячейка (#2 glow-pulse + #6 переливающийся border).
  /// [t] ∈ [0,1] — фаза пульса из `_pulseCtrl`.
  PinTheme _focusedTheme(AppColors c, double t) {
    // Border «переливается» между ink и accent по фазе t.
    final borderColor = Color.lerp(c.ink, c.accent, t)!;
    // Glow дышит: blur и прозрачность тени растут к пику пульса.
    final glowAlpha = 0.10 + 0.22 * t;
    final glowBlur = 12.0 + 12.0 * t;
    return _defaultTheme(c).copyWith(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5 + 0.5 * t),
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: glowAlpha),
            blurRadius: glowBlur,
            spreadRadius: 0.5 * t,
          ),
        ],
      ),
    );
  }

  /// Заполненная ячейка (#1 заливка акцентом). Scale-bounce даёт
  /// `pinAnimationType: scale` + easeOutBack на самом Pinput.
  PinTheme _submittedTheme(AppColors c) => _defaultTheme(c).copyWith(
    textStyle: AppText.serif(fontSize: 26, letterSpacing: 0, color: c.ink),
    decoration: BoxDecoration(
      color: c.emeraldTint,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.accent, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: c.accent.withValues(alpha: 0.18),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
  );

  PinTheme _errorTheme(AppColors c) => _defaultTheme(c).copyWith(
    textStyle: AppText.serif(
      fontSize: 26,
      letterSpacing: 0,
      color: c.errorMuted,
    ),
    decoration: BoxDecoration(
      color: c.errorTint,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.errorMuted, width: 1.5),
      // Красный pulse-glow на ошибке (#4).
      boxShadow: [
        BoxShadow(
          color: c.errorMuted.withValues(alpha: 0.28),
          blurRadius: 14,
          spreadRadius: 1,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final isLoading = context.select<AuthProvider, bool>((a) => a.isLoading);
    final c = AppColors.of(context);

    final buttonDisabled = _disabled || isLoading;

    return Scaffold(
      backgroundColor: c.bg,
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
                    AuthLangSwitcher(
                      isRu: lang.isRu,
                      onToggle: lang.toggleLanguage,
                    ),
                    const SizedBox(width: 8),
                    const ThemeToggleIcon(),
                  ],
                ),

                const Spacer(flex: 2),

                // ── Title (calm serif) ─────────────────────────────────────
                Text(words.authOtpTitle, style: AppText.serif(fontSize: 34)),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: AppText.regular(
                      fontSize: 14.5,
                      color: c.inkMuted,
                    ).copyWith(height: 1.5, letterSpacing: 0.1),
                    children: [
                      TextSpan(text: words.authOtpSubtitle),
                      TextSpan(
                        text: auth.phoneController.text.isNotEmpty
                            ? '+993 ${auth.phoneController.text}'
                            : '+993 6X XX XX XX',
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Pinput ↔ Success-морфинг ──────────────────────────────
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.85, end: 1.0).animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOut),
                        ),
                        child: child,
                      ),
                    ),
                    child: _success
                        ? _SuccessCheck(key: const ValueKey('ok'), ctrl: _successCtrl)
                        : AnimatedBuilder(
                            key: const ValueKey('pins'),
                            // Слушаем shake И pulse — оба влияют на отрисовку.
                            animation: Listenable.merge([_shakeAnim, _pulseCtrl]),
                            builder: (_, _) {
                              final t = Curves.easeInOut.transform(
                                _pulseCtrl.value,
                              );
                              return Transform.translate(
                                offset: Offset(_shakeAnim.value, 0),
                                child: Pinput(
                                  length: 4,
                                  controller: auth.otpController,
                                  smsRetriever: _smsRetriever, // авто-чтение SMS
                                  // #5 spring-появление цифры (overshoot).
                                  pinAnimationType: PinAnimationType.scale,
                                  animationCurve: Curves.easeOutBack,
                                  animationDuration:
                                      const Duration(milliseconds: 300),
                                  defaultPinTheme: _defaultTheme(c),
                                  focusedPinTheme: _focusedTheme(c, t), // #2/#6
                                  submittedPinTheme: _submittedTheme(c), // #1
                                  errorPinTheme: _errorTheme(c), // #4
                                  forceErrorState: _forceError,
                                  separatorBuilder: (_) =>
                                      const SizedBox(width: 12),
                                  showCursor: true,
                                  cursor: Container(
                                    width: 1.5,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: c.ink,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  onCompleted: (_) =>
                                      _onVerify(fromAutoComplete: true),
                                ),
                              );
                            },
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
// Success check (#3) — заливка-круг + галочка с bounce-появлением
// ═════════════════════════════════════════════════════════════════════════════

class _SuccessCheck extends StatelessWidget {
  final AnimationController ctrl;
  const _SuccessCheck({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Круг масштабируется с overshoot, галочка проявляется чуть позже.
    final circleScale = CurvedAnimation(
      parent: ctrl,
      curve: Curves.easeOutBack,
    );
    final checkFade = CurvedAnimation(
      parent: ctrl,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );
    return SizedBox(
      height: 64,
      child: Center(
        child: ScaleTransition(
          scale: circleScale,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FadeTransition(
              opacity: checkFade,
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 34),
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
    final c = AppColors.of(context);
    final mm = '0:${seconds.toString().padLeft(2, '0')}';

    return RichText(
      text: TextSpan(
        style: AppText.regular(
          fontSize: 13.5,
          color: c.inkSoft,
        ).copyWith(height: 1.4, letterSpacing: 0.1),
        children: [
          TextSpan(text: words.authOtpResendInPrefix),
          TextSpan(
            text: mm,
            style: TextStyle(
              color: c.ink,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SMS auto-read (A1) ────────────────────────────────────────────────────────

/// Реализация pinput-овского [SmsRetriever] поверх smart_auth.
/// Использует User Consent API: показывает системный диалог подтверждения
/// чтения SMS, извлекает код дефолтным matcher'ом `\d{4,8}` (ловит 4-значный).
/// НЕ требует SMS app-signature (в отличие от Retriever API).
class _OtpSmsRetriever implements SmsRetriever {
  _OtpSmsRetriever(this._smartAuth);
  final SmartAuth _smartAuth;

  @override
  bool get listenForMultipleSms => false;

  @override
  Future<String?> getSmsCode() async {
    final res = await _smartAuth.getSmsWithUserConsentApi();
    if (res.hasData) return res.data?.code;
    return null;
  }

  @override
  Future<void> dispose() async {
    await _smartAuth.removeUserConsentApiListener();
  }
}

class _ResendLink extends StatelessWidget {
  final VoidCallback onPressed;
  const _ResendLink({required this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    final c = AppColors.of(context);

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          words.authOtpResendLink,
          style: AppText.semiBold(fontSize: 13.5, color: c.ink).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: c.ink,
            decorationThickness: 1.2,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
