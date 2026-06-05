import 'package:bagla/core/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Full-screen animated loader shown while the app initialises.
///
/// Design: Anthropic-style — clean background, serif logo, three
/// breathing dots that loop until [onReady] fires.  Everything fades
/// out smoothly so the transition into the main screen is seamless.
class SplashScreen extends StatefulWidget {
  /// Called once; receives the callback that triggers the exit animation
  /// and then hands control back to [AppBootstrap].
  final Future<void> Function(VoidCallback onDone) onReady;

  const SplashScreen({super.key, required this.onReady});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Logo: fade-in + subtle upward slide ──────────────────────────────────
  late final AnimationController _logoCtrl;
  late final Animation<double>   _logoOpacity;
  late final Animation<Offset>   _logoSlide;

  // ── Dots: three breathing circles looping forever ────────────────────────
  late final AnimationController _dotsCtrl;

  // ── Exit: full-screen fade to background ─────────────────────────────────
  late final AnimationController _exitCtrl;
  late final Animation<double>   _exitOpacity;

  @override
  void initState() {
    super.initState();

    // Logo
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic));

    // Dots (looping)
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Exit fade
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _exitOpacity = CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn);

    _run();
  }

  Future<void> _run() async {
    // 1. Logo fades in
    _logoCtrl.forward();
    // 2. Dots start a beat after
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    _dotsCtrl.repeat();
  
    // 3. Run all init wor  k; when done → exit animation
    await widget.onReady(_onDone);
  }

  void _onDone() async {
    if (!mounted) return;
    _dotsCtrl.stop();
    await _exitCtrl.forward();
    // AppBootstrap.setState() is triggered from outside after this callback
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _dotsCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // Returns the per-dot scale/opacity animation with staggered offset.
  Animation<double> _dotAnim(int i) {
    final start = i / 3.5;
    final end   = (start + 0.55).clamp(0.0, 1.0);
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0,  end: 0.25), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _dotsCtrl,
        curve: Interval(start, end, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the theme colours so the splash respects dark / light mode.
    final bg   = Theme.of(context).colorScheme.surface;
    final ink  = Theme.of(context).colorScheme.onSurface;

    return FadeTransition(
      // Exit: fade entire screen to background
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_exitOpacity),
      child: Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Logo ────────────────────────────────────────────────
              SlideTransition(
                position: _logoSlide,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: Text(
                    'Bagla',
                    style: AppText.serif(fontSize: 44, color: ink),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Three breathing dots (Anthropic-style) ────────────
              AnimatedBuilder(
                animation: _dotsCtrl,
                builder: (_, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final anim = _dotAnim(i);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Transform.scale(
                        scale: 0.4 + 0.6 * anim.value,
                        child: Opacity(
                          opacity: anim.value,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
