import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/profile/trusted_couriers_service.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Список надёжных курьеров магазина.
///
/// Дорогие заказы видят только те, кто здесь. Список наполняется из истории
/// своих заказов — постоянные пары «магазин — курьер» складываются сами, и
/// вспоминать имена не приходится.
class TrustedCouriersScreen extends StatefulWidget {
  const TrustedCouriersScreen({super.key});

  @override
  State<TrustedCouriersScreen> createState() => _TrustedCouriersScreenState();
}

class _TrustedCouriersScreenState extends State<TrustedCouriersScreen> {
  final _service = TrustedCouriersService();

  List<TrustedCourier> _list = [];
  bool _loading = true;
  String? _busyCourierId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _shopId => context.read<AuthProvider>().userId;

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.list(_shopId);
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  void _toast(String text, {bool bad = false}) {
    if (!mounted) return;
    final c = AppColors.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: AppText.regular(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: bad ? c.errorMuted : c.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  String _outcomeText(TrustedOutcome o, AppLocalizations words) {
    switch (o) {
      case TrustedOutcome.alreadyAdded:
        return words.trustedAlreadyAdded;
      case TrustedOutcome.notFound:
        return words.trustedNotFound;
      case TrustedOutcome.courierUnavailable:
        return words.trustedCourierUnavailable;
      case TrustedOutcome.notAShop:
      case TrustedOutcome.error:
      case TrustedOutcome.ok:
        return words.trustedGenericError;
    }
  }

  Future<void> _add(TrustedCourier c, AppLocalizations words) async {
    setState(() => _busyCourierId = c.courierId);
    final r = await _service.add(c.courierId);
    if (!mounted) return;
    setState(() => _busyCourierId = null);
    if (r == TrustedOutcome.ok) {
      await _load();
      _toast(words.trustedAdded.replaceAll('{name}', c.name));
    } else {
      _toast(_outcomeText(r, words), bad: true);
    }
  }

  Future<void> _remove(TrustedCourier c, AppLocalizations words) async {
    final ok = await _confirmRemove(c, words);
    if (ok != true) return;
    setState(() => _busyCourierId = c.courierId);
    final r = await _service.remove(c.courierId);
    if (!mounted) return;
    setState(() => _busyCourierId = null);
    if (r == TrustedOutcome.ok) {
      await _load();
      _toast(words.trustedRemoved.replaceAll('{name}', c.name));
    } else {
      _toast(_outcomeText(r, words), bad: true);
    }
  }

  Future<bool?> _confirmRemove(TrustedCourier c, AppLocalizations words) {
    final col = AppColors.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: col.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          words.trustedRemoveTitle,
          style: AppText.serif(fontSize: 18, letterSpacing: -0.3),
        ),
        content: Text(
          words.trustedRemoveBody.replaceAll('{name}', c.name),
          style: AppText.regular(fontSize: 14, color: col.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              words.regPickCancel,
              style: AppText.regular(fontSize: 14, color: col.inkMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              words.trustedRemoveConfirm,
              style: AppText.regular(fontSize: 14, color: col.errorMuted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCandidates(AppLocalizations words) async {
    final col = AppColors.of(context);
    final already = _list.map((e) => e.courierId).toSet();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: col.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _CandidatesSheet(
        load: () => _service.candidatesFromHistory(
          _shopId,
          exclude: already,
        ),
        onPick: (c) async {
          Navigator.pop(sheetCtx);
          await _add(c, words);
        },
      ),
    );
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
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: c.ink,
              size: 16,
            ),
          ),
        ),
        title: Text(
          words.trustedCouriersTitle,
          style: AppText.serif(fontSize: 20, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: c.border),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: c.ink, strokeWidth: 2),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: c.ink,
              child: _list.isEmpty
                  ? _buildEmpty(words, c)
                  : _buildList(words, c),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCandidates(words),
        backgroundColor: c.ink,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
        label: Text(
          words.trustedAddBtn,
          style: AppText.semiBold(fontSize: 14, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations words, AppColors c) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        Icon(Icons.verified_user_outlined, size: 48, color: c.inkSoft),
        const SizedBox(height: 16),
        Text(
          words.trustedEmptyTitle,
          textAlign: TextAlign.center,
          style: AppText.serif(fontSize: 18, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        Text(
          words.trustedEmptyBody,
          textAlign: TextAlign.center,
          style: AppText.regular(fontSize: 14, color: c.inkMuted).copyWith(height: 1.45),
        ),
      ],
    );
  }

  Widget _buildList(AppLocalizations words, AppColors c) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _list.length + 1,
      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 8),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(
              words.trustedHint,
              style: AppText.regular(fontSize: 13, color: c.inkMuted).copyWith(height: 1.45),
            ),
          );
        }
        final item = _list[i - 1];
        return _CourierTile(
          courier: item,
          busy: _busyCourierId == item.courierId,
          trailing: IconButton(
            onPressed: _busyCourierId != null
                ? null
                : () => _remove(item, words),
            icon: Icon(Icons.close_rounded, size: 18, color: c.inkMuted),
          ),
        );
      },
    );
  }
}

/// Лист кандидатов: курьеры, которые уже возили у этого магазина.
class _CandidatesSheet extends StatefulWidget {
  final Future<List<TrustedCourier>> Function() load;
  final Future<void> Function(TrustedCourier) onPick;

  const _CandidatesSheet({required this.load, required this.onPick});

  @override
  State<_CandidatesSheet> createState() => _CandidatesSheetState();
}

class _CandidatesSheetState extends State<_CandidatesSheet> {
  List<TrustedCourier>? _items;

  @override
  void initState() {
    super.initState();
    widget.load().then((v) {
      if (mounted) setState(() => _items = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
    final items = _items;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                words.trustedPickTitle,
                style: AppText.serif(fontSize: 18, letterSpacing: -0.3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                words.trustedPickSubtitle,
                style: AppText.regular(fontSize: 13, color: c.inkMuted).copyWith(height: 1.4),
              ),
            ),
            if (items == null)
              Padding(
                padding: const EdgeInsets.all(32),
                child: CircularProgressIndicator(color: c.ink, strokeWidth: 2),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                child: Text(
                  words.trustedNoCandidates,
                  textAlign: TextAlign.center,
                  style: AppText.regular(fontSize: 14, color: c.inkMuted).copyWith(height: 1.45),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CourierTile(
                    courier: items[i],
                    onTap: () => widget.onPick(items[i]),
                    trailing: Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: c.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CourierTile extends StatelessWidget {
  final TrustedCourier courier;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool busy;

  const _CourierTile({
    required this.courier,
    this.trailing,
    this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.borderSoft),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 20,
                  color: c.inkMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courier.name.isEmpty ? words.courier : courier.name,
                      style: AppText.semiBold(fontSize: 15, color: c.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      courier.deliveries > 0
                          ? words.trustedDeliveries.replaceAll('{n}', '${courier.deliveries}')
                          : courier.phone,
                      style: AppText.regular(fontSize: 13, color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: c.inkMuted,
                    strokeWidth: 2,
                  ),
                )
              else
                ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
