import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Фабрика шагов тура с единым стилем (AuthColors + AppText).
///
/// Использование:
/// ```dart
/// TourTarget.build(
///   key: _filterKey,
///   titleRu: 'Фильтры', titleTk: 'Süzgüçler',
///   bodyRu:  'Фильтруй заказы по городу и типу.',
///   bodyTk:  'Sargytlary şäher we görnüş boýunça süzüň.',
///   isRu: isRu,
/// )
/// ```
class TourTarget {
  TourTarget._();

  static TargetFocus build({
    required GlobalKey key,
    required String titleRu,
    required String titleTk,
    required String bodyRu,
    required String bodyTk,
    required bool isRu,
    ShapeLightFocus shape = ShapeLightFocus.RRect,
    double radius = 12,
    ContentAlign align = ContentAlign.top,
    // Use custom positioning when the target widget is very large (e.g. a full-
    // screen list) and the auto-calculated position would land off-screen.
    CustomTargetContentPosition? customPosition,
  }) {
    final effectiveAlign =
        customPosition != null ? ContentAlign.custom : align;
    return TargetFocus(
      identify: key.hashCode.toString(),
      keyTarget: key,
      shape: shape,
      radius: radius,
      paddingFocus: 10,
      contents: [
        TargetContent(
          align: effectiveAlign,
          customPosition: customPosition,
          builder: (_, _) => _TourCard(
            title: isRu ? titleRu : titleTk,
            body: isRu ? bodyRu : bodyTk,
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
  const _TourCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).ink.withValues(alpha: 0.10),
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
            style: AppText.serif(fontSize: 15, color: AppColors.of(context).ink),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppText.regular(fontSize: 13, color: AppColors.of(context).inkMuted)
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
