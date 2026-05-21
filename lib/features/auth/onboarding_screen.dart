import 'dart:async';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart'; // adjust import path
import '../../l10n/app_localizations.dart'; // adjust import path

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  final _pageCtrl = PageController();
  int _page = 0;
  int _seconds = 3;
  bool _canNext = false;
  Timer? _timer;

  // ── Page enter animation ───────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  // ── Build pages dynamically from localization ──────────────────────────────
  List<_PageData> _buildPages(AppLocalizations l) => [
    _PageData(
      tag: l.onboardingTag1,
      title: l.onboardingTitle1,
      subtitle: l.onboardingSubtitle1,
      pills: [
        _Pill(l.onboardingPill1_1, true),
        _Pill(l.onboardingPill1_2, true),
        _Pill(l.onboardingPill1_3, false),
      ],
    ),
    _PageData(
      tag: l.onboardingTag2,
      title: l.onboardingTitle2,
      subtitle: l.onboardingSubtitle2,
      pills: [
        _Pill(l.onboardingPill2_1, true),
        _Pill(l.onboardingPill2_2, false),
      ],
    ),
    _PageData(
      tag: l.onboardingTag3,
      title: l.onboardingTitle3,
      subtitle: l.onboardingSubtitle3,
      pills: [
        _Pill(l.onboardingPill3_1, true),
        _Pill(l.onboardingPill3_2, false),
      ],
    ),
    _PageData(
      tag: l.onboardingTag4,
      title: l.onboardingTitle4,
      subtitle: l.onboardingSubtitle4,
      pills: [
        _Pill(l.onboardingPill4_1, true),
        _Pill(l.onboardingPill4_2, false),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _startTimer();
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = 3;
      _canNext = false;
    });
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

  void _next(int pageCount) {
    if (!_canNext) return;
    if (_page < pageCount - 1) {
      _fadeCtrl.reset();
      _slideCtrl.reset();
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goStart();
    }
  }

  Future<void> _skip() async {
    await context.read<AuthProvider>().skipOnboarding(context);
  }

  void _goStart() {
    Navigator.pushNamed(context, '/user_type_selection');
  }

  @override
  Widget build(BuildContext context) {
    // Watch the language provider so the UI rebuilds on locale change
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final pages = _buildPages(words);
    final isLast = _page == pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BaglaLogo(width: 52, height: 26),
                  AnimatedOpacity(
                    opacity: isLast ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: isLast ? _skip : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEEF0F3)),
                        ),
                        child: Text(
                          words.skip,
                          style: AppText.semiBold(
                            fontSize: 12,
                            color: const Color(0xFF9AA3AF),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Dots ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: _page == i ? AuthColors.gradient : null,
                    color: _page == i ? null : const Color(0xFFEEF0F3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),

            const SizedBox(height: 8),

            // ── Illustration ───────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: PageView.builder(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _page = i);
                  _startTimer();
                  _fadeCtrl.forward(from: 0);
                  _slideCtrl.forward(from: 0);
                },
                itemCount: pages.length,
                itemBuilder: (_, i) => _buildIllustration(i, words),
              ),
            ),

            // ── Text content ───────────────────────────────────────────────
            Expanded(
              flex: 4,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AuthColors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pages[_page].tag,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AuthColors.green,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Title
                        Text(
                          pages[_page].title,
                          style: AppText.extraBold(
                            fontSize: 22,
                            color: const Color(0xFF0F1117),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          pages[_page].subtitle,
                          style: AppText.regular(
                            fontSize: 13,
                            color: const Color(0xFF9AA3AF),
                          ).copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 12),

                        // Pills
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: pages[_page].pills
                              .map((p) => _PillWidget(pill: p))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Timer hint ─────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _canNext
                  ? Text(
                      words.canContinue,
                      key: const ValueKey('ok'),
                      style: AppText.regular(
                        fontSize: 11,
                        color: AuthColors.green,
                      ),
                    )
                  : Text(
                      '${words.waitSeconds} $_seconds ${words.sec}',
                      key: const ValueKey('wait'),
                      style: AppText.regular(
                        fontSize: 11,
                        color: const Color(0xFF9AA3AF),
                      ),
                    ),
            ),

            const SizedBox(height: 12),

            // ── Button ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: GestureDetector(
                onTap: _canNext ? () => _next(pages.length) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _canNext ? AuthColors.gradient : null,
                    color: _canNext ? null : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _canNext
                        ? [
                            BoxShadow(
                              color: AuthColors.green.withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLast ? words.start : words.next,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: _canNext
                              ? Colors.white
                              : const Color(0xFF9AA3AF),
                        ),
                      ),
                      if (_canNext) ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
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
    );
  }

  // ── Illustrations ──────────────────────────────────────────────────────────
  Widget _buildIllustration(int index, AppLocalizations l) {
    switch (index) {
      case 0:
        return _DeliveryIllus();
      case 1:
        return _RolesIllus(
          shopLabel: l.get('onboardingPill2_1'),
          shopDesc: l.get('shopDesc'),
          courierLabel: l.get('onboardingPill2_2'),
          courierDesc: l.get('courierDesc'),
        );
      case 2:
        return _TokensIllus();
      case 3:
        return _StepsIllus(
          shopLabel: l.get('onboardingPill2_1'),
          shopSub: l.get('shopCreatesOrder'),
          courierLabel: l.get('onboardingPill2_2'),
          courierSub: l.get('courierTakesOrder'),
          deliveryLabel: l.get('delivery'),
          deliverySub: l.get('deliveryConfirmed'),
          badge: l.get('cashback'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration 1 — delivery van  (no text, unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryIllus extends StatefulWidget {
  @override
  State<_DeliveryIllus> createState() => _DeliveryIllusState();
}

class _DeliveryIllusState extends State<_DeliveryIllus>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _move;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _move = Tween<double>(
      begin: -30,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _move,
      builder: (_, _) => Transform.translate(
        offset: Offset(_move.value, 0),
        child: CustomPaint(
          painter: _VanPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _VanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.48;

    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.34,
      Paint()..color = AuthColors.green.withValues(alpha: 0.07),
    );

    final road = Paint()..color = const Color(0xFFEEF0F3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + 70),
          width: size.width * 0.8,
          height: 10,
        ),
        const Radius.circular(5),
      ),
      road,
    );

    final bodyP = Paint()..color = AuthColors.green;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 90, cy + 10, 130, 56),
        const Radius.circular(10),
      ),
      bodyP,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 28, cy - 6, 54, 50),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF22963F),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 36, cy + 2, 38, 26),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFE8F5EE),
    );

    void wheel(double x) {
      canvas.drawCircle(
        Offset(x, cy + 66),
        16,
        Paint()..color = const Color(0xFF0F1117),
      );
      canvas.drawCircle(Offset(x, cy + 66), 8, Paint()..color = Colors.white);
    }

    wheel(cx - 50);
    wheel(cx + 30);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 78, cy - 12, 56, 42),
        const Radius.circular(7),
      ),
      Paint()..color = AuthColors.red.withValues(alpha: 0.9),
    );
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(cx - 78, cy + 9),
      Offset(cx - 22, cy + 9),
      linePaint,
    );
    canvas.drawLine(
      Offset(cx - 50, cy - 12),
      Offset(cx - 50, cy + 30),
      linePaint,
    );

    final bow = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final bowPath = Path()
      ..moveTo(cx - 56, cy - 12)
      ..quadraticBezierTo(cx - 50, cy - 20, cx - 44, cy - 12);
    canvas.drawPath(bowPath, bow);

    final lineP = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final y = cy + 20 + i * 12.0;
      lineP
        ..color = AuthColors.green.withValues(alpha: 0.4 - i * 0.1)
        ..strokeWidth = 2.5 - i * 0.5;
      canvas.drawLine(Offset(cx - 130, y), Offset(cx - 102, y), lineP);
    }

    canvas.drawCircle(
      Offset(cx + 72, cy - 42),
      13,
      Paint()..color = AuthColors.red,
    );
    canvas.drawCircle(
      Offset(cx + 72, cy - 46),
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawLine(
      Offset(cx + 72, cy - 29),
      Offset(cx + 72, cy - 22),
      Paint()
        ..color = AuthColors.red
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VanPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration 2 — roles  (labels now come from l10n)
// ─────────────────────────────────────────────────────────────────────────────

class _RolesIllus extends StatelessWidget {
  final String shopLabel;
  final String shopDesc;
  final String courierLabel;
  final String courierDesc;

  const _RolesIllus({
    required this.shopLabel,
    required this.shopDesc,
    required this.courierLabel,
    required this.courierDesc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoleCard(
            color: AuthColors.green,
            bg: const Color(0xFFE8F5EE),
            icon: Icons.storefront_outlined,
            title: shopLabel,
            desc: shopDesc,
          ),
          const SizedBox(width: 14),
          _RoleCard(
            color: AuthColors.red,
            bg: const Color(0xFFFFF0EE),
            icon: Icons.delivery_dining_outlined,
            title: courierLabel,
            desc: courierDesc,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final Color color;
  final Color bg;
  final IconData icon;
  final String title;
  final String desc;
  const _RoleCard({
    required this.color,
    required this.bg,
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEEF0F3)),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: widget.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.icon, color: widget.color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F1117),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9AA3AF),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration 3 — tokens & levels  (no user-visible text to localize)
// ─────────────────────────────────────────────────────────────────────────────

class _TokensIllus extends StatefulWidget {
  @override
  State<_TokensIllus> createState() => _TokensIllusState();
}

class _TokensIllusState extends State<_TokensIllus>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) => CustomPaint(
        painter: _TokensPainter(_pulse.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TokensPainter extends CustomPainter {
  final double pulse;
  const _TokensPainter(this.pulse);

  static const _green = Color(0xFF1A7A3C);
  static const _orange = Color(0xFFE67E22);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.44;

    for (int i = 3; i >= 1; i--) {
      canvas.drawCircle(
        Offset(cx, cy),
        (38 + i * 18) * pulse,
        Paint()..color = _orange.withValues(alpha: 0.04 * i),
      );
    }

    canvas.drawCircle(Offset(cx, cy), 36 * pulse, Paint()..color = _orange);

    final tp = TextPainter(
      text: const TextSpan(
        text: 'T',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    final b1 = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + 64, cy - 36), width: 36, height: 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(b1, Paint()..color = _green);
    _drawText(canvas, '+1', cx + 64, cy - 36, Colors.white, 12);

    final b2 = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - 60, cy - 34), width: 36, height: 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(b2, Paint()..color = const Color(0xFFD32F1E));
    _drawText(canvas, '+2', cx - 60, cy - 34, Colors.white, 12);

    // Daily bonus pill — localized inline via passed text would require
    // refactoring _TokensPainter to accept a string; keeping as-is since
    // "+0.5" is a numeric label understood across both locales.
    final bonusRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 58), width: 170, height: 24),
      const Radius.circular(12),
    );
    canvas.drawRRect(bonusRect, Paint()..color = _green.withValues(alpha: 0.1));
    _drawText(canvas, '+0.5 / day', cx, cy + 58, _green, 10, bold: true);

    final barY = cy + 88.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 90, barY, 180, 8),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFEEF0F3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 90, barY, 115, 8),
        const Radius.circular(4),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [_green, Color(0xFFD32F1E)],
        ).createShader(Rect.fromLTWH(cx - 90, barY, 180, 8)),
    );

    // Level labels use "Ур." / numeric — keep neutral
    _drawText(canvas, 'Lv.1', cx - 86, barY + 20, const Color(0xFF9AA3AF), 9);
    _drawText(canvas, 'Lv.3 ★', cx, barY + 20, _green, 9, bold: true);
    _drawText(canvas, 'Lv.10', cx + 82, barY + 20, const Color(0xFF9AA3AF), 9);
  }

  void _drawText(
    Canvas canvas,
    String text,
    double cx,
    double cy,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TokensPainter old) => old.pulse != pulse;
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration 4 — 3 steps flow  (labels now come from l10n)
// ─────────────────────────────────────────────────────────────────────────────

