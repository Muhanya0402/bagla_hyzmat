import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'level_provider.dart';
import 'dart:math';

// ─── Public helper ────────────────────────────────────────────────────────────

void showLevelDetailsSheet(
  BuildContext context, {
  required LevelProvider provider,
  required AppLocalizations words,
  required bool isRu,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _LevelDetailsSheet(provider: provider, w: words, isRu: isRu),
  );
}

// ─── LevelCardWidget ──────────────────────────────────────────────────────────

class LevelCardWidget extends StatefulWidget {
  const LevelCardWidget({super.key});

  @override
  State<LevelCardWidget> createState() => _LevelCardWidgetState();
}

class _LevelCardWidgetState extends State<LevelCardWidget> {
  bool _dialogShown = false;
  bool _expanded = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.userId.isEmpty) return;
    final provider = context.read<LevelProvider>();
    await provider.loadForUser(auth.userId);
    if (mounted) _checkPendingLevelUp();
  }

  void _checkPendingLevelUp() {
    if (_dialogShown) return;
    final provider = context.read<LevelProvider>();
    if (provider.pendingLevelUp != null) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLevelUpDialog(context.read<LanguageProvider>().isRu);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    return Consumer<LevelProvider>(
      builder: (_, provider, _) {
        if (provider.pendingLevelUp != null && !_dialogShown) {
          _dialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLevelUpDialog(lang.isRu);
          });
        }
        if (provider.isLoading) return _buildSkeleton();
        if (provider.currentLevel == null) return _buildDebugEmpty(provider);
        return _buildCard(provider, lang.words, lang.isRu);
      },
    );
  }

  Widget _buildDebugEmpty(LevelProvider provider) {
    final reason = provider.allLevels.isEmpty
        ? 'level_definitions пустой или нет прав доступа'
        : 'current_level_id не заполнен у курьера в Directus';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthColors.amberTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AuthColors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason,
              style: AppText.medium(fontSize: 12, color: AuthColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(LevelProvider p, AppLocalizations w, bool isRu) {
    final level = p.currentLevel!;
    final hasBonuses = level.bonuses.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() {
          _pressed = false;
          if (hasBonuses) _expanded = !_expanded;
        });
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AuthColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    // ── Amber circle emblem ──────────────────────────────────
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AuthColors.amberTint,
                        border: Border.all(
                          color: AuthColors.amber.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${level.levelNumber}',
                        style: AppText.semiBold(fontSize: 22, color: AuthColors.amber),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // ── Title + progress ────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  level.title(isRu),
                                  style: AppText.serif(fontSize: 15, color: AuthColors.ink),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AuthColors.amberTint,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AuthColors.amber.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  w.levelLabel.replaceAll('{n}', '${level.levelNumber}'),
                                  style: AppText.semiBold(
                                    fontSize: 10,
                                    color: AuthColors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          if (p.nextLevel != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${p.currentXp} XP',
                                  style: AppText.semiBold(
                                    fontSize: 11,
                                    color: AuthColors.ink,
                                  ),
                                ),
                                Text(
                                  '${p.xpToNextLevel} XP',
                                  style: AppText.regular(
                                    fontSize: 10,
                                    color: AuthColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: p.progressInLevel.clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: AuthColors.amberTint,
                                valueColor: const AlwaysStoppedAnimation(
                                  AuthColors.amber,
                                ),
                              ),
                            ),
                          ] else
                            Text(
                              w.levelMaxReached,
                              style: AppText.semiBold(
                                fontSize: 11,
                                color: AuthColors.emerald,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (hasBonuses) ...[
                      const SizedBox(width: 10),
                      // ── Expand arrow ──────────────────────────────────────
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AuthColors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Expanded bonus list ──────────────────────────────────────
              if (hasBonuses)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  child: _expanded
                      ? _buildExpandedContent(level.bonuses, isRu)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(List bonuses, bool isRu) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 0.5, color: AuthColors.borderSoft),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: bonuses.map<Widget>((b) {
              final bool isToken = b.bonusType == 'daily_tokens';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToken ? AuthColors.amberTint : AuthColors.emeraldTint,
                      ),
                      alignment: Alignment.center,
                      child: Text(b.icon, style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isRu ? b.labelRu : b.labelTk,
                        style: AppText.regular(fontSize: 13, color: AuthColors.inkMuted),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 78,
      decoration: BoxDecoration(
        color: AuthColors.borderSoft,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  void _showLevelUpDialog(bool isRu) {
    final provider = context.read<LevelProvider>();
    final pending = provider.pendingLevelUp;
    if (pending == null || !mounted) return;

    final matches = provider.allLevels
        .where((l) => l.levelNumber == pending.levelAfter)
        .toList();
    final levelData = matches.isNotEmpty ? matches.first : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _LevelUpDialog(
        levelNumber: pending.levelAfter,
        levelTitle: levelData?.title(isRu) ?? 'Уровень ${pending.levelAfter}',
        levelIcon: levelData?.icon ?? '🏆',
        xpEarned: pending.xpAmount,
        bonuses: levelData?.bonuses ?? [],
        dailyBonus: levelData?.dailyTokens ?? 0.0,
        onDismiss: () {
          provider.dismissLevelUp(pending.id);
          _dialogShown = false;
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Level Up Dialog
// ═════════════════════════════════════════════════════════════════════════════

class _LevelUpDialog extends StatefulWidget {
  final int levelNumber;
  final String levelTitle;
  final String levelIcon;
  final int xpEarned;
  final List bonuses;
  final double dailyBonus;
  final VoidCallback onDismiss;

  const _LevelUpDialog({
    required this.levelNumber,
    required this.levelTitle,
    required this.levelIcon,
    required this.xpEarned,
    required this.bonuses,
    required this.dailyBonus,
    required this.onDismiss,
  });

  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _confettiCtrl;
  late Animation<double> _scaleAnim;
  final List<_Particle> _particles = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 50; i++) {
      _particles.add(_Particle(_rng));
    }
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();
    _confettiCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final w = lang.words;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _confettiCtrl,
          builder: (_, _) => CustomPaint(
            painter: _ConfettiPainter(_particles, _confettiCtrl.value),
            size: MediaQuery.of(context).size,
          ),
        ),
        Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AuthColors.amber.withValues(alpha: 0.22),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    w.levelNewLevel,
                    style: AppText.bold(fontSize: 11, color: AuthColors.amber)
                        .copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.levelIcon} ${widget.levelTitle}',
                    style: AppText.serif(fontSize: 22, color: AuthColors.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // XP badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AuthColors.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      w.levelXpEarned.replaceAll('{n}', '${widget.xpEarned}'),
                      style: AppText.semiBold(fontSize: 13, color: AuthColors.ink),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Daily bonus highlight
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AuthColors.amberTint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AuthColors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded, color: AuthColors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          w.levelNowDaily.replaceAll('{n}', '${widget.dailyBonus}'),
                          style: AppText.bold(fontSize: 14, color: AuthColors.ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    w.levelTokensAuto,
                    style: AppText.regular(fontSize: 11, color: AuthColors.inkSoft),
                  ),

                  // Bonuses
                  if (widget.bonuses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(height: 0.5, color: AuthColors.borderSoft),
                    const SizedBox(height: 8),
                    Text(
                      w.levelNewBonuses,
                      style: AppText.regular(fontSize: 12, color: AuthColors.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    ...widget.bonuses.take(3).map(
                      (b) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(b.icon, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              b.labelRu,
                              style: AppText.semiBold(
                                fontSize: 13,
                                color: AuthColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AuthColors.ink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: widget.onDismiss,
                        child: Text(
                          w.great,
                          style: AppText.bold(fontSize: 15, color: Colors.white)
                              .copyWith(letterSpacing: 1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Level Details Sheet
// ═════════════════════════════════════════════════════════════════════════════

class _LevelDetailsSheet extends StatelessWidget {
  final LevelProvider provider;
  final AppLocalizations w;
  final bool isRu;

  const _LevelDetailsSheet({
    required this.provider,
    required this.w,
    required this.isRu,
  });

  @override
  Widget build(BuildContext context) {
    final current = provider.currentLevel;
    if (current == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: AuthColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AuthColors.amberTint,
                        border: Border.all(
                          color: AuthColors.amber.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${current.levelNumber}',
                        style: AppText.semiBold(fontSize: 22, color: AuthColors.amber),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.title(isRu),
                            style: AppText.serif(fontSize: 18, color: AuthColors.ink),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            w.levelLabel.replaceAll('{n}', '${current.levelNumber}'),
                            style: AppText.medium(
                              fontSize: 12,
                              color: AuthColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${provider.currentXp}',
                          style: AppText.bold(fontSize: 20, color: AuthColors.ink),
                        ),
                        Text(
                          'XP',
                          style: AppText.regular(fontSize: 11, color: AuthColors.inkSoft),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Progress
              if (provider.nextLevel != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            w.levelToNextShort,
                            style: AppText.regular(
                              fontSize: 12,
                              color: AuthColors.inkMuted,
                            ),
                          ),
                          Text(
                            '${provider.xpToNextLevel} XP',
                            style: AppText.semiBold(
                              fontSize: 12,
                              color: AuthColors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: provider.progressInLevel,
                          minHeight: 8,
                          backgroundColor: AuthColors.amberTint,
                          valueColor: const AlwaysStoppedAnimation(AuthColors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Level table
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AuthColors.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AuthColors.border),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: AuthColors.amber, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              w.levelBonusHeader,
                              style: AppText.bold(fontSize: 10, color: AuthColors.inkSoft)
                                  .copyWith(letterSpacing: 0.8),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 0.5, color: AuthColors.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Text(
                          w.levelTokensAuto,
                          style: AppText.medium(fontSize: 13, color: AuthColors.ink),
                        ),
                      ),
                      Container(height: 0.5, color: AuthColors.border),
                      ...List.generate(provider.allLevels.length, (i) {
                        final l = provider.allLevels[i];
                        final bonus = l.dailyTokens;
                        final isCurrent = l.id == current.id;
                        final isUnlocked = provider.currentXp >= l.xpRequired;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (i > 0) Container(height: 0.5, color: AuthColors.borderSoft),
                            Container(
                              color: isCurrent ? AuthColors.amberTint : Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isUnlocked
                                          ? Icons.check_circle_rounded
                                          : Icons.lock_outline_rounded,
                                      size: 14,
                                      color: isUnlocked
                                          ? AuthColors.emerald
                                          : AuthColors.inkSoft,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            w.levelRow
                                                .replaceAll('{n}', '${l.levelNumber}')
                                                .replaceAll('{title}', l.title(isRu)),
                                            style: isCurrent
                                                ? AppText.semiBold(
                                                    fontSize: 13,
                                                    color: AuthColors.amber,
                                                  )
                                                : AppText.regular(
                                                    fontSize: 13,
                                                    color: isUnlocked
                                                        ? AuthColors.ink
                                                        : AuthColors.inkSoft,
                                                  ),
                                          ),
                                          Text(
                                            w.levelFromXp.replaceAll('{n}', '${l.xpRequired}'),
                                            style: AppText.regular(
                                              fontSize: 10,
                                              color: AuthColors.inkSoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? AuthColors.amber.withValues(alpha: 0.12)
                                            : isUnlocked
                                            ? AuthColors.emeraldTint
                                            : AuthColors.borderSoft,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        w.levelPerDay.replaceAll('{n}', '$bonus'),
                                        style: AppText.semiBold(
                                          fontSize: 12,
                                          color: isCurrent
                                              ? AuthColors.amber
                                              : isUnlocked
                                              ? AuthColors.emerald
                                              : AuthColors.inkSoft,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Confetti particles
// ═════════════════════════════════════════════════════════════════════════════

class _Particle {
  final double x, speedY, speedX, size, rotation;
  final Color color;

  _Particle(Random rng)
    : x = rng.nextDouble(),
      speedY = 0.3 + rng.nextDouble() * 0.7,
      speedX = (rng.nextDouble() - 0.5) * 0.25,
      size = 5 + rng.nextDouble() * 7,
      rotation = rng.nextDouble() * pi * 2,
      color = [
        AuthColors.amber,
        AuthColors.emerald,
        const Color(0xFFD32F1E),
        const Color(0xFF3498DB),
        const Color(0xFF9B59B6),
        const Color(0xFFE67E22),
      ][rng.nextInt(6)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - progress * 0.8).clamp(0, 1));
      final x = (p.x + p.speedX * progress) * size.width;
      final y = -50 + p.speedY * progress * (size.height + 100);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * pi * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
