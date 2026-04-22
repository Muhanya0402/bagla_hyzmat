import 'package:bagla/features/profile/user_type_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color brandBlue = Color(0xFF1B3A6B);
  static const Color brandGreen = Color(0xFF27AE60);

  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _canNext = false;
  int _secondsLeft = 3;
  Timer? _timer;

  late final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      iconWidget: Image.asset(
        'assets/images/bagla_logo.png',
        width: 56,
        height: 56,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 40),
      ),
      bg: const Color(0xFFEAF4FF),
      accentColor: const Color(0xFF1B3A6B),
      title: 'Добро пожаловать\nв Bagla',
      subtitle:
          'Bagla — это платформа для быстрой доставки товаров. '
          'Здесь встречаются заказчики и доставщики.',
    ),
    _OnboardingPage(
      emoji: '🚀',
      bg: const Color(0xFFEAFFF3),
      accentColor: const Color(0xFF1A7A45),
      title: 'Как это работает?',
      subtitle: 'Две стороны одной доставки — выбери свою.',
    ),
    _OnboardingPage(
      iconWidget: Image.asset(
        'assets/images/point_icon.png',
        width: 128,
        height: 128,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.monetization_on, size: 40),
      ),
      bg: const Color(0xFFFFFBEA),
      accentColor: const Color(0xFFB07D00),
      title: 'Жетоны — ваша\nвалюта в Bagla',
      subtitle:
          'За каждый заказ вы получаете жетоны. Их можно тратить '
          'на скидки, бонусы и специальные предложения внутри приложения.',
    ),
    _OnboardingPage(
      emoji: '🎯',
      bg: const Color(0xFFF3EAFF),
      accentColor: const Color(0xFF5B2D9E),
      title: 'Кем вы хотите\nбыть в Bagla?',
      subtitle:
          'Выберите роль — заказчик или доставщик. '
          'Можно поменять позже в профиле.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _canNext = false;
    _secondsLeft = 3;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _canNext = true;
          t.cancel();
        }
      });
    });
  }

  void _next() {
    if (!_canNext) return;
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToRoleSelection();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToRoleSelection() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const UserTypeSelectionScreen()),
    );
  }

  Future<void> _skip() async {
    final auth = context.read<AuthProvider>();
    await auth.skipOnboarding(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: page.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Топбар ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Логотип
                  Text(
                    'Bagla',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: brandBlue,
                      letterSpacing: .4,
                    ),
                  ),

                  // Кнопка «Пропустить» — только на последней странице
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: isLast ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !isLast,
                      child: GestureDetector(
                        onTap: _skip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.07),
                            ),
                          ),
                          child: Text(
                            'Пропустить',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Прогресс-индикаторы ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? page.accentColor
                          : page.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // ── Контент страниц ───────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  _startTimer();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final p = _pages[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Иконка-карточка
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: p.accentColor.withOpacity(0.1),
                            ),
                          ),
                          child: Center(
                            child:
                                p.iconWidget ??
                                Text(
                                  p.emoji,
                                  style: const TextStyle(fontSize: 36),
                                ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        Text(
                          p.title,
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: p.accentColor,
                            height: 1.15,
                            letterSpacing: -0.3,
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          p.subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.black54,
                            height: 1.6,
                          ),
                        ),

                        if (index == 1) ...[
                          const SizedBox(height: 24),
                          _TwoSideCard(accentColor: p.accentColor),
                        ],

                        if (index == 2) ...[
                          const SizedBox(height: 24),
                          _TokenCard(accentColor: p.accentColor),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Кнопки навигации ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Row(
                children: [
                  // Кнопка «Назад»
                  if (_currentPage > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: brandBlue,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.black.withOpacity(0.08),
                              ),
                            ),
                          ),
                          onPressed: _back,
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // Кнопка «Далее» / «Выбрать роль»
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canNext
                              ? (isLast ? brandGreen : page.accentColor)
                              : page.accentColor.withOpacity(0.25),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _canNext ? _next : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _canNext
                                  ? (isLast ? 'ВЫБРАТЬ РОЛЬ' : 'ДАЛЕЕ')
                                  : 'ПОДОЖДИТЕ  $_secondsLeft',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .8,
                                color: _canNext ? Colors.white : Colors.white60,
                              ),
                            ),
                            if (_canNext) ...[
                              const SizedBox(width: 8),
                              Icon(
                                isLast
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _TwoSideCard ─────────────────────────────────────────────────────────────

class _TwoSideCard extends StatelessWidget {
  final Color accentColor;
  const _TwoSideCard({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _roleCard(
          label: 'Заказчик / Магазин',
          labelBg: const Color(0xFFEAF4FF),
          labelColor: const Color(0xFF1B3A6B),
          borderColor: const Color(0xFF1B3A6B),
          steps: const [
            'Создаёт заказ в приложении',
            'Указывает адрес доставки',
            'Ждёт подтверждения доставщика',
            'Получает товар и оставляет оценку',
          ],
        ),
        const SizedBox(height: 10),
        _roleCard(
          label: 'Доставщик',
          labelBg: const Color(0xFFEAFFF3),
          labelColor: const Color(0xFF1A7A45),
          borderColor: const Color(0xFF27AE60),
          steps: const [
            'Видит доступные заказы рядом',
            'Берёт удобный заказ',
            'Забирает товар и едет к заказчику',
            'Получает оплату и жетоны',
          ],
        ),
      ],
    );
  }

  Widget _roleCard({
    required String label,
    required Color labelBg,
    required Color labelColor,
    required Color borderColor,
    required List<String> steps,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: labelBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map(
            (e) => _MiniStep(num: '${e.key + 1}', text: e.value),
          ),
        ],
      ),
    );
  }
}

// ─── _MiniStep ────────────────────────────────────────────────────────────────

class _MiniStep extends StatelessWidget {
  final String num;
  final String text;
  const _MiniStep({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                num,
                style: GoogleFonts.dmMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black45,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _TokenCard ───────────────────────────────────────────────────────────────

class _TokenCard extends StatelessWidget {
  final Color accentColor;
  const _TokenCard({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.13)),
      ),
      child: Column(
        children: [
          _TokenRow(
            icon: Icons.shopping_bag_outlined,
            text: 'Сделай заказ',
            accentColor: accentColor,
          ),
          Divider(height: 20, color: accentColor.withOpacity(0.08)),
          _TokenRow(
            icon: Icons.toll_rounded,
            text: 'Получи жетоны',
            accentColor: accentColor,
          ),
          Divider(height: 20, color: accentColor.withOpacity(0.08)),
          _TokenRow(
            icon: Icons.card_giftcard_rounded,
            text: 'Трать на бонусы',
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accentColor;
  const _TokenRow({
    required this.icon,
    required this.text,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: accentColor, size: 17),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _OnboardingPage {
  final String emoji;
  final Widget? iconWidget;
  final Color bg;
  final Color accentColor;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    this.emoji = '',
    this.iconWidget,
    required this.bg,
    required this.accentColor,
    required this.title,
    required this.subtitle,
  });
}
