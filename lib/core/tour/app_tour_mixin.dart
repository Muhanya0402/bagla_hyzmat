import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  TutorialCoachMark? _coachMark;

  /// Запускает тур, если экран ещё не пройден.
  ///
  /// [screenKey]      — ключ из TourKeys.
  /// [targetsBuilder] — ленивая функция, строящая шаги только после
  ///                    завершения первого кадра (GlobalKey гарантированно
  ///                    прикреплены к дереву).
  /// [forceShow]      — показать несмотря на сохранённое состояние
  ///                    (удобно для кнопки «Повторить гид»).
  void startTourIfNeeded({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
    bool forceShow = false,
  }) {
    if (!forceShow && TourManager.instance.isSeen(screenKey)) {
      debugPrint('🗺️  [$screenKey] тур пропущен — уже пройден');
      return;
    }

    debugPrint('🗺️  [$screenKey] планируем запуск тура (forceShow=$forceShow)');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        debugPrint('🗺️  [$screenKey] отменено — виджет уже не mounted');
        return;
      }
      final targets = targetsBuilder();
      debugPrint('🗺️  [$screenKey] шагов: ${targets.length}');
      if (targets.isEmpty) return;
      _launch(screenKey: screenKey, targets: targets);
    });
  }

  void _launch({
    required String screenKey,
    required List<TargetFocus> targets,
  }) {
    debugPrint('🗺️  [$screenKey] тур запущен');
    final isRu = context.read<LanguageProvider>().isRu;
    _coachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: AppColors.of(context).ink,
      opacityShadow: 0.80,
      paddingFocus: 10,
      focusAnimationDuration: const Duration(milliseconds: 350),
      pulseAnimationDuration: const Duration(milliseconds: 900),
      skipWidget: _TourSkipButton(isRu: isRu),
      onFinish: () {
        debugPrint('🗺️  [$screenKey] тур завершён (finish)');
        TourManager.instance.markSeen(screenKey);
      },
      onSkip: () {
        debugPrint('🗺️  [$screenKey] тур пропущен (skip)');
        TourManager.instance.markSeen(screenKey);
        return true;
      },
    )..show(context: context);
  }

  /// Программный сброс и повторный запуск тура (например, из меню настроек).
  Future<void> replayTour({
    required String screenKey,
    required List<TargetFocus> Function() targetsBuilder,
  }) async {
    debugPrint('🗺️  [$screenKey] replayTour — сброс и перезапуск');
    await TourManager.instance.resetScreen(screenKey);
    startTourIfNeeded(
      screenKey: screenKey,
      targetsBuilder: targetsBuilder,
      forceShow: true,
    );
  }

  @override
  void dispose() {
    _coachMark?.skip();
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
        style: AppText.medium(fontSize: 13, color: AppColors.of(context).inkMuted),
      ),
    );
  }
}
