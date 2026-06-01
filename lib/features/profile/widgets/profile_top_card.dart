import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/user_avatar.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/levels/level_card_widget.dart';
import 'package:bagla/features/levels/level_provider.dart';
import 'package:bagla/features/profile/widgets/pulse_dot.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class _StatusCfg {
  final Color color;
  final Color bg;
  final String label;
  const _StatusCfg({
    required this.color,
    required this.bg,
    required this.label,
  });
}

class ProfileTopCard extends StatefulWidget {
  final AuthProvider auth;
  final String fullName;
  final bool isCourier;

  const ProfileTopCard({
    super.key,
    required this.auth,
    required this.fullName,
    required this.isCourier,
  });

  @override
  State<ProfileTopCard> createState() => _ProfileTopCardState();
}

class _ProfileTopCardState extends State<ProfileTopCard> {
  @override
  void initState() {
    super.initState();
    if (widget.isCourier && widget.auth.userId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final lp = context.read<LevelProvider>();
        if (!lp.isLoading && lp.currentLevel == null) {
          lp.loadForUser(widget.auth.userId);
        }
      });
    }
  }

  String _roleLabel(AppLocalizations w) {
    switch (widget.auth.role) {
      case 'courier':
        return w.roleCourierLabel;
      case 'shop':
      case 'business':
        return w.roleShopLabel;
      case 'client':
        return w.roleObserverLabel;
      default:
        return '—';
    }
  }

  _StatusCfg _cfg(String s, AppColors c, AppLocalizations w) {
    switch (s) {
      case 'active':
        return _StatusCfg(
          color: c.ink,
          bg: c.emeraldTint,
          label: w.statusActiveLabel,
        );
      case 'pending':
        return _StatusCfg(
          color: c.amber,
          bg: c.amberTint,
          label: w.statusPendingLabel,
        );
      case 'banned':
        return _StatusCfg(
          color: c.errorMuted,
          bg: c.errorTint,
          label: w.statusBannedLabel,
        );
      case 'published':
        return _StatusCfg(
          color: c.inkMuted,
          bg: c.borderSoft,
          label: w.statusPublishedLabel,
        );
      default:
        return _StatusCfg(color: c.inkSoft, bg: c.bg, label: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final cfg = _cfg(widget.auth.status, c, words);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar + status badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      // selfie_scan UUID. Если пустой — fallback на букву имени.
                      fileId: widget.auth.selfieFileId,
                      name: widget.fullName,
                      size: 48, // inner-диаметр; с рамкой 2 + padding 3 → 58 total
                      borderColor: cfg.color,
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cfg.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.surface, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widget.auth.isActive
                                ? PulseDot(color: cfg.color)
                                : Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: cfg.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            const SizedBox(width: 3),
                            Text(
                              cfg.label,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: cfg.color,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Name + role + phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.fullName,
                              style: AppText.serif(fontSize: 17, color: c.ink),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.emeraldTint,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _roleLabel(words),
                              style: AppText.semiBold(
                                fontSize: 10,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 11,
                            color: c.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.auth.phone.isNotEmpty
                                ? widget.auth.phone
                                : '+993 ...',
                            style: AppText.regular(
                              fontSize: 12,
                              color: c.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Level progress (courier)
          if (widget.isCourier)
            Consumer<LevelProvider>(
              builder: (_, lp, _) {
                final c2 = AppColors.of(context);
                if (lp.isLoading || lp.currentLevel == null) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: c2.borderSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
                final level = lp.currentLevel!;
                final progress = lp.progressInLevel.clamp(0.0, 1.0);
                final nextXp = lp.nextLevel?.xpRequired;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showLevelDetailsSheet(
                    context,
                    provider: lp,
                    words: words,
                    isRu: lang.isRu,
                  ),
                  child: Column(
                    children: [
                      Divider(height: 1, thickness: 0.8, color: c2.borderSoft),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 11, 16, 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.emoji_events_outlined,
                                  size: 13,
                                  color: c2.amber,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${level.title(lang.isRu)}  •  ${words.profileLevelShort} ${level.levelNumber}',
                                  style: AppText.medium(
                                    fontSize: 12,
                                    color: c2.inkMuted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  nextXp != null
                                      ? '${lp.currentXp} / $nextXp XP'
                                      : '${lp.currentXp} XP',
                                  style: AppText.semiBold(
                                    fontSize: 11,
                                    color: c2.ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: c2.amberTint,
                                valueColor: AlwaysStoppedAnimation(c2.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
