import 'dart:async';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'tour_manager.dart';

/// Mixin для `State<T>`. Инкапсулирует запуск тура, lifecycle-безопасность
/// и интеграцию с TourManager.
///
/// Использование:
/// ```dart
/// class _HomeScreenState extends State<HomeScreen> with AppTourMixin {
///   @override
///   void initState() {
///     super.initState();
///     startTourIfNeeded(
///       screenKey: TourKeys.home,
///       targetsBuilder: _buildTargets,
///     );
///   }
/// }
/// ```
mixin AppTourMixin<T extends StatefulWidget> on State<T> {
  // Global lock — only one tour at a time across all screens.
  static bool _isAnyTourRunning = false;

  TutorialCoachMark? _coachMark;
  Timer? _tourRetryTimer;

  /// Запускает тур, если экран ещё не пройден.
  ///
  /// Если виджет находится в неактивном `Offstage`-табе (MainShell), тур
  /// откладывается и запускается автоматически, когда таб становится видимым.
  void startTourIfNeeded({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
    bool forceShow = false,
  }) {
    // ВАЖНО: НЕ делаем eager isSeen-check здесь. На cold-start TourManager
    // ещё может не знать `_userId` (AuthProvider.loadUserData ещё в полёте).
    // isSeen с пустым namespace вернёт false, тур запустится впустую. Все
    // проверки делаются в `_tryLaunch` ПОСЛЕ синхронизации userId.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isVisible()) {
        _scheduleRetry(
          screenKey: screenKey,
          targetsBuilder: targetsBuilder,
          forceShow: forceShow,
        );
        return;
      }
      // If the screen is a pushed route still mid-transition, wait for the
      // animation to complete before reading GlobalKey positions — otherwise
      // localToGlobal returns positions that include the slide offset and the
      // spotlight lands in the wrong place (e.g. at the top of the screen).
      final animation = ModalRoute.of(context)?.animation;
      if (animation != null &&
          animation.status != AnimationStatus.completed) {
        void onStatus(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            animation.removeStatusListener(onStatus);
            if (!mounted) return;
            _tryLaunch(
              screenKey: screenKey,
              targetsBuilder: targetsBuilder,
              forceShow: forceShow,
            );
          }
        }
        animation.addStatusListener(onStatus);
      } else {
        _tryLaunch(
          screenKey: screenKey,
          targetsBuilder: targetsBuilder,
          forceShow: forceShow,
        );
      }
    });
  }

  // Polls every 300 ms until the tab becomes visible, then launches the tour.
  void _scheduleRetry({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
    required bool forceShow,
  }) {
    _tourRetryTimer?.cancel();
    _tourRetryTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) {
        _tourRetryTimer?.cancel();
        return;
      }
      if (_isAnyTourRunning) return;
      if (!_isVisible()) return;
      _tourRetryTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tryLaunch(
          screenKey: screenKey,
          targetsBuilder: targetsBuilder,
          forceShow: forceShow,
        );
      });
    });
  }

  Future<void> _tryLaunch({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
    required bool forceShow,
  }) async {
    // Синхронизация userId — критично для cold-start race.
    //
    // Сценарий бага:
    //   1. App start → AuthProvider() ctor вызывает loadUserData() (async)
    //   2. Параллельно HomeScreen.initState() → startTourIfNeeded() →
    //      postFrameCallback → _tryLaunch до того как loadUserData
    //      успел вызвать TourManager.setUserId(123)
    //   3. isSeen(home_screen) → проверяет `tour_passed_home_screen`
    //      (без uid) → false → тур запускается
    //   4. Пользователь проходит тур → markSeen пишет
    //      `tour_passed_123_home_screen=true` (т.к. loadUserData
    //      уже завершился)
    //   5. Следующий запуск — та же гонка → тур опять «не пройден» → loop
    //
    // Фикс: перед isSeen-check читаем `user_id` напрямую из prefs и
    // форсим TourManager.setUserId(...). Если prefs уже содержит user_id
    // (что верно для re-launch'а), TourManager сразу станет правильным.
    if (!forceShow) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final uid = prefs.getString('user_id') ?? '';
        if (uid.isNotEmpty) {
          TourManager.instance.setUserId(uid);
        }
      } catch (_) {
        // prefs read failed — продолжаем с тем что есть, безопасный fallback
      }
      if (!mounted) return;
      if (TourManager.instance.isSeen(screenKey)) return;
    }
    if (_isAnyTourRunning) return;
    final targets = targetsBuilder();
    if (targets.isEmpty) return;
    _launch(screenKey: screenKey, targets: targets);
  }

  // Returns false if any ancestor RenderOffstage has offstage == true.
  bool _isVisible() {
    try {
      RenderObject? obj = context.findRenderObject();
      while (obj != null) {
        if (obj is RenderOffstage && obj.offstage) return false;
        final parent = obj.parent;
        obj = parent is RenderObject ? parent : null;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  void _launch({
    required String screenKey,
    required List<TargetFocus> targets,
  }) {
    _isAnyTourRunning = true;
    final isRu = context.read<LanguageProvider>().isRu;
    _coachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: AppColors.of(context).ink,
      opacityShadow: 0.80,
      paddingFocus: 10,
      focusAnimationDuration: const Duration(milliseconds: 350),
      // Без пульсации — спокойный «editorial» вид без отвлекающего ритма.
      pulseAnimationDuration: Duration.zero,
      pulseEnable: false,
      // Skip уехал в bottom-right: тултипы для AppBar-таргетов (logout,
      // mark-all, logo) появляются сразу под appbar — там же, где раньше
      // висел Skip → визуально сливались. Снизу подсказки почти не
      // отрисовываются (последний шаг прибит CustomTargetContentPosition,
      // см. home_screen / order_detail).
      alignSkip: Alignment.bottomRight,
      useSafeArea: true,
      skipWidget: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 20,
          right: 12,
        ),
        child: _TourSkipButton(isRu: isRu),
      ),
      onFinish: () {
        _isAnyTourRunning = false;
        TourManager.instance.markSeen(screenKey);
      },
      onSkip: () {
        _isAnyTourRunning = false;
        TourManager.instance.markSeen(screenKey);
        return true;
      },
    )..show(context: context, rootOverlay: true);
  }

  /// Программный сброс и повторный запуск тура (например, из меню настроек).
  Future<void> replayTour({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
  }) async {
    await TourManager.instance.resetScreen(screenKey);
    startTourIfNeeded(
      screenKey: screenKey,
      targetsBuilder: targetsBuilder,
      forceShow: true,
    );
  }

  @override
  void dispose() {
    _tourRetryTimer?.cancel();
    if (_coachMark != null) {
      _isAnyTourRunning = false;
      _coachMark?.skip();
    }
    super.dispose();
  }
}

// ── Кнопка «Пропустить» ───────────────────────────────────────────────────────

class _TourSkipButton extends StatelessWidget {
  final bool isRu;
  const _TourSkipButton({required this.isRu});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).ink.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        isRu ? 'Пропустить' : 'Geç',
        style: AppText.medium(
          fontSize: 13,
          color: AppColors.of(context).inkMuted,
        ),
      ),
    );
  }
}
