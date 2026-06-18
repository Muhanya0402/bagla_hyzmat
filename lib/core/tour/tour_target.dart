import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Фабрика шагов тура с единым стилем (AppColors + AppText).
///
/// Рекомендуемый способ — передавать уже локализованные строки:
/// ```dart
/// TourTarget.build(
///   key: _filterKey,
///   title: words.tourFiltersTitle,
///   body:  words.tourFiltersBody,
///   isLast: true,
/// )
/// ```
///
/// Legacy-режим (для экранов с хардкод-строками, ещё не переведённых в l10n):
/// ```dart
/// TourTarget.build(
///   key: _filterKey,
///   titleRu: 'Фильтры', titleTk: 'Süzgüçler',
///   bodyRu:  '...',     bodyTk:  '...',
///   isRu: isRu,
/// )
/// ```
class TourTarget {
  TourTarget._();

  static TargetFocus build({
    required GlobalKey key,
    // Стабильный идентификатор шага (T10). Если не задан — fallback на
    // key.hashCode. Явный id предпочтительнее: hashCode уникален per-
    // инстанс GlobalKey, но при пересоздании ключа меняется, а
    // tutorial_coach_mark использует identify для трекинга шагов.
    String? id,
    // ── New (preferred) — single localized string ──────────────────────────
    String? title,
    String? body,
    // ── Legacy — RU/TK split, выбор по isRu ──────────────────────────────
    String? titleRu,
    String? titleTk,
    String? bodyRu,
    String? bodyTk,
    bool isRu = true,
    bool isLast = false,
    ShapeLightFocus shape = ShapeLightFocus.RRect,
    double radius = 12,
    ContentAlign align = ContentAlign.top,
    // Use custom positioning when the target widget is very large (e.g. a full-
    // screen list) and the auto-calculated position would land off-screen.
    CustomTargetContentPosition? customPosition,
  }) {
    final String effectiveTitle =
        title ?? (isRu ? (titleRu ?? '') : (titleTk ?? ''));
    final String effectiveBody =
        body ?? (isRu ? (bodyRu ?? '') : (bodyTk ?? ''));

    final effectiveAlign = customPosition != null
        ? ContentAlign.custom
        : align;
    return TargetFocus(
      identify: id ?? key.hashCode.toString(),
      keyTarget: key,
      shape: shape,
      radius: radius,
      paddingFocus: 10,
      // Тап по подсветке больше не продвигает тур — только кнопка «Далее».
      enableTargetTab: false,
      enableOverlayTab: false,
      contents: [
        TargetContent(
          align: effectiveAlign,
          customPosition: customPosition,
          builder: (_, controller) => _TourCard(
            title: effectiveTitle,
            body: effectiveBody,
            isLast: isLast,
            onNext: controller.next,
            onSkip: controller.skip,
          ),
        ),
      ],
    );
  }
}

// ─── Карточка подсказки ───────────────────────────────────────────────────────

class _TourCard extends StatelessWidget {
  final String title;
  final String body;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TourCard({
    required this.title,
    required this.body,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // `read`, не `watch`: тур транзиентный, язык не меняется во время показа.
    // watch вызывал бы лишние rebuild'ы overlay-контента.
    final isRu = context.read<LanguageProvider>().isRu;
    final nextLabel = isLast
        ? (isRu ? 'Понятно' : 'Düşnükli')
        : (isRu ? 'Далее' : 'Indiki');
    final skipLabel = isRu ? 'Пропустить' : 'Geç';

    // #2-fix: пакет НЕ оборачивает контент-карточку в SafeArea (только
    // Skip-кнопку). Без этого карточка с кнопкой «Понятно» при размещении
    // у верха экрана уходит за статус-бар. SafeArea сдвигает её в
    // безопасную зону (сверху — из-под статус-бара, снизу — из-под навбара).
    return SafeArea(
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppText.serif(fontSize: 15, color: c.ink),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppText.regular(fontSize: 13, color: c.inkMuted)
                .copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          // Skip + Next в одном ряду внутри карточки. Раньше «Пропустить»
          // была отдельной плавающей кнопкой внизу справа и наезжала на
          // «Далее» (#8) — теперь обе живут в карточке и не пересекаются.
          Row(
            children: [
              if (!isLast)
                _TourSkipButton(label: skipLabel, onPressed: onSkip),
              const Spacer(),
              _TourNextButton(label: nextLabel, onPressed: onNext),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _TourSkipButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _TourSkipButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Text(
            label,
            style: AppText.medium(fontSize: 13, color: c.inkSoft),
          ),
        ),
      ),
    );
  }
}

class _TourNextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _TourNextButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: AppText.semiBold(fontSize: 13, color: Colors.white)
                .copyWith(letterSpacing: 0.1),
          ),
        ),
      ),
    );
  }
}
