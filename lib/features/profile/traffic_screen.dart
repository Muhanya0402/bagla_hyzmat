import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/traffic_tracker.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// «Анализ трафика» — сколько интернета съело приложение.
///
/// Считается обмен с сервером через наш сетевой клиент. Показ уже
/// загруженных фотографий и живое подключение для обновлений сюда не входят,
/// об этом прямо написано внизу экрана: лучше неполная правда, чем красивая
/// цифра, которой нельзя верить.
class TrafficScreen extends StatefulWidget {
  const TrafficScreen({super.key});

  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  final _tracker = TrafficTracker();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _tracker.revision.addListener(_onChanged);
  }

  @override
  void dispose() {
    _tracker.revision.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _tracker.load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirmReset(AppLocalizations words) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          words.trafficResetTitle,
          style: AppText.serif(fontSize: 17, color: c.ink),
        ),
        content: Text(
          words.trafficResetBody,
          style: AppText.regular(fontSize: 13.5, color: c.inkMuted)
              .copyWith(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              words.trafficResetCancel,
              style: AppText.medium(fontSize: 14, color: c.inkMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              words.trafficResetConfirm,
              style: AppText.semiBold(fontSize: 14, color: c.errorMuted),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _tracker.reset();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final isRu = lang.isRu;
    final s = _tracker.stats;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child:
                Icon(Icons.arrow_back_ios_new_rounded, color: c.ink, size: 16),
          ),
        ),
        title: Text(
          words.trafficTitle,
          style: AppText.serif(fontSize: 20, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: c.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Две главные цифры ───────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _BigStat(
                        label: words.trafficToday,
                        value: formatBytes(s.today, isRu: isRu),
                        icon: Icons.today_outlined,
                        accent: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BigStat(
                        label: words.trafficTotal,
                        value: formatBytes(s.total, isRu: isRu),
                        icon: Icons.data_usage_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Строки помельче ─────────────────────────────────────
                _Card(
                  child: Column(
                    children: [
                      _Row(
                        label: words.trafficAveragePerDay,
                        value: formatBytes(s.averagePerActiveDay, isRu: isRu),
                      ),
                      _Sep(),
                      _Row(
                        label: words.trafficForecast,
                        value: formatBytes(s.monthlyForecast, isRu: isRu),
                        hint: words.trafficForecastHint,
                      ),
                      _Sep(),
                      _Row(
                        label: words.trafficSent,
                        value: formatBytes(s.totalSent, isRu: isRu),
                      ),
                      _Sep(),
                      _Row(
                        label: words.trafficReceived,
                        value: formatBytes(s.totalReceived, isRu: isRu),
                      ),
                      _Sep(),
                      _Row(
                        label: words.trafficRequests,
                        value: '${s.requests}',
                      ),
                      if (s.since != null) ...[
                        _Sep(),
                        _Row(
                          label: words.trafficSince,
                          value: _formatDate(s.since!, isRu),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ── График по дням ──────────────────────────────────────
                _SectionTitle(words.trafficByDays),
                _Card(child: _DaysChart(stats: s, isRu: isRu)),
                const SizedBox(height: 10),

                // ── На что ушло ─────────────────────────────────────────
                if (s.byCategory.isNotEmpty) ...[
                  _SectionTitle(words.trafficByCategory),
                  _Card(child: _CategoryBars(stats: s, isRu: isRu, words: words)),
                  const SizedBox(height: 10),
                ],

                // ── Самые тяжёлые запросы ───────────────────────────────
                if (s.byOperation.isNotEmpty) ...[
                  _SectionTitle(words.trafficHeaviest),
                  _Card(child: _TopOperations(stats: s, isRu: isRu)),
                  const SizedBox(height: 10),
                ],

                // ── Что не учтено ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 15, color: c.inkSoft),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          words.trafficDisclaimer,
                          style:
                              AppText.regular(fontSize: 12, color: c.inkMuted)
                                  .copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Сброс ───────────────────────────────────────────────
                GestureDetector(
                  onTap: () => _confirmReset(words),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      words.trafficReset,
                      style:
                          AppText.medium(fontSize: 14, color: c.errorMuted),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDate(DateTime t, bool isRu) {
    const ru = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    const tk = [
      'ýan', 'few', 'mart', 'apr', 'maý', 'iýun',
      'iýul', 'awg', 'sen', 'okt', 'noý', 'dek'
    ];
    final m = (isRu ? ru : tk)[t.month - 1];
    return '${t.day} $m ${t.year}';
  }
}

// ─── Крупная плитка ───────────────────────────────────────────────────────────

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool accent;

  const _BigStat({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: accent ? c.emeraldTint : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ? c.border : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.inkSoft),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppText.semiBold(fontSize: 22, color: c.ink)
                .copyWith(letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.regular(fontSize: 12, color: c.inkMuted)),
        ],
      ),
    );
  }
}

// ─── График по дням ───────────────────────────────────────────────────────────

class _DaysChart extends StatelessWidget {
  final TrafficStats stats;
  final bool isRu;
  const _DaysChart({required this.stats, required this.isRu});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final data = stats.lastDays(14);
    final maxV = data.fold<int>(0, (a, e) => e.value > a ? e.value : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 92,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((e) {
              // Столбик всегда видно хотя бы ниткой — иначе пустой день
              // неотличим от отсутствующего.
              final h = maxV == 0 ? 2.0 : (e.value / maxV) * 86 + 2;
              final isToday = e.key.day == DateTime.now().day &&
                  e.key.month == DateTime.now().month;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: h,
                        decoration: BoxDecoration(
                          color: isToday ? c.ink : c.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${data.first.key.day}.${data.first.key.month}',
              style: AppText.regular(fontSize: 10.5, color: c.inkSoft),
            ),
            Text(
              formatBytes(maxV, isRu: isRu),
              style: AppText.regular(fontSize: 10.5, color: c.inkSoft),
            ),
            Text(
              '${data.last.key.day}.${data.last.key.month}',
              style: AppText.regular(fontSize: 10.5, color: c.ink),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Разбивка по разделам ─────────────────────────────────────────────────────

class _CategoryBars extends StatelessWidget {
  final TrafficStats stats;
  final bool isRu;
  final AppLocalizations words;
  const _CategoryBars({
    required this.stats,
    required this.isRu,
    required this.words,
  });

  String _label(String key) {
    switch (key) {
      case 'orders':
        return words.trafficCatOrders;
      case 'photos':
        return words.trafficCatPhotos;
      case 'notifications':
        return words.trafficCatNotifications;
      case 'profile':
        return words.trafficCatProfile;
      case 'auth':
        return words.trafficCatAuth;
      default:
        return words.trafficCatOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final entries = stats.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxV = entries.isEmpty ? 0 : entries.first.value;

    return Column(
      children: entries.map((e) {
        final share = maxV == 0 ? 0.0 : e.value / maxV;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_label(e.key),
                      style: AppText.regular(fontSize: 13, color: c.ink)),
                  Text(
                    formatBytes(e.value, isRu: isRu),
                    style: AppText.medium(fontSize: 12.5, color: c.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 6,
                  backgroundColor: c.borderSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(c.ink),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Самые тяжёлые запросы ────────────────────────────────────────────────────

class _TopOperations extends StatelessWidget {
  final TrafficStats stats;
  final bool isRu;
  const _TopOperations({required this.stats, required this.isRu});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final entries = stats.byOperation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();

    return Column(
      children: [
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) const _Sep(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    top[i].key,
                    style: AppText.regular(fontSize: 12.5, color: c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatBytes(top[i].value, isRu: isRu),
                  style: AppText.medium(fontSize: 12.5, color: c.ink),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Мелочи оформления ────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text,
        style: AppText.semiBold(fontSize: 13, color: c.inkMuted),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  const _Row({required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppText.regular(fontSize: 13.5, color: c.ink)),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: AppText.regular(fontSize: 11, color: c.inkSoft)
                        .copyWith(height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: AppText.semiBold(fontSize: 13.5, color: c.ink)),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.5, color: AppColors.of(context).borderSoft);
  }
}
