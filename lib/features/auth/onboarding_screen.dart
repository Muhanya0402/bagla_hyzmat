import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../profile/user_type_selection_screen.dart';
import 'package:bagla/core/app_text_styles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color primary = Color(0xFF1B3A6B);

  final PageController _controller = PageController();
  int _page = 0;

  int _seconds = 3;
  Timer? _timer;
  bool _canNext = false;

  final pages = const [
    _SimplePage(
      icon: Icons.local_shipping_outlined,
      title: "Быстрая доставка",
      subtitle: "От двери до двери за короткое время",
    ),
    _SimplePage(
      icon: Icons.swap_horiz,
      title: "Выбирай роль",
      subtitle: "Заказывай или доставляй — решаешь ты",
    ),
    _SimplePage(
      icon: Icons.card_giftcard,
      title: "Получай бонусы",
      subtitle: "Жетоны за заказы и бонусы внутри приложения",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 3;
    _canNext = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      setState(() {
        _seconds--;

        if (_seconds <= 0) {
          _canNext = true;
          t.cancel();
        }
      });
    });
  }

  void _next() {
    if (!_canNext) return;

    if (_page < pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserTypeSelectionScreen()),
      );
    }
  }

  Future<void> _skip() async {
    await context.read<AuthProvider>().skipOnboarding(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == pages.length - 1;

    final page = pages[_page];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// TOP BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/images/bagla_logo.png', width: 34),

                  /// SKIP только на последнем
                  Opacity(
                    opacity: isLast ? 1 : 0,
                    child: TextButton(
                      onPressed: isLast ? _skip : null,
                      child: const Text("Пропустить"),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// DOTS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i ? primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            /// CONTENT
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _page = i);
                  _startTimer();
                },
                itemCount: pages.length,
                itemBuilder: (_, i) {
                  final p = pages[i];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(p.icon, size: 64, color: primary),

                        const SizedBox(height: 28),

                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: AppText.bold(
                            fontSize: 26,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          p.subtitle,
                          textAlign: TextAlign.center,
                          style: AppText.regular(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            /// TIMER INFO
            Text(
              _canNext ? "Можно продолжить" : "Подождите $_seconds сек",
              style: AppText.regular(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 16),

            /// BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canNext ? _next : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canNext
                        ? primary
                        : primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isLast ? "НАЧАТЬ" : "ДАЛЕЕ",
                    style: AppText.semiBold(fontSize: 14, color: Colors.white),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// SIMPLE PAGE MODEL
class _SimplePage {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SimplePage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
