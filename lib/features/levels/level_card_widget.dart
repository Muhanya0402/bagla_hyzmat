import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/level_provider.dart';
import '../../providers/auth_provider.dart';
import 'dart:math';

class LevelCardWidget extends StatefulWidget {
  const LevelCardWidget({super.key});

  @override
  State<LevelCardWidget> createState() => _LevelCardWidgetState();
}

class _LevelCardWidgetState extends State<LevelCardWidget> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    debugPrint('🔵 LevelCard init: userId=${auth.userId}, role=${auth.role}');

    if (auth.userId.isEmpty) {
      debugPrint('🔴 LevelCard: userId пустой — загрузка невозможна');
      return;
    }

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
        if (mounted) _showLevelUpDialog();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LevelProvider>(
      builder: (_, provider, __) {
        // ── DEBUG: всегда показываем состояние ───────────────────────────────
        debugPrint(
          '🟡 LevelCard build: '
          'isLoading=${provider.isLoading}, '
          'levels=${provider.allLevels.length}, '
          'currentLevel=${provider.currentLevel?.titleRu}, '
          'xp=${provider.currentXp}',
        );

        // Pending level up
        if (provider.pendingLevelUp != null && !_dialogShown) {
          _dialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLevelUpDialog();
          });
        }

        // Загружается
        if (provider.isLoading) {
          return _buildSkeleton();
        }

        // Нет данных — показываем заглушку с текстом для диагностики
        // TODO: убери _buildDebugEmpty и замени на SizedBox.shrink()
        // когда всё заработает
        if (provider.currentLevel == null) {
          return _buildDebugEmpty(provider);
        }

        return _buildCard(provider);
      },
    );
  }

  // ─── Временная заглушка для диагностики ───────────────────────────────────
  // Показывает причину почему карточка пустая
  // УДАЛИ после того как всё заработает
  Widget _buildDebugEmpty(LevelProvider provider) {
    String reason;
    if (provider.allLevels.isEmpty) {
      reason = '⚠️ level_definitions пустой\nили нет прав доступа';
    } else {
      reason = '⚠️ current_level_id не заполнен\nу курьера в Directus';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF856404),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Карточка ──────────────────────────────────────────────────────────────

  Widget _buildCard(LevelProvider p) {
    final level = p.currentLevel!;

    return GestureDetector(
      onTap: () => _showDetailsSheet(p),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B3A6B), Color(0xFF274B8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B3A6B).withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(level.icon, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Уровень ${level.levelNumber}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        level.titleRu,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${p.currentXp} XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (p.nextLevel != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'До уровня ${p.nextLevel!.levelNumber} ${p.nextLevel!.icon}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  Text(
                    '${p.xpToNextLevel} XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AnimatedProgressBar(progress: p.progressInLevel),
            ] else ...[
              const Text(
                '🏆 Максимальный уровень достигнут!',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],

            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Подробнее',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Colors.white38,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 130,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  void _showLevelUpDialog() {
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
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => _LevelUpDialog(
        levelNumber: pending.levelAfter,
        levelTitle: levelData?.titleRu ?? 'Уровень ${pending.levelAfter}',
        levelIcon: levelData?.icon ?? '🏆',
        levelColor: levelData != null
            ? _parseHex(levelData.colorHex)
            : const Color(0xFF27AE60),
        xpEarned: pending.xpAmount,
        bonuses: levelData?.bonuses ?? [],
        onDismiss: () {
          provider.dismissLevelUp(pending.id);
          _dialogShown = false;
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showDetailsSheet(LevelProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LevelDetailsSheet(provider: provider),
    );
  }

  Color _parseHex(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF1B3A6B);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Анимированный прогресс-бар
// ═══════════════════════════════════════════════════════════════════

class _AnimatedProgressBar extends StatefulWidget {
  final double progress;
  const _AnimatedProgressBar({required this.progress});

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedProgressBar old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(4),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _anim.value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Level Up Dialog
// ═══════════════════════════════════════════════════════════════════

class _LevelUpDialog extends StatefulWidget {
  final int levelNumber;
  final String levelTitle;
  final String levelIcon;
  final Color levelColor;
  final int xpEarned;
  final List bonuses;
  final VoidCallback onDismiss;

  const _LevelUpDialog({
    required this.levelNumber,
    required this.levelTitle,
    required this.levelIcon,
    required this.levelColor,
    required this.xpEarned,
    required this.bonuses,
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
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _confettiCtrl,
          builder: (_, __) => CustomPaint(
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: widget.levelColor.withOpacity(0.25),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: widget.levelColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.levelIcon,
                        style: const TextStyle(fontSize: 44),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'НОВЫЙ УРОВЕНЬ!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B3A6B),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.levelTitle,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: widget.levelColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+${widget.xpEarned} XP заработано',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B3A6B),
                      ),
                    ),
                  ),
                  if (widget.bonuses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 8),
                    const Text(
                      'Новые бонусы',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ...widget.bonuses
                        .take(3)
                        .map(
                          (b) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  b.icon,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  b.labelRu,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1B3A6B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.levelColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: widget.onDismiss,
                      child: const Text(
                        'ОТЛИЧНО!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 1,
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
        const Color(0xFF27AE60),
        const Color(0xFF1B3A6B),
        const Color(0xFFF1C40F),
        const Color(0xFFE74C3C),
        const Color(0xFF3498DB),
        const Color(0xFF9B59B6),
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
        ..color = p.color.withOpacity((1 - progress * 0.8).clamp(0, 1));
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

// ═══════════════════════════════════════════════════════════════════
//  Level Details Bottom Sheet
// ═══════════════════════════════════════════════════════════════════

class _LevelDetailsSheet extends StatelessWidget {
  final LevelProvider provider;
  const _LevelDetailsSheet({required this.provider});

  Color _parseHex(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF1B3A6B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = provider.currentLevel;
    if (current == null) return const SizedBox.shrink();
    final color = _parseHex(current.colorHex);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(current.icon, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Уровень ${current.levelNumber}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      current.titleRu,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${provider.currentXp}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B3A6B),
                      ),
                    ),
                    const Text(
                      'XP',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (provider.nextLevel != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'До следующего уровня',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        '${provider.xpToNextLevel} XP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
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
                      backgroundColor: const Color(0xFFF0F0F0),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (current.bonuses.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'БОНУСЫ УРОВНЯ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B3A6B),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...current.bonuses.map(
              (b) => ListTile(
                dense: true,
                leading: Text(b.icon, style: const TextStyle(fontSize: 22)),
                title: Text(
                  b.labelRu,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B3A6B),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ВСЕ УРОВНИ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B3A6B),
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: provider.allLevels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final l = provider.allLevels[i];
                final lColor = _parseHex(l.colorHex);
                final isCurrentLevel = l.id == current.id;
                final isUnlocked = provider.currentXp >= l.xpRequired;
                return Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? lColor.withOpacity(0.12)
                            : const Color(0xFFF0F0F0),
                        shape: BoxShape.circle,
                        border: isCurrentLevel
                            ? Border.all(color: lColor, width: 2.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          isUnlocked ? l.icon : '🔒',
                          style: TextStyle(fontSize: isUnlocked ? 22 : 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l.levelNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrentLevel
                            ? FontWeight.w800
                            : FontWeight.w400,
                        color: isCurrentLevel ? lColor : Colors.grey,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
