import 'dart:async';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  //
  // T1/T2-fix: вместо голого bool храним ВЛАДЕЛЬЦА (State, запустивший тур).
  // Это даёт:
  //   - owner-check в dispose/onFinish — не сбрасываем чужой флаг;
  //   - self-heal: если владелец размонтирован (краш/гонка) без вызова
  //     onFinish, следующий экран это заметит (`!owner.mounted`) и заберёт
  //     блокировку — раньше bool «залипал» и ВСЕ туры умирали до рестарта.
  static State? _tourOwner;
  static bool get _isAnyTourRunning {
    final owner = _tourOwner;
    if (owner != null && !owner.mounted) {
      // Владелец мёртв — освобождаем lock (self-heal).
      _tourOwner = null;
      return false;
    }
    return owner != null;
  }

  // T14: момент завершения последнего тура — для cooldown'а между турами,
  // чтобы при быстрой навигации не показывать тур-за-туром встык.
  static DateTime? _lastTourFinishedAt;
  static const _interTourCooldown = Duration(milliseconds: 700);

  // T3: ограничение числа retry-попыток. 40 × 300ms = 12 сек. Если за это
  // время таб так и не стал видимым — прекращаем polling (раньше таймер
  // тикал бесконечно для никогда-не-открываемых табов → расход батареи).
  static const _maxRetryAttempts = 40;
  int _retryAttempts = 0;

  TutorialCoachMark? _coachMark;
  Timer? _tourRetryTimer;

  // Сохранённые параметры последнего startTourIfNeeded — нужны, чтобы
  // повторно попытаться запустить тур, когда Offstage-таб развернулся
  // (см. retryTourOnBecameVisible).
  String? _savedScreenKey;
  List<TargetFocus> Function()? _savedTargetsBuilder;
  bool Function()? _savedShouldSkip;
  bool _savedForceShow = false;

  /// Запускает тур, если экран ещё не пройден.
  ///
  /// Если виджет находится в неактивном `Offstage`-табе (MainShell), тур
  /// откладывается и запускается автоматически, когда таб становится видимым.
  ///
  /// [shouldSkip] — опциональный ранний гард (T4/T15). Если вернёт true,
  /// тур не запускается И не помечается seen. Передавай
  /// `() => context.read<AuthProvider>().shouldSkipTour` чтобы banned/
  /// pending юзеры не видели тур. Проверяется ДО построения targets и ДО
  /// isSeen — раньше эта проверка жила внутри targetsBuilder, выполнялась
  /// поздно и была лишь в 4 из 11 экранов.
  void startTourIfNeeded({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
    bool Function()? shouldSkip,
    bool forceShow = false,
  }) {
    // ВАЖНО: НЕ делаем eager isSeen-check здесь. На cold-start TourManager
    // ещё может не знать `_userId` (AuthProvider.loadUserData ещё в полёте).
    // isSeen с пустым namespace вернёт false, тур запустится впустую. Все
    // проверки делаются в `_tryLaunch` ПОСЛЕ синхронизации userId.

    // Сохраняем параметры для возможного повторного запуска при
    // разворачивании Offstage-таба (retryTourOnBecameVisible).
    _savedScreenKey = screenKey;
    _savedTargetsBuilder = targetsBuilder;
    _savedShouldSkip = shouldSkip;
    _savedForceShow = forceShow;

    // Ранний skip-гард — banned/pending не должны даже планировать тур.
    if (!forceShow && shouldSkip != null && shouldSkip()) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isVisible()) {
        _scheduleRetry(
          screenKey: screenKey,
          targetsBuilder: targetsBuilder,
          shouldSkip: shouldSkip,
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
              shouldSkip: shouldSkip,
              forceShow: forceShow,
            );
          }
        }
        animation.addStatusListener(onStatus);
      } else {
        _tryLaunch(
          screenKey: screenKey,
          targetsBuilder: targetsBuilder,
          shouldSkip: shouldSkip,
          forceShow: forceShow,
        );
      }
    });
  }

  /// Повторная попытка запустить тур, когда экран стал ВИДИМЫМ (его таб
  /// развернулся из Offstage в MainShell).
  ///
  /// Зачем: в MainShell все табы создаются на старте app внутри Offstage,
  /// поэтому `initState` (и его polling видимости с лимитом ~12с) у
  /// Notifications/Profile отрабатывает задолго до того, как пользователь
  /// откроет таб — ретрай истекает, и тур там «не срабатывает». MainShell
  /// зовёт этот метод при переключении на таб.
  ///
  /// Безопасно вызывать повторно: `_tryLaunch` сам проверит isSeen и
  /// глобальный лок, так что тур не запустится дважды.
  void retryTourOnBecameVisible() {
    final key = _savedScreenKey;
    final builder = _savedTargetsBuilder;
    if (key == null || builder == null) return;
    if (_coachMark != null) return; // наш тур уже показывается
    _tourRetryTimer?.cancel();
    _retryAttempts = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isVisible()) return;
      _tryLaunch(
        screenKey: key,
        targetsBuilder: builder,
        shouldSkip: _savedShouldSkip,
        forceShow: _savedForceShow,
      );
    });
  }

  // Polls every 300 ms until the tab becomes visible, then launches the tour.
  // T3: останавливается после `_maxRetryAttempts` (12 сек) — не крутится
  // вечно для табов, которые пользователь не открывает.
  void _scheduleRetry({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
    required bool Function()? shouldSkip,
    required bool forceShow,
  }) {
    _tourRetryTimer?.cancel();
    _retryAttempts = 0;
    _tourRetryTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) {
        _tourRetryTimer?.cancel();
        return;
      }
      if (++_retryAttempts > _maxRetryAttempts) {
        // Дали табу 12 сек стать видимым — не дождались. Прекращаем
        // polling, тур запустится при следующем заходе на экран.
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
          shouldSkip: shouldSkip,
          forceShow: forceShow,
        );
      });
    });
  }

  Future<void> _tryLaunch({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
    required bool Function()? shouldSkip,
    required bool forceShow,
  }) async {
    // Повторная проверка skip-гарда — статус мог измениться пока тур
    // ждал видимости таба / завершения анимации.
    if (!forceShow && shouldSkip != null && shouldSkip()) return;
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

    // T14: cooldown между турами — при быстрой навигации не показываем
    // следующий тур встык. Если ещё рано — переотложим через retry.
    final lastFinished = _lastTourFinishedAt;
    if (!forceShow && lastFinished != null) {
      final sinceFinish = DateTime.now().difference(lastFinished);
      if (sinceFinish < _interTourCooldown) {
        _tourRetryTimer?.cancel();
        _tourRetryTimer = Timer(_interTourCooldown - sinceFinish, () {
          if (!mounted) return;
          _tryLaunch(
            screenKey: screenKey,
            targetsBuilder: targetsBuilder,
            shouldSkip: shouldSkip,
            forceShow: forceShow,
          );
        });
        return;
      }
    }

    // T9: mounted-check прямо перед построением targets/launch — между
    // началом _tryLaunch и этой точкой были await'ы (prefs) и слушатель
    // анимации, context мог стать невалидным.
    if (!mounted) return;

    // #1-fix: не запускаем тур, если экран уже НЕ текущий маршрут.
    // Сценарий: пока тур планировался, ApiClient поймал 401 и
    // pushNamedAndRemoveUntil('/login') подменил стек — тогда тур
    // не должен всплыть поверх экрана авторизации.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    final targets = _filterMountedTargets(targetsBuilder());
    if (targets.isEmpty) return;
    if (!mounted) return;
    _launch(screenKey: screenKey, targets: targets);
  }

  /// Оставляет только таргеты, чьи виджеты реально в дереве.
  /// Если у TargetFocus есть keyTarget без currentContext (условный виджет
  /// не отрисован), пакет при фокусе бросает NotFoundTargetException и
  /// прерывает ВЕСЬ тур. Фильтр спасает: пропускаем «мёртвые» шаги.
  List<TargetFocus> _filterMountedTargets(List<TargetFocus> targets) {
    return targets.where((t) {
      // targetPosition-таргеты (без key) оставляем как есть.
      if (t.keyTarget == null) return true;
      return t.keyTarget!.currentContext != null;
    }).toList();
  }

  /// #3-fix: прокручивает таргет в видимую зону перед фокусом, оставляя место
  /// для карточки подсказки.
  ///
  /// Ключевой момент: выравнивание скролла зависит от того, КУДА растёт
  /// карточка относительно цели:
  ///   - `ContentAlign.bottom` (карточка СНИЗУ) → подводим цель к ВЕРХУ
  ///     вьюпорта, чтобы внизу осталось место под карточку с кнопками;
  ///   - `ContentAlign.top` (карточка СВЕРХУ) → подводим цель к НИЗУ;
  ///   - иначе — центрируем.
  /// Без этого у высоких целей (например блок «Местоположение») карточка
  /// с «Понятно/Пропустить» уезжала за нижний край и была недоступна.
  ///
  /// Для таргетов вне Scrollable (AppBar) — no-op. Пакет await'ит
  /// `beforeFocus`, поэтому spotlight берёт уже новую позицию.
  Future<void> _scrollTargetIntoView(TargetFocus target) async {
    final ctx = target.keyTarget?.currentContext;
    if (ctx == null) return;
    // ВАЖНО: не используем `Scrollable.maybeOf(ctx) == null` как гард —
    // для контекста KeyedSubtree-якоря он возвращает null (ищет по element-
    // дереву), хотя ensureVisible находит вьюпорт через render-дерево и
    // отлично скроллит (так делает рабочий _scrollTo в форме регистрации).
    // Для целей вне скролла (AppBar) ensureVisible просто бросит — ловим.

    final ContentAlign align =
        (target.contents != null && target.contents!.isNotEmpty)
            ? target.contents!.first.align
            : ContentAlign.bottom;
    final double alignment = switch (align) {
      ContentAlign.bottom => 0.12, // цель вверху → место под карточку снизу
      ContentAlign.top => 0.88, // цель внизу → место под карточку сверху
      _ => 0.5,
    };

    try {
      await Scrollable.ensureVisible(
        ctx,
        alignment: alignment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      // даём кадру осесть, чтобы localToGlobal вернул финальную позицию
      await Future<void>.delayed(const Duration(milliseconds: 60));
    } catch (_) {
      // ensureVisible может бросить если контекст устарел — игнорируем.
    }
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
    // T1/T2: становимся владельцем глобальной блокировки.
    _tourOwner = this;
    _coachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: AppColors.of(context).ink,
      opacityShadow: 0.80,
      paddingFocus: 10,
      focusAnimationDuration: const Duration(milliseconds: 350),
      // #3-fix: перед каждым шагом прокручиваем таргет в видимую зону.
      beforeFocus: _scrollTargetIntoView,
      // #1-fix: Android-back во время тура закрывает ТУР, а не уводит
      // с экрана (раньше back мог попнуть маршрут и увести на login).
      disableBackButton: true,
      // Без пульсации — спокойный «editorial» вид без отвлекающего ритма.
      pulseAnimationDuration: Duration.zero,
      pulseEnable: false,
      // #8-fix: плавающую кнопку «Пропустить» убрали — она наезжала на
      // «Далее» в карточке (карточка почти на всю ширину, сдвиг по
      // горизонтали не спасал). Теперь «Пропустить» живёт ВНУТРИ карточки
      // рядом с «Далее» (см. _TourCard), а пакетный skip скрыт.
      hideSkip: true,
      onFinish: () {
        // Освобождаем lock только если ВЛАДЕЛЕЦ — мы (T2: не сбрасываем
        // чужой тур, если был race).
        if (_tourOwner == this) _tourOwner = null;
        _coachMark = null;
        _lastTourFinishedAt = DateTime.now(); // T14
        TourManager.instance.markSeen(screenKey);
      },
      onSkip: () {
        if (_tourOwner == this) _tourOwner = null;
        _coachMark = null;
        _lastTourFinishedAt = DateTime.now(); // T14
        TourManager.instance.markSeen(screenKey);
        return true;
      },
    )..show(context: context, rootOverlay: true);
  }

  /// Программный сброс и повторный запуск тура («Повторить обучение»).
  ///
  /// ⚠️ НЕ идём через `startTourIfNeeded`/`_tryLaunch` — там авто-гейтинг
  /// (isSeen, cooldown, `_isAnyTourRunning`, guard на `route.isCurrent`),
  /// который для ЯВНОГО пользовательского replay только мешает (и тихо
  /// глотал запуск — отсюда «не работает»). Запускаем напрямую: сбрасываем
  /// seen-флаг, гасим активный тур, ждём кадр и показываем.
  Future<void> replayTour({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
  }) async {
    await TourManager.instance.resetScreen(screenKey);
    if (!mounted) return;

    // Гасим возможный активный тур и освобождаем глобальный lock —
    // чтобы replay не упёрся в «уже идёт тур».
    _coachMark?.skip();
    _coachMark = null;
    if (_tourOwner == this) _tourOwner = null;

    // Ждём кадр (закрытие предыдущего overlay + раскладка), затем launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targets = _filterMountedTargets(targetsBuilder());
      if (targets.isEmpty) return;
      _launch(screenKey: screenKey, targets: targets);
    });
  }

  @override
  void dispose() {
    _tourRetryTimer?.cancel();
    if (_coachMark != null) {
      // T2: освобождаем глобальный lock только если это НАШ тур.
      if (_tourOwner == this) _tourOwner = null;
      _coachMark?.skip();
      _coachMark = null;
    }
    super.dispose();
  }
}
