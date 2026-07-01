import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/point_icon.dart';
import 'package:bagla/core/widgets/shimmer.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/profile/transactions/transaction_service.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// История транзакций курьера: пополнения (сумма+жетоны), списания за заказы,
/// кэшбек и ежедневные бонусы — единым списком, новые сверху.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _service = TransactionService();
  List<TransactionEntry> _items = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = false);
    try {
      final userId = context.read<AuthProvider>().userId;
      final items = await _service.fetchHistory(userId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
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
            child: Icon(Icons.arrow_back_ios_new_rounded, color: c.ink, size: 16),
          ),
        ),
        title: Text(
          words.txHistoryTitle,
          style: AppText.serif(fontSize: 20, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: c.border),
        ),
      ),
      body: RefreshIndicator(
        color: c.ink,
        backgroundColor: c.surface,
        onRefresh: _load,
        child: _buildBody(c, words),
      ),
    );
  }

  Widget _buildBody(AppColors c, AppLocalizations words) {
    if (_loading) return const ShimmerListSkeleton(itemHeight: 72);
    if (_error) {
      return _centered(
        c,
        icon: Icons.wifi_off_rounded,
        iconColor: c.errorMuted,
        iconBg: c.errorTint,
        title: words.txHistoryError,
        subtitle: words.txHistoryPullRefresh,
      );
    }
    if (_items.isEmpty) {
      return _centered(
        c,
        icon: Icons.receipt_long_outlined,
        iconColor: c.inkSoft,
        iconBg: c.borderSoft,
        title: words.txHistoryEmpty,
        subtitle: words.txHistoryEmptyDesc,
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TxTile(entry: _items[i], words: words),
    );
  }

  Widget _centered(
    AppColors c, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 110),
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: iconColor),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(title, style: AppText.semiBold(fontSize: 15, color: c.ink)),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppText.regular(fontSize: 13, color: c.inkSoft)
                .copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _TxTile extends StatelessWidget {
  final TransactionEntry entry;
  final AppLocalizations words;
  const _TxTile({required this.entry, required this.words});

  ({IconData icon, String title}) _meta() {
    switch (entry.kind) {
      case TxKind.topUp:
        return (icon: Icons.account_balance_wallet_outlined, title: words.txTopUp);
      case TxKind.orderDebit:
        final id = entry.orderShortId;
        return (
          icon: Icons.shopping_bag_outlined,
          title: id != null && id.isNotEmpty
              ? '${words.txOrderDebit} #$id'
              : words.txOrderDebit,
        );
      case TxKind.cashback:
        return (icon: Icons.savings_outlined, title: words.txCashback);
      case TxKind.dailyBonus:
        return (icon: Icons.card_giftcard_outlined, title: words.txDailyBonus);
      case TxKind.other:
        return (icon: Icons.swap_vert_rounded, title: words.txOther);
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final m = _meta();
    final isCredit = entry.tokens >= 0;
    final tokenColor = entry.tokens > 0
        ? c.ink
        : entry.tokens < 0
            ? c.errorMuted
            : c.inkSoft;
    final sign = entry.tokens > 0 ? '+' : '';
    final tokenStr = '$sign${_trim(entry.tokens)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit ? c.emeraldTint : c.errorTint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(m.icon, size: 19, color: isCredit ? c.ink : c.errorMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.title,
                  style: AppText.semiBold(fontSize: 14, color: c.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _fmtDate(entry.date),
                  style: AppText.regular(fontSize: 11.5, color: c.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Деньги — только для пополнения.
              if (entry.kind == TxKind.topUp && entry.money != null)
                Text(
                  '+${_trim(entry.money!)} TMT',
                  style: AppText.bold(fontSize: 14, color: c.ink),
                ),
              if (entry.tokens != 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tokenStr,
                      style: AppText.semiBold(fontSize: 13.5, color: tokenColor),
                    ),
                    const SizedBox(width: 3),
                    const PointIcon(size: 14),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// «10.0» → «10», «10.5» → «10.5».
  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
