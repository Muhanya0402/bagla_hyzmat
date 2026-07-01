import 'dart:ui';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/appeals/appeals_screen.dart';
import 'package:bagla/features/home/home_screen.dart';
import 'package:bagla/features/home/widgets/home_create_button.dart';
import 'package:bagla/features/notifications/notifications_screen.dart';
import 'package:bagla/features/orders/create_order_screen.dart';
import 'package:bagla/features/profile/profile_screen.dart';
import 'package:bagla/features/profile/terms_screen.dart';
import 'package:bagla/features/profile/user_type_selection_screen.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  // ── Floating nav geometry — публичные константы ──────────────────────────
  static const double navBarHeight = 66;
  static const double navBarSideMargin = 32;
  static const double _navBarGap = 12;

  /// Сколько места снизу должен зарезервировать экран, чтобы навбар
  /// не перекрывал контент. Учитывает SafeArea + высоту bar'а + зазор.
  ///
  /// Используй в `padding.bottom` у скроллов под навбаром:
  /// ```dart
  /// ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, MainShell.bottomReserve(context)))
  /// ```
  static double bottomReserve(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final navOffset = safeBottom > 0 ? safeBottom + 4.0 : 20.0;
    return navBarHeight + navOffset + _navBarGap;
  }

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

  // Прямой ключ на экран уведомлений — чтобы вызвать refresh() при
  // переключении на таб. Раньше делалось через findAncestorStateOfType
  // от контекста Navigator'а, но экран — ПОТОМОК Navigator'а, не предок,
  // поэтому state всегда был null и рефреш не срабатывал.
  final GlobalKey<NotificationsScreenState> _notifKey = GlobalKey();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey();

  late final List<_DepthObserver> _observers;

  int _unreadCount = 0;

  Offset? _fabOffset;
  bool _isFabDragging = false;

  static const double _fabW = 162.0;
  static const double _fabH = 52.0;

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
          });
        },
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnreadCount());
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

    // После первого кадра (таб уже развернулся из Offstage):
    //  - рефреш уведомлений;
    //  - перезапуск гида для таба — на Offstage-табах initState отрабатывает
    //    на старте app, и его 12-сек polling истекает до того, как юзер
    //    откроет таб; здесь дожимаем запуск, когда таб реально стал видим.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (index == 1) {
        _notifKey.currentState?.refresh();
        // Открыли уведомления → помечаем все прочитанными (кнопки больше нет).
        _notifKey.currentState?.markAllReadOnOpen();
        _notifKey.currentState?.retryTourOnBecameVisible();
      } else if (index == 2) {
        _profileKey.currentState?.retryTourOnBecameVisible();
      } else if (index == 0) {
        // Вернулись на вкладку заказов → у заказчика сбрасываем статус на «Все».
        _homeKey.currentState?.resetStatusFilterForShop();
      }
    });

    if (index == 1 && _unreadCount > 0) {
      setState(() => _unreadCount = 0);
    }
  }

  void _onFabPanUpdate(
    DragUpdateDetails d,
    Size screen,
    double minY,
    double maxY,
  ) {
    setState(() {
      _isFabDragging = true;
      final dx = (_fabOffset!.dx + d.delta.dx).clamp(0.0, screen.width - _fabW);
      final dy = (_fabOffset!.dy + d.delta.dy).clamp(minY, maxY);
      _fabOffset = Offset(dx, dy);
    });
  }

  void _onFabPanEnd(DragEndDetails _, Size screen, double minY, double maxY) {
    final snappedX = _fabOffset!.dx + _fabW / 2 < screen.width / 2
        ? 20.0
        : screen.width - _fabW - 20.0;
    final clampedY = _fabOffset!.dy.clamp(minY, maxY);
    setState(() {
      _isFabDragging = false;
      _fabOffset = Offset(snappedX, clampedY);
    });
  }

  Future<bool> _onWillPop() async {
    final nav = _navigatorKeys[_currentIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final c = AppColors.of(context);

    final mq = MediaQuery.of(context);
    final bottomPadding = mq.padding.bottom;
    final bottomOffset = bottomPadding > 0 ? bottomPadding + 4.0 : 20.0;
    final screenSize = mq.size;

    final fabMinY = mq.padding.top + kToolbarHeight + 54.0;
    final fabMaxY = screenSize.height - _fabH - 66.0 - bottomOffset - 8.0;

    _fabOffset ??= Offset(screenSize.width - _fabW - 20.0, fabMaxY);

    final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final showNav = _navVisible && isTopRoute;

    final role = auth.role.toLowerCase().trim();
    final isShop = role == 'shop' || role == 'business';
    final isActive = auth.status.toLowerCase().trim() == 'active';
    final showFab = showNav && _currentIndex == 0 && isShop && isActive;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            _buildTab(0, HomeScreen(key: _homeKey)),
            _buildTab(1, NotificationsScreen(key: _notifKey)),
            _buildTab(2, ProfileScreen(key: _profileKey)),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: 32,
              right: 32,
              bottom: showNav ? bottomOffset : -100,
              child: IgnorePointer(
                ignoring: !showNav,
                child: AnimatedOpacity(
                  opacity: showNav ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: _FloatingNav(
                    currentIndex: _currentIndex,
                    unreadCount: _unreadCount,
                    onTap: _onTabTapped,
                  ),
                ),
              ),
            ),
            if (showFab)
              Positioned(
                left: _fabOffset!.dx,
                top: _fabOffset!.dy,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isFabDragging = true),
                  onPanUpdate: (d) =>
                      _onFabPanUpdate(d, screenSize, fabMinY, fabMaxY),
                  onPanEnd: (d) =>
                      _onFabPanEnd(d, screenSize, fabMinY, fabMaxY),
                  onTap: () => _navigatorKeys[0].currentState?.push(
                    MaterialPageRoute(
                      builder: (_) => const CreateOrderScreen(),
                    ),
                  ),
                  child: HomeCreateFab(
                    label: context.read<LanguageProvider>().words.createOrder,
                    isDragging: _isFabDragging,
                  ),
                ),
              ),
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
// Navigator depth observer
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
      return;
    }
    _push();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _pop();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _pop();
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating nav — glassmorphism pill
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingNav extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  const _FloatingNav({
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        // sigma 2 вместо 4 — визуально близко, ~4× дешевле для GPU.
        // BackdropFilter — самая дорогая операция в Flutter UI.
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.09),
                blurRadius: 28,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: c.ink.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications_rounded,
                isActive: currentIndex == 1,
                badge: unreadCount,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single nav item
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    this.badge = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: SizedBox(
        width: 64,
        height: 66,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Background tint pill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: 46,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.isActive ? c.emeraldTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),

                // Icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Icon(
                    widget.isActive ? widget.activeIcon : widget.icon,
                    key: ValueKey(widget.isActive),
                    size: 22,
                    color: widget.isActive ? c.ink : c.inkSoft,
                  ),
                ),

                // Bottom line indicator
                Positioned(
                  bottom: 7,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: widget.isActive ? 16.0 : 0.0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: c.ink,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),

                // Badge
                if (widget.badge > 0)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 14),
                      decoration: BoxDecoration(
                        color: c.errorMuted,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.badge > 99 ? '99+' : '${widget.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
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
