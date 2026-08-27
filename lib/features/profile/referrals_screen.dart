import 'package:bagla/core/app_settings_provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/profile/referrals_service.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

/// «Приведи друга» — реферальная программа курьера.
///
/// Порядок действий важен и объясняется прямо на экране: сначала вписать
/// номер, потом друг скачивает приложение. Пригласить уже зарегистрированного
/// нельзя — сервер откажет, и человек должен понимать почему заранее.
class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  final _service = ReferralsService();

  List<Referral> _list = [];
  bool _loading = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.list();
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

  String _outcomeText(ReferralOutcome o, AppLocalizations words) {
    switch (o) {
      case ReferralOutcome.badPhone:
        return words.refErrBadPhone;
      case ReferralOutcome.selfInvite:
        return words.refErrSelf;
      case ReferralOutcome.alreadyRegistered:
        return words.refErrRegistered;
      case ReferralOutcome.alreadyInvited:
        return words.refErrInvited;
      case ReferralOutcome.limitReached:
        return words.refErrLimit;
      case ReferralOutcome.notFound:
        return words.refErrNotFound;
      case ReferralOutcome.disabled:
        return words.refErrDisabled;
      case ReferralOutcome.notACourier:
      case ReferralOutcome.error:
      case ReferralOutcome.ok:
        return words.refErrGeneric;
    }
  }

  Future<void> _invite(AppLocalizations words) async {
    final phone = await _askPhone(words);
    if (phone == null || phone.isEmpty) return;
    setState(() => _busyId = -1);
    final r = await _service.invite(phone);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (r == ReferralOutcome.ok) {
      await _load();
      _toast(words.refInvited);
    } else {
      _toast(_outcomeText(r, words), bad: true);
    }
  }

  Future<String?> _askPhone(AppLocalizations words) {
    final ctrl = TextEditingController();
    final mask = MaskTextInputFormatter(
      mask: '## ## ## ##',
      filter: {'#': RegExp(r'[0-9]')},
    );
    final c = AppColors.of(context);

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              words.refAskTitle,
              style: AppText.serif(fontSize: 18, letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            Text(
              words.refAskSubtitle,
              style: AppText.regular(
                fontSize: 13,
                color: c.inkMuted,
              ).copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [mask],
              style: AppText.medium(fontSize: 16, color: c.ink),
              decoration: InputDecoration(
                prefixText: '+993 ',
                prefixStyle: AppText.medium(fontSize: 16, color: c.inkMuted),
                hintText: '6X XX XX XX',
                hintStyle: AppText.regular(fontSize: 16, color: c.inkSoft),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.ink),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: Text(
                  words.refAskSubmit,
                  style: AppText.semiBold(fontSize: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(Referral r, AppLocalizations words) async {
    setState(() => _busyId = r.id);
    final res = await _service.cancel(r.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (res == ReferralOutcome.ok) {
      await _load();
      _toast(words.refCancelled);
    } else {
      _toast(_outcomeText(res, words), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
    final reward = context.watch<AppSettingsProvider>().referralReward;

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
          words.refTitle,
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
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  _buildHowItWorks(words, c, reward),
                  const SizedBox(height: 16),
                  if (_list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
                      child: Text(
                        words.refEmpty,
                        textAlign: TextAlign.center,
                        style: AppText.regular(
                          fontSize: 14,
                          color: c.inkMuted,
                        ).copyWith(height: 1.45),
                      ),
                    )
                  else ...[
                    _buildSummary(words, c),
                    const SizedBox(height: 10),
                    for (final r in _list) ...[
                      _buildTile(r, words, c),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busyId != null ? null : () => _invite(words),
        backgroundColor: c.ink,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
        label: Text(
          words.refInviteBtn,
          style: AppText.semiBold(fontSize: 14, color: Colors.white),
        ),
      ),
    );
  }

  /// Как это работает. Порядок шагов — главное, что нужно понять: приглашение
  /// вписывается ДО того, как друг скачает приложение.
  Widget _buildHowItWorks(AppLocalizations words, AppColors c, int reward) {
    final steps = [
      words.refStep1,
      words.refStep2,
      words.refStep3.replaceAll('{n}', '$reward'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: c.emeraldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            words.refHowTitle,
            style: AppText.serif(fontSize: 17, letterSpacing: -0.3),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppText.semiBold(fontSize: 11, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[i],
                    style: AppText.regular(
                      fontSize: 13.5,
                      color: c.ink,
                    ).copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(AppLocalizations words, AppColors c) {
    final paid = _list.where((r) => r.isPaid).toList();
    final earned = paid.fold<int>(0, (s, r) => s + r.reward);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Text(
        words.refSummary
            .replaceAll('{friends}', '${_list.length}')
            .replaceAll('{tokens}', '$earned'),
        style: AppText.medium(fontSize: 13, color: c.inkMuted),
      ),
    );
  }

  Widget _buildTile(Referral r, AppLocalizations words, AppColors c) {
    final busy = _busyId == r.id;
    final (IconData icon, String label, Color tint) = switch (r.status) {
      'paid' => (
        Icons.check_circle_outline,
        words.refStatusPaid.replaceAll('{n}', '${r.reward}'),
        c.emeraldTint,
      ),
      'registered' => (
        Icons.how_to_reg_outlined,
        words.refStatusRegistered,
        c.amberTint,
      ),
      _ => (Icons.schedule, words.refStatusWaiting, c.borderSoft),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: c.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.inviteeName.isNotEmpty ? r.inviteeName : _pretty(r.phone),
                  style: AppText.semiBold(fontSize: 15, color: c.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
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
          // Убрать можно только пока друг не зарегистрировался: дальше строка
          // уже что-то значит, а после выплаты это ещё и история начислений.
          else if (r.isPending)
            IconButton(
              onPressed: _busyId != null ? null : () => _cancel(r, words),
              icon: Icon(Icons.close_rounded, size: 18, color: c.inkMuted),
            ),
        ],
      ),
    );
  }

  /// `+99361553303` → `+993 61 55 33 03`.
  static String _pretty(String phone) {
    if (phone.length != 12) return phone;
    final d = phone.substring(4);
    return '+993 ${d.substring(0, 2)} ${d.substring(2, 4)} '
        '${d.substring(4, 6)} ${d.substring(6)}';
  }
}
