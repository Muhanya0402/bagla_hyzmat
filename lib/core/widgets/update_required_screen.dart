import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/app_version.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Экран «нужно обновиться», дальше которого не пройти.
///
/// Показывается, когда версия на устройстве ниже минимальной, заданной в
/// Directus для этой платформы. Нужен, чтобы серверную часть можно было
/// менять, не гадая, у скольких людей осталась несовместимая сборка.
///
/// Выхода с экрана намеренно нет: если версия объявлена неподдерживаемой,
/// работа в ней может испортить данные — например, старый клиент не знает
/// про новые проверки на сервере и покажет человеку неверное состояние.
///
/// Ссылка на обновление берётся из настроек и может быть пустой — пока
/// приложение раздаётся вручную, вести человека некуда, и вместо кнопки
/// показывается просьба обратиться в поддержку.
class UpdateRequiredScreen extends StatelessWidget {
  final AppLocalizations words;
  final String updateUrl;

  const UpdateRequiredScreen({
    super.key,
    required this.words,
    required this.updateUrl,
  });

  Future<void> _openUpdate() async {
    final uri = Uri.tryParse(updateUrl.trim());
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hasLink = updateUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.amberTint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    size: 34,
                    color: c.amber,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  words.updateRequiredTitle,
                  textAlign: TextAlign.center,
                  style: AppText.serif(fontSize: 19, color: c.ink),
                ),
                const SizedBox(height: 10),
                Text(
                  words.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: AppText.regular(fontSize: 14, color: c.inkMuted)
                      .copyWith(height: 1.45),
                ),
                if (AppVersion.display.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${words.updateRequiredYourVersion}: ${AppVersion.display}',
                    style: AppText.regular(fontSize: 12, color: c.inkSoft),
                  ),
                ],
                const SizedBox(height: 26),
                if (hasLink)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Material(
                      color: c.ink,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _openUpdate,
                        child: Center(
                          child: Text(
                            words.updateRequiredButton,
                            style: AppText.semiBold(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    words.updateRequiredNoLink,
                    textAlign: TextAlign.center,
                    style: AppText.medium(fontSize: 13, color: c.ink),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