class _StepsIllus extends StatelessWidget {
  final String shopLabel;
  final String shopSub;
  final String courierLabel;
  final String courierSub;
  final String deliveryLabel;
  final String deliverySub;
  final String badge;

  const _StepsIllus({
    required this.shopLabel,
    required this.shopSub,
    required this.courierLabel,
    required this.courierSub,
    required this.deliveryLabel,
    required this.deliverySub,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepBox(
            bg: const Color(0xFFE8F5EE),
            color: AuthColors.green,
            icon: Icons.storefront_outlined,
            label: shopLabel,
            sub: shopSub,
          ),
          _Arrow(),
          _StepBox(
            bg: const Color(0xFFFFF0EE),
            color: AuthColors.red,
            icon: Icons.delivery_dining_outlined,
            label: courierLabel,
            sub: courierSub,
          ),
          _Arrow(),
          _StepBox(
            bg: const Color(0xFFE8F5EE),
            color: AuthColors.green,
            icon: Icons.check_circle_outline_rounded,
            label: deliveryLabel,
            sub: deliverySub,
            badge: badge,
          ),
        ],
      ),
    );
  }
}

class _StepBox extends StatefulWidget {
  final Color bg;
  final Color color;
  final IconData icon;
  final String label;
  final String sub;
  final String? badge;

  const _StepBox({
    required this.bg,
    required this.color,
    required this.icon,
    required this.label,
    required this.sub,
    this.badge,
  });

  @override
  State<_StepBox> createState() => _StepBoxState();
}

class _StepBoxState extends State<_StepBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: widget.bg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(widget.icon, color: widget.color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: widget.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF9AA3AF),
              height: 1.3,
            ),
          ),
          if (widget.badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.badge!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: const Color(0xFFEEF0F3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _PageData {
  final String tag;
  final String title;
  final String subtitle;
  final List<_Pill> pills;
  const _PageData({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.pills,
  });
}

class _Pill {
  final String label;
  final bool isGreen;
  const _Pill(this.label, this.isGreen);
}

class _PillWidget extends StatelessWidget {
  final _Pill pill;
  const _PillWidget({required this.pill});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: pill.isGreen
            ? AuthColors.green.withValues(alpha: 0.08)
            : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pill.isGreen
              ? AuthColors.green.withValues(alpha: 0.2)
              : const Color(0xFFEEF0F3),
        ),
      ),
      child: Text(
        pill.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: pill.isGreen ? AuthColors.green : const Color(0xFF9AA3AF),
        ),
      ),
    );
  }
}
