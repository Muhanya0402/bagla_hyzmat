import 'dart:math';
import 'package:bagla/features/levels/level_definition.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/level_provider.dart';
import '../../providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════
//  Карточка уровня для экрана профиля
//  Использование: LevelCardWidget() — просто добавь в профиль
// ═══════════════════════════════════════════════════════════════════

class LevelCardWidget extends StatefulWidget {
  const LevelCardWidget({super.key});

  @override
  State<LevelCardWidget> createState() => _LevelCardWidgetState();
}

class _LevelCardWidgetState extends State<LevelCardWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final auth = context.read<AuthProvider>();
    if (auth.userId.isNotEmpty) {
      context.read<LevelProvider>().loadForUser(auth.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LevelProvider>(
      builder: (context, provider, _) {
        // Показать level up анимацию если есть pending
        if (provider.pendingLevelUp != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showLevelUpDialog(context, provider);
          });
        }

        if (provider.isLoading) {
          return _buildSkeleton();
        }

        if (provider.currentLevel == null) {
          return const SizedBox.shrink();
        }

        return _buildCard(context, provider);
      },
    );
  }

  Widget _buildCard(BuildContext context, LevelProvider provider) {
    final level = provider.currentLevel!;
    final nextLevel = provider.nextLevel;
    final color = _hexColor(level.colorHex);
    final isRu = true; // замени на langProvider.isRu

    return GestureDetector(
      onTap: () => _showLevelDetailsSheet(context, provider, isRu),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Верхняя строка: иконка + уровень + XP
              Row(
                children: [
                  Text(level.icon, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Уровень ${level.levelNumber}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          level.title(isRu),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // XP badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${provider.currentXp} XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Прогресс-бар
              if (nextLevel != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'До уровня ${nextLevel.levelNumber} ${nextLevel.icon}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${provider.xpToNextLevel} XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _AnimatedProgressBar(
                  progress: provider.progressInLevel,
                  color: Colors.white,
                ),
              ] else ...[
                const Text(
                  '🏆 Максимальный уровень!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // Подсказка тапнуть
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    'Подробнее',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Colors.white60,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  // ─── Level Up Dialog (анимация) ───────────────────────────────────────────

  void _showLevelUpDialog(BuildContext context, LevelProvider provider) {
    final pending = provider.pendingLevelUp!;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _LevelUpDialog(
        levelAfterNumber: pending.levelAfter,
        xpEarned: pending.xpAmount,
        allLevels: provider.allLevels,
        onDismiss: () {
          provider.dismissLevelUp(pending.id);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ─── Level Details Bottom Sheet ───────────────────────────────────────────

  void _showLevelDetailsSheet(
    BuildContext context,
    LevelProvider provider,
    bool isRu,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LevelDetailsSheet(provider: provider, isRu: isRu),
    );
  }

  Color _hexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
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
  final Color color;

  const _AnimatedProgressBar({required this.progress, required this.color});

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedProgressBar old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Level Up Dialog — анимация конфетти + новый уровень
// ═══════════════════════════════════════════════════════════════════

class _LevelUpDialog extends StatefulWidget {
  final int levelAfterNumber;
  final int xpEarned;
  final List<LevelDefinition> allLevels;
  final VoidCallback onDismiss;

  const _LevelUpDialog({
    required this.levelAfterNumber,
    required this.xpEarned,
    required this.allLevels,
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
  late Animation<double> _fadeAnim;

  final List<_ConfettiParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    // Генерируем частицы конфетти
    for (int i = 0; i < 40; i++) {
      _particles.add(_ConfettiParticle(rng: _rng));
    }

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeIn);

    _scaleCtrl.forward();
    _confettiCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  LevelDefinition? get _newLevel {
    try {
      return widget.allLevels.firstWhere(
        (l) => l.levelNumber == widget.levelAfterNumber,
      );
    } catch (_) {
      return null;
    }
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF27AE60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = _newLevel;
    final color = level != null
        ? _hexColor(level.colorHex)
        : const Color(0xFF27AE60);

    return Stack(
      children: [
        // Конфетти
        AnimatedBuilder(
          animation: _confettiCtrl,
          builder: (_, __) => CustomPaint(
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _confettiCtrl.value,
            ),
            size: MediaQuery.of(context).size,
          ),
        ),

        // Диалог
        Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Иконка уровня
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          level?.icon ?? '🏆',
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'НОВЫЙ УРОВЕНЬ!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B3A6B),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      level?.titleRu ?? 'Уровень ${widget.levelAfterNumber}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // XP earned badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
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

                    if (level != null && level.bonuses.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Новые бонусы разблокированы',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...level.bonuses
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
                          backgroundColor: color,
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
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Конфетти
// ═══════════════════════════════════════════════════════════════════

class _ConfettiParticle {
  final double x;
  final double speedY;
  final double speedX;
  final Color color;
  final double size;
  final double rotation;

  _ConfettiParticle({required Random rng})
    : x = rng.nextDouble(),
      speedY = 0.3 + rng.nextDouble() * 0.7,
      speedX = (rng.nextDouble() - 0.5) * 0.3,
      size = 6 + rng.nextDouble() * 8,
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
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withOpacity(1 - progress * 0.8);
      final x = (p.x + p.speedX * progress) * size.width;
      final y = -50 + p.speedY * progress * (size.height + 100);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * pi * 2);
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
  final bool isRu;

  const _LevelDetailsSheet({required this.provider, required this.isRu});

  Color _hexColor(String hex) {
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
    final color = _hexColor(current.colorHex);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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

          // Заголовок
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
                      current.title(isRu),
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
                        fontSize: 20,
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

          const SizedBox(height: 16),

          // Прогресс-бар в шите
          if (provider.nextLevel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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

          const SizedBox(height: 20),

          // Бонусы текущего уровня
          if (current.bonuses.isNotEmpty) ...[
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
            const SizedBox(height: 12),
            ...current.bonuses.map(
              (b) => ListTile(
                leading: Text(b.icon, style: const TextStyle(fontSize: 24)),
                title: Text(
                  b.label(isRu),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B3A6B),
                  ),
                ),
                dense: true,
              ),
            ),
          ],

          // Все уровни
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: provider.allLevels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final l = provider.allLevels[i];
                final lColor = _hexColor(l.colorHex);
                final isCurrentLevel = l.id == current.id;
                final isUnlocked = provider.currentXp >= l.xpRequired;

                return Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? lColor.withOpacity(0.15)
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
