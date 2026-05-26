import 'package:bagla/features/appeals/appeals_screen.dart';
import 'package:bagla/features/home/home_screen.dart';
import 'package:bagla/features/notifications/notifications_screen.dart';
import 'package:bagla/features/profile/profile_screen.dart';
import 'package:bagla/features/profile/terms_screen.dart';
import 'package:bagla/features/profile/user_type_selection_screen.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  static const Color brandGreen = Color(0xFF1A7A3C);
  static const Color brandRed = Color(0xFFD32F1E);

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainShellState>();
    state?._onTabTapped(index);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  late int _currentIndex;

  final List<int> _stackDepths = [1, 1, 1];

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  late final List<_DepthObserver> _observers;

  int _unreadCount = 0;

  // ── Overlay entry для навбара ──────────────────────────────────────────────
  OverlayEntry? _navOverlayEntry;

  bool get _navVisible => _stackDepths[_currentIndex] == 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _observers = List.generate(3, (i) {
      return _DepthObserver(
        onDepthChanged: (depth) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _stackDepths[i] = depth);
            // Перестроить overlay при изменении видимости
            _navOverlayEntry?.markNeedsBuild();
          });
        },
      );
    });

    // Вставляем навбар в корневой Overlay после первого кадра.
    // Корневой Overlay находится выше всех Navigator'ов,
    // но showModalBottomSheet по умолчанию открывается через корневой Navigator —
    // его модалки рендерятся ПОВЕРХ Overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _insertNavOverlay();
      _loadUnreadCount();
    });
  }

  void _insertNavOverlay() {
    _navOverlayEntry = OverlayEntry(
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;
        final bottomOffset = bottomPadding > 0 ? bottomPadding + 4.0 : 20.0;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          left: 36,
          right: 36,
          bottom: _navVisible ? bottomOffset : -100,
          child: AnimatedOpacity(
            opacity: _navVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: _FloatingPillNavInline(
              currentIndex: _currentIndex,
              unreadCount: _unreadCount,
              onTap: _onTabTapped,
            ),
          ),
        );
      },
    );

    // Вставляем в корневой Overlay (самый верхний в дереве)
    Overlay.of(context, rootOverlay: true).insert(_navOverlayEntry!);
  }

  @override
  void dispose() {
    _navOverlayEntry?.remove();
    _navOverlayEntry?.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) return;
  }

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    if (_currentIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _currentIndex = index);
    _navOverlayEntry?.markNeedsBuild();

    // Обновляем уведомления через Navigator
    if (index == 1) {
      final context = _navigatorKeys[1].currentContext;
      if (context != null) {
        final state = context
            .findAncestorStateOfType<NotificationsScreenState>();
        state?.refresh();
      }
    }

    if (index == 1 && _unreadCount > 0) {
      setState(() => _unreadCount = 0);
    }
  }

  Future<bool> _onWillPop() async {
    final nav = _navigatorKeys[_currentIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      _navOverlayEntry?.markNeedsBuild();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      // Scaffold без навбара в body — он живёт в корневом Overlay
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FA),
        body: Stack(
          children: [
            _buildTab(0, const HomeScreen()),
            _buildTab(1, const NotificationsScreen()),
            _buildTab(2, const ProfileScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, Widget screen) {
    return Offstage(
      offstage: _currentIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        observers: [_observers[index]],
        onGenerateRoute: (settings) => _tabRoute(settings, screen),
      ),
    );
  }

  Route<dynamic>? _tabRoute(RouteSettings settings, Widget root) {
    final name = settings.name;
    if (name == null || name == '/') {
      return MaterialPageRoute(builder: (_) => root, settings: settings);
    }
    if (name == '/appeals') {
      return MaterialPageRoute(
        builder: (_) => const AppealsScreen(),
        settings: settings,
      );
    }
    if (name == '/terms') {
      return MaterialPageRoute(
        builder: (_) => const TermsScreen(),
        settings: settings,
      );
    }
    if (name == '/user_type_selection') {
      return MaterialPageRoute(
        builder: (_) => const UserTypeSelectionScreen(),
        settings: settings,
      );
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Observer
// ─────────────────────────────────────────────────────────────────────────────
class _DepthObserver extends NavigatorObserver {
  final void Function(int depth) onDepthChanged;
  int _depth = 1;
  bool _initialPushDone = false;

  _DepthObserver({required this.onDepthChanged});

  void _push() {
    _depth++;
    onDepthChanged(_depth);
  }

  void _pop() {
    if (_depth > 1) _depth--;
    onDepthChanged(_depth);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_initialPushDone) {
      _initialPushDone = true;
      return; // первый push — корневой экран таба, не считаем
    }
    _push();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pop();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pop();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Pill Nav
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingPillNavInline extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  const _FloatingPillNavInline({
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
  });

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_green, _red],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(-4, 8),
          ),
          BoxShadow(
            color: _red.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(4, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AnimatedPillItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _AnimatedPillItem(
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications_rounded,
            isActive: currentIndex == 1,
            badge: unreadCount,
            onTap: () => onTap(1),
          ),
          _AnimatedPillItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            isActive: currentIndex == 2,
            onTap: () => onTap(2),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Анимированная иконка
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedPillItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  const _AnimatedPillItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    this.badge = 0,
  });

  @override
  State<_AnimatedPillItem> createState() => _AnimatedPillItemState();
}

class _AnimatedPillItemState extends State<_AnimatedPillItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _offsetY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.26,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.26,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.92,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
    ]).animate(_ctrl);

    _offsetY = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -7.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -7.0,
          end: 2.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 2.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_AnimatedPillItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        width: 72,
        height: 64,
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _offsetY.value),
              child: Transform.scale(scale: _scale.value, child: child),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: widget.isActive ? 44 : 0,
                  height: widget.isActive ? 36 : 0,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Icon(
                  widget.isActive ? widget.activeIcon : widget.icon,
                  size: 24,
                  color: widget.isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
                if (widget.isActive)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (widget.badge > 0)
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.badge > 99 ? '99+' : '${widget.badge}',
                        style: const TextStyle(
                          color: Color(0xFFD32F1E),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
