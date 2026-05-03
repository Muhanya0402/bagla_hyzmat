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

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _gradient = LinearGradient(
    colors: [_green, _red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

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
        if (mounted) _showLevelUpDialog();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LevelProvider>(
      builder: (_, provider, __) {
        if (provider.pendingLevelUp != null && !_dialogShown) {
          _dialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLevelUpDialog();
          });
        }

        if (provider.isLoading) return _buildSkeleton();
        if (provider.currentLevel == null) return _buildDebugEmpty(provider);
        return _buildCard(provider);
      },
    );
  }

  // ── Debug empty ────────────────────────────────────────────────────────────
  Widget _buildDebugEmpty(LevelProvider provider) {
    final reason = provider.allLevels.isEmpty
        ? '⚠️ level_definitions пустой или нет прав доступа'
        : '⚠️ current_level_id не заполнен у курьера в Directus';
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
          const Text('⚠️', style: TextStyle(fontSize: 22)),
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

  // ── Main card ──────────────────────────────────────────────────────────────
  Widget _buildCard(LevelProvider p) {
    final level = p.currentLevel!;
    final int levelNum = level.levelNumber;
    // +0.5 жетонов в день за каждый уровень
    final double dailyBonus = levelNum * 0.5;

    return GestureDetector(
      onTap: () => _showDetailsSheet(p),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          gradient: _gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top: level info + XP ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Уровень $levelNum',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                  // XP badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
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
            ),

            const SizedBox(height: 16),

            // ── Daily bonus info row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ежедневный бонус: +$dailyBonus жетонов/день',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '(+0.5 за уровень)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Progress to next level ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: p.nextLevel != null
                  ? Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'До уровня ${p.nextLevel!.levelNumber}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
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
                      ],
                    )
                  : const Text(
                      '🏆 Максимальный уровень достигнут!',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
            ),

            // ── Tap hint ────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_green.withOpacity(0.15), _red.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  // ── Level up dialog ────────────────────────────────────────────────────────
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
        levelColor: levelData != null ? _parseHex(levelData.colorHex) : _green,
        xpEarned: pending.xpAmount,
        bonuses: levelData?.bonuses ?? [],
        dailyBonus: pending.levelAfter * 0.5,
        onDismiss: () {
          provider.dismissLevelUp(pending.id);
          _dialogShown = false;
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── Details sheet ──────────────────────────────────────────────────────────
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
      return _green;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Animated progress bar
// ═════════════════════════════════════════════════════════════════════════════

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
                BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Level Up Dialog — with +0.5/level description
// ═════════════════════════════════════════════════════════════════════════════

class _LevelUpDialog extends StatefulWidget {
  final int levelNumber;
  final String levelTitle;
  final String levelIcon;
  final Color levelColor;
  final int xpEarned;
  final List bonuses;
  final double dailyBonus;
  final VoidCallback onDismiss;

  const _LevelUpDialog({
    required this.levelNumber,
    required this.levelTitle,
    required this.levelIcon,
    required this.levelColor,
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
                  // Title
                  const Text(
                    'НОВЫЙ УРОВЕНЬ!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A7A3C),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.levelIcon} ${widget.levelTitle}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: widget.levelColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // XP badge
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F1117),
                      ),
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
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1A7A3C).withOpacity(0.08),
                          const Color(0xFFD32F1E).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF1A7A3C).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFFE67E22),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Теперь +${widget.dailyBonus} жетонов/день',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A7A3C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Каждый уровень даёт +0.5 жетонов в день',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9AA3AF),
                    ),
                  ),

                  // Bonuses
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
                                    color: Color(0xFF0F1117),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A7A3C), Color(0xFFD32F1E)],
                        ),
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
// Level Details Sheet — with +0.5/level table
// ═════════════════════════════════════════════════════════════════════════════

class _LevelDetailsSheet extends StatelessWidget {
  final LevelProvider provider;
  const _LevelDetailsSheet({required this.provider});

  Color _parseHex(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF1A7A3C);
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    current.titleRu,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
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
                          color: Color(0xFF0F1117),
                        ),
                      ),
                      const Text(
                        'XP',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'До следующего уровня',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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

            const SizedBox(height: 20),

            // ── Daily bonus per level table ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEF0F3)),
                ),
                child: Column(
                  children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFE67E22),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'БОНУС ЗА УРОВЕНЬ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF9AA3AF),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEF0F3)),

                    // Description row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Каждый уровень даёт +0.5 жетонов в день',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F1117),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Жетоны начисляются автоматически каждые 24 часа',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF9AA3AF),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEF0F3)),

                    // Level rows
                    ...List.generate(provider.allLevels.length, (i) {
                      final l = provider.allLevels[i];
                      final bonus = l.levelNumber * 0.5;
                      final isCurrent = l.id == current.id;
                      final isUnlocked = provider.currentXp >= l.xpRequired;
                      return Container(
                        color: isCurrent ? color.withOpacity(0.05) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // Level emoji
                              Text(
                                isUnlocked ? '' : '🔒',
                                style: TextStyle(
                                  fontSize: isUnlocked ? 18 : 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Level name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ур. ${l.levelNumber} — ${l.titleRu}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isCurrent
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isCurrent
                                            ? color
                                            : isUnlocked
                                            ? const Color(0xFF0F1117)
                                            : const Color(0xFF9AA3AF),
                                      ),
                                    ),
                                    Text(
                                      'от ${l.xpRequired} XP',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF9AA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Bonus badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? color.withOpacity(0.12)
                                      : isUnlocked
                                      ? const Color(0xFFE8F5EE)
                                      : const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '+$bonus/день',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrent
                                        ? color
                                        : isUnlocked
                                        ? const Color(0xFF1A7A3C)
                                        : const Color(0xFF9AA3AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bonuses of current level
            if (current.bonuses.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'БОНУСЫ ТЕКУЩЕГО УРОВНЯ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9AA3AF),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...current.bonuses.map(
                (b) => ListTile(
                  dense: true,
                  leading: Text(b.icon, style: const TextStyle(fontSize: 20)),
                  title: Text(
                    b.labelRu,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F1117),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Confetti particles (unchanged)
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
        const Color(0xFF1A7A3C),
        const Color(0xFFD32F1E),
        const Color(0xFFF1C40F),
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
