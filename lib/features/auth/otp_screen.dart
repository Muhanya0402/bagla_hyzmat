import 'dart:async';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/core/app_text_styles.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with WidgetsBindingObserver {
  int _seconds = 30;
  Timer? _timer;
  DateTime? _backgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Уходим в фон — запоминаем время и останавливаем таймер
      _backgroundTime = DateTime.now();
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // Возвращаемся — считаем сколько прошло времени
      if (_backgroundTime != null && _seconds > 0) {
        final elapsed = DateTime.now().difference(_backgroundTime!).inSeconds;
        final remaining = _seconds - elapsed;
        setState(() => _seconds = remaining > 0 ? remaining : 0);
        _backgroundTime = null;

        if (_seconds > 0) {
          // Продолжаем отсчёт
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (_seconds == 0) {
              _timer?.cancel();
            } else {
              setState(() => _seconds--);
            }
          });
        }
        // Если _seconds == 0 — таймер закончился пока были в фоне,
        // кнопка "Отправить снова" появится автоматически
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
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
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // ── Pinput themes ──────────────────────────────────────────────────────────
  // FIX: use copyWith(decoration: ...) — copyDecorationWith doesn't exist in
  // this version of pinput and caused the compile error.

  PinTheme get _defaultTheme => PinTheme(
    width: 64,
    height: 64,
    textStyle: AppText.bold(fontSize: 24),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black12, width: 1.5),
    ),
  );

  PinTheme get _focusedTheme => _defaultTheme.copyWith(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AuthColors.green, width: 2),
      boxShadow: [
        BoxShadow(
          color: AuthColors.green.withValues(alpha: 0.15),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
  );

  PinTheme get _submittedTheme => _defaultTheme.copyWith(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AuthColors.red, width: 2),
    ),
  );

  PinTheme get _errorTheme => _defaultTheme.copyWith(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0EE),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AuthColors.red, width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lang = context.watch<LanguageProvider>();
    final isLoading = context.select<AuthProvider, bool>((a) => a.isLoading);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──────────────────────────────────────────────────
              const SizedBox(height: 16),
              Row(
                children: [
                  AuthBackButton(),
                  const Spacer(),
                  const BaglaLogo(width: 56, height: 28),
                  const Spacer(),
                  AuthLangSwitcher(
                    isRu: lang.isRu,
                    onToggle: lang.toggleLanguage,
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // ── Title ────────────────────────────────────────────────────
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'SMS',
                      style: AppText.bold(
                        fontSize: 26,
                        color: AuthColors.green,
                      ),
                    ),
                    TextSpan(
                      text: lang.isRu ? '-код\nотправлен' : '-kod\niberildi',
                      style: AppText.bold(fontSize: 26, color: Colors.black),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: lang.isRu ? 'На номер ' : 'Belgä '),
                    TextSpan(
                      text: auth.phoneController.text.isNotEmpty
                          ? auth.phoneController.text
                          : '+993 6X XXX XXX',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Pinput ───────────────────────────────────────────────────
              Center(
                child: Pinput(
                  length: 4,
                  controller: auth.otpController,
                  defaultPinTheme: _defaultTheme,
                  focusedPinTheme: _focusedTheme,
                  submittedPinTheme: _submittedTheme,
                  errorPinTheme: _errorTheme,
                  showCursor: true,
                  cursor: Container(
                    width: 2,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AuthColors.green,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  onCompleted: (pin) async {
                    final ok = await auth.verifyOtpAndLogin(context, lang);
                    if (!ok && context.mounted) auth.otpController.clear();
                  },
                ),
              ),

              const SizedBox(height: 28),

              // ── Timer / Resend ───────────────────────────────────────────
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _seconds > 0
                      ? _TimerPill(
                          seconds: _seconds,
                          isRu: lang.isRu,
                          key: const ValueKey('timer'),
                        )
                      : _ResendButton(
                          isRu: lang.isRu,
                          key: const ValueKey('resend'),
                          onPressed: () async {
                            await auth.sendOTPOnly(context, lang);
                            _startTimer();
                          },
                        ),
                ),
              ),

              const Spacer(),

              // ── Confirm button ───────────────────────────────────────────
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                AuthGradientButton(
                  label: lang.isRu ? 'ПОДТВЕРДИТЬ' : 'TASSYKLAMAK',
                  onPressed: () async {
                    if (auth.otpController.text.length < 4) return;
                    await auth.verifyOtpAndLogin(context, lang);
                  },
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TimerPill extends StatelessWidget {
  final int seconds;
  final bool isRu;
  const _TimerPill({required this.seconds, required this.isRu, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 15, color: Colors.black45),
          const SizedBox(width: 7),
          Text(
            isRu ? 'Повтор через ' : 'Gaýtalamak: ',
            style: AppText.regular(fontSize: 13, color: Colors.black45),
          ),
          Text(
            '0:${seconds.toString().padLeft(2, '0')}',
            style: AppText.bold(fontSize: 13, color: AuthColors.green),
          ),
        ],
      ),
    );
  }
}

class _ResendButton extends StatelessWidget {
  final bool isRu;
  final VoidCallback onPressed;
  const _ResendButton({required this.isRu, required this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh, size: 16, color: AuthColors.green),
      label: Text(
        isRu ? 'Отправить снова' : 'Täzeden ibermek',
        style: AppText.semiBold(fontSize: 14, color: AuthColors.green),
      ),
    );
  }
}
