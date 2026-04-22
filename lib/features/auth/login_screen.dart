import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../home/home_screen.dart'; // Импорт для доступа к brandBlue/brandGreen

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // Цвета вынесены для единообразия (можно брать из HomeScreen)
  static const Color brandBlue = Color(0xFF1B3A6B);
  static const Color brandGreen = Color(0xFF27AE60);
  static const Color surfaceColor = Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
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
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: brandBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: brandBlue.withOpacity(0.1)),
              ),
              alignment: Alignment.center,
              child: Text(
                lang.label.toUpperCase(),
                style: GoogleFonts.inter(
                  color: brandBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const _BrandingHeader(),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (isCodeSent ? words.otpLabel : words.phoneLabel),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9AA3AF),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (!isCodeSent)
                      TextField(
                        controller: context
                            .read<AuthProvider>()
                            .phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F1117),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: surfaceColor,
                          hintText: "+993",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.all(18),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFEEF0F3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: brandBlue,
                              width: 1.5,
                            ),
                          ),
                        ),
                      )
                    else
                      const Center(child: _OtpInput()),

                    const SizedBox(height: 24),

                    _MainActionButton(
                      text: isCodeSent ? words.confirmBtn : words.getCodeBtn,
                      onPressed: () => context.read<AuthProvider>().handleAuth(
                        context,
                        lang,
                      ),
                      isLoading: isLoading,
                    ),

                    if (isCodeSent)
                      Center(
                        child: TextButton(
                          onPressed: context.read<AuthProvider>().resetStatus,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            words.changePhoneBtn,
                            style: GoogleFonts.inter(
                              color: brandBlue,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const _PrivacyPolicySection(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpInput extends StatelessWidget {
  const _OtpInput();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();

    final defaultPinTheme = PinTheme(
      width: 64,
      height: 64,
      textStyle: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0F1117),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
    );

    return Pinput(
      length: 4,
      controller: auth.otpController,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: defaultPinTheme.copyWith(
        decoration: defaultPinTheme.decoration!.copyWith(
          border: Border.all(color: LoginScreen.brandBlue, width: 2),
        ),
      ),
      onCompleted: (pin) => auth.handleAuth(context, lang),
      hapticFeedbackType: HapticFeedbackType.lightImpact,
      autofocus: true,
    );
  }
}

class _BrandingHeader extends StatelessWidget {
  const _BrandingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // Занимать только нужное место
      children: [
        Image.asset(
          'assets/images/bagla_logo.png',
          width: 128,
          height: 128, // Вернул 22, так как 4 — это совсем мало
          fit: BoxFit.contain,
          // Добавим обработку ошибки, если файл не найдется
          errorBuilder: (context, error, stackTrace) => Container(
            width: 6,
            height: 22,
            color:
                Colors.red, // Если картинки нет, увидите красный прямоугольник
          ),
        ),
        Flexible(
          // Предотвращает overflow, если текст будет длинным
          child: Text(
            "BAGLA",
            overflow:
                TextOverflow.ellipsis, // Обрежет текст точками, если не влезет
            style: GoogleFonts.inter(
              color: HomeScreen.brandBlue,
              fontWeight: FontWeight.w700,
              fontSize: 36,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _MainActionButton({
    required this.text,
    this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              LoginScreen.brandBlue, // Сменил на Blue для стиля BAGLA
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class _PrivacyPolicySection extends StatelessWidget {
  const _PrivacyPolicySection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text.rich(
        TextSpan(
          text: "Нажимая кнопку, вы соглашаетесь с ",
          style: GoogleFonts.inter(
            color: const Color(0xFF9AA3AF),
            fontSize: 12,
          ),
          children: [
            TextSpan(
              text: "\nПолитикой конфиденциальности",
              style: const TextStyle(
                color: LoginScreen.brandBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
