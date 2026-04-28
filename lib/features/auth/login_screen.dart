import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';

import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/core/app_text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const Color primary = Color(0xFF1B3A6B);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  int seconds = 30;
  Timer? timer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  /// 📱 Маска номера
  final phoneMask = MaskTextInputFormatter(
    mask: '+993########',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween(
      begin: 0.0,
      end: 8.0,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);

    startTimer();

    /// 🔒 Ограничение: только 6 или 7 после +993
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();

      auth.phoneController.addListener(() {
        final text = auth.phoneController.text;
        final clean = _cleanPhone(text);

        if (clean.length >= 4) {
          final first = clean.substring(3, 4);

          if (first != '6' && first != '7') {
            auth.phoneController.clear();
          }
        }
      });
    });
  }

  void startTimer() {
    timer?.cancel();
    seconds = 30;

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds == 0) {
        timer?.cancel();
      } else {
        setState(() => seconds--);
      }
    });
  }

  void shake() {
    _shakeController.forward(from: 0);
  }

  String _cleanPhone(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  bool _isValidPhone(String input) {
    final clean = _cleanPhone(input);

    if (clean.length != 11) return false;

    final first = clean.substring(3, 4);
    return first == '6' || first == '7';
  }

  @override
  void dispose() {
    timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;

    final auth = context.read<AuthProvider>();

    final isCodeSent = context.select<AuthProvider, bool>((a) => a.isCodeSent);
    final isLoading = context.select<AuthProvider, bool>((a) => a.isLoading);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          GestureDetector(
            onTap: () => lang.toggleLanguage(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  lang.label.toUpperCase(),
                  style: AppText.medium(
                    fontSize: 13,
                    color: LoginScreen.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),

              /// 🔥 ЛОГОТИП
              Image.asset(
                'assets/images/bagla_logo.png',
                width: 90,
                height: 90,
              ),

              const SizedBox(height: 16),

              /// 🔥 СЛОГАН
              Text(
                "Услуга доставки с двери до двери",
                textAlign: TextAlign.center,
                style: AppText.regular(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 32),

              /// Заголовок
              Text(
                isCodeSent ? words.otpLabel : words.phoneLabel,
                textAlign: TextAlign.center,
                style: AppText.semiBold(fontSize: 20, color: Colors.black),
              ),

              const SizedBox(height: 24),

              /// Ввод с shake
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: !isCodeSent
                    ? TextField(
                        controller: auth.phoneController,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        inputFormatters: [phoneMask],
                        style: AppText.semiBold(
                          fontSize: 18,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: "+993 6_ ___ ___",
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: LoginScreen.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      )
                    : _OtpInput(
                        onError: shake,
                        onResend: () {
                          auth.resetStatus();
                          startTimer();
                        },
                        seconds: seconds,
                      ),
              ),

              const SizedBox(height: 28),

              /// Кнопка
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final phone = auth.phoneController.text;

                          if (!isCodeSent && !_isValidPhone(phone)) {
                            shake();
                            return;
                          }

                          try {
                            await auth.handleAuth(context, lang);
                          } catch (_) {
                            shake();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LoginScreen.primary,
                    elevation: 0,
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
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          (isCodeSent ? words.confirmBtn : words.getCodeBtn)
                              .toUpperCase(),
                          style: AppText.semiBold(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const Spacer(),

              Text(
                "Нажимая кнопку, вы соглашаетесь с условиями",
                textAlign: TextAlign.center,
                style: AppText.regular(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// OTP блок
class _OtpInput extends StatelessWidget {
  final VoidCallback onError;
  final VoidCallback onResend;
  final int seconds;

  const _OtpInput({
    required this.onError,
    required this.onResend,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();

    final pinTheme = PinTheme(
      width: 52,
      height: 52,
      textStyle: AppText.bold(fontSize: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    return Column(
      children: [
        Pinput(
          length: 4,
          controller: auth.otpController,
          defaultPinTheme: pinTheme,
          focusedPinTheme: pinTheme.copyWith(
            decoration: pinTheme.decoration!.copyWith(
              border: Border.all(color: LoginScreen.primary, width: 1.5),
            ),
          ),
          onCompleted: (pin) async {
            try {
              await auth.handleAuth(context, lang);
            } catch (_) {
              onError();
            }
          },
          autofocus: true,
        ),

        const SizedBox(height: 16),

        seconds > 0
            ? Text(
                "Отправить код через $seconds сек",
                style: AppText.regular(fontSize: 12, color: Colors.grey),
              )
            : TextButton(
                onPressed: onResend,
                child: const Text("Отправить код повторно"),
              ),
      ],
    );
  }
}
