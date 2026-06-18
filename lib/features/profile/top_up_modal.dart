import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/point_icon.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/features/home/widgets/role_picker_modal.dart';
import 'package:bagla/features/profile/bank_picker.dart';
import 'package:bagla/features/profile/restricted_access_view.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../features/auth/auth_repository.dart';

// ─── Token package presets ────────────────────────────────────────────────────

/// Тип бейджа на карточке пакета. Сами строки локализуются через
/// AppLocalizations — здесь только enum-ключ, чтобы массив пакетов
/// оставался `const`.
enum _BadgeKind { popular, profitable }

class _TokenPackage {
  final int tokens;
  final _BadgeKind? badge;

  const _TokenPackage({required this.tokens, this.badge});
}

const _kPackages = [
  _TokenPackage(tokens: 10),
  _TokenPackage(tokens: 25, badge: _BadgeKind.popular),
  _TokenPackage(tokens: 50, badge: _BadgeKind.profitable),
  _TokenPackage(tokens: 100),
];

String? _badgeText(_BadgeKind? kind, AppLocalizations w) {
  switch (kind) {
    case _BadgeKind.popular:
      return w.topUpBadgePopular;
    case _BadgeKind.profitable:
      return w.topUpBadgeProfitable;
    case null:
      return null;
  }
}

// ─── TopUpModal ───────────────────────────────────────────────────────────────

class TopUpModal extends StatefulWidget {
  final String userId;
  final String role;
  final String status;

  /// ⚠️ Deprecated — используется только при тур-таргетах, где требуется
  /// инициализация ДО первого build (initState). В UI язык берётся из
  /// `LanguageProvider`, чтобы автоматически реагировать на toggle языка.
  /// Раньше caller'ы не передавали этот флаг → модалка всегда показывалась
  /// на RU независимо от выбранного языка.
  final bool isRu;
  final int? currentBalance; // optional: pass from parent to show balance chip

  const TopUpModal({
    super.key,
    required this.userId,
    required this.role,
    required this.status,
    this.isRu = true,
    this.currentBalance,
  });

  @override
  State<TopUpModal> createState() => _TopUpModalState();
}

class _TopUpModalState extends State<TopUpModal> with AppTourMixin<TopUpModal> {
  final TextEditingController _controller = TextEditingController();
  final AuthRepository _authRepo = AuthRepository();
  final _packagesKey = GlobalKey();
  final _payKey = GlobalKey();

  int _points = 0;
  int? _selectedPackageIndex;
  bool _isLoading = false;
  double _rate = 2.0;
  BankOption? _selectedBank;

  @override
  void initState() {
    super.initState();
    _loadRate();
    startTourIfNeeded(
      screenKey: TourKeys.topUpModal,
      targetsBuilder: _buildTourTargets,
      // У модалки нет AuthProvider — гейтим по переданным role/status.
      // client видит RolePicker, pending/restricted — RestrictedAccessView,
      // в обоих случаях тур поверх пакетов жетонов не нужен.
      shouldSkip: () {
        final r = widget.role.toLowerCase().trim();
        final s = widget.status.toLowerCase().trim();
        final isClient = r == 'client';
        final isRestricted =
            (r == 'shop' || r == 'business' || r == 'courier') &&
            (s == 'pending' || s == 'banned');
        return isClient || isRestricted;
      },
    );
  }

  List<TargetFocus> _buildTourTargets() {
    // Тур-таргеты строятся ДО первого build, поэтому здесь читаем
    // language через context.read (а не watch). Тур однократный,
    // язык не меняется по ходу обхода.
    final lang = context.read<LanguageProvider>();
    final isRuActual = lang.isRu;
    final w = lang.words;
    return [
      TourTarget.build(
        id: 'top_up_0',
        key: _packagesKey,
        titleRu: w.topUpTourPackagesTitle,
        titleTk: w.topUpTourPackagesTitle,
        bodyRu: w.topUpTourPackagesBody,
        bodyTk: w.topUpTourPackagesBody,
        isRu: isRuActual,
        align: ContentAlign.top,
      ),
      TourTarget.build(
        id: 'top_up_1',
        key: _payKey,
        titleRu: w.topUpTourPayTitle,
        titleTk: w.topUpTourPayTitle,
        bodyRu: w.topUpTourPayBody,
        bodyTk: w.topUpTourPayBody,
        isRu: isRuActual,
        align: ContentAlign.top,
      ),
    ];
  }

  Future<void> _loadRate() async {
    final rate = await _authRepo.fetchTokenRate();
    if (mounted) setState(() => _rate = rate ?? 2.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectPackage(int index) {
    final pkg = _kPackages[index];
    setState(() {
      _selectedPackageIndex = index;
      _points = pkg.tokens;
      _controller.clear();
    });
  }

  void _onCustomChanged(String val) {
    setState(() {
      _selectedPackageIndex = null;
      _points = int.tryParse(val) ?? 0;
    });
  }

  bool get _canSubmit => _points > 0 && _selectedBank != null && !_isLoading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isLoading = true);
    final success = await _authRepo.requestTopUp(
      userId: widget.userId,
      points: _points,
      amountTmt: (_points * _rate).toDouble(),
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.role.toLowerCase().trim();
    final String status = widget.status.toLowerCase().trim();

    final bool isClient = role == 'client';
    final bool isRestricted =
        (role == 'shop' || role == 'business' || role == 'courier') &&
        status == 'pending';

    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomSpace = bottomInset > 0
        ? bottomInset + 16
        : bottomPadding + 24;

    // Читаем из провайдера через watch — если юзер переключит язык
    // через LangToggle пока модалка открыта, тексты подменятся
    // моментально без переоткрытия.
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final bool isRu = lang.isRu;

    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),

            // ── Non-main states (client / restricted) ─────────────────────────
            if (isClient || isRestricted)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, bottomSpace),
                child: isClient
                    ? RolePickerEmbedded(onClose: () => Navigator.pop(context))
                    : RestrictedAccessView(
                        onActionPressed: () => Navigator.pop(context),
                      ),
              )
            // ── Main top-up flow ──────────────────────────────────────────────
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, bottomSpace),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _Header(
                        words: words,
                        onClose: () => Navigator.pop(context),
                      ),
                      const SizedBox(height: 20),

                      // Balance chip (optional)
                      if (widget.currentBalance != null) ...[
                        _BalanceChip(
                          balance: widget.currentBalance!,
                          words: words,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Bank picker
                      BankPickerSection(
                        isRu: isRu,
                        selected: _selectedBank,
                        onSelected: (bank) =>
                            setState(() => _selectedBank = bank),
                      ),
                      const SizedBox(height: 22),

                      // Token packages grid
                      _SectionLabel(text: words.topUpSectionTokensAmount),
                      const SizedBox(height: 10),
                      KeyedSubtree(
                        key: _packagesKey,
                        child: _PackagesGrid(
                          packages: _kPackages,
                          selectedIndex: _selectedPackageIndex,
                          rate: _rate,
                          words: words,
                          onSelect: _selectPackage,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Custom amount field
                      _CustomAmountField(
                        controller: _controller,
                        words: words,
                        isActive: _selectedPackageIndex == null && _points > 0,
                        onChanged: _onCustomChanged,
                      ),

                      // Summary row (animated)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.fastOutSlowIn,
                        child: _points > 0
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: _SummaryRow(
                                  points: _points,
                                  rate: _rate,
                                  words: words,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 22),

                      // Pay button
                      KeyedSubtree(
                        key: _payKey,
                        child: _PayButton(
                          enabled: _canSubmit,
                          isLoading: _isLoading,
                          words: words,
                          onTap: _submit,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Security note
                      _SecurityNote(words: words),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Header
// ═════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final AppLocalizations words;
  final VoidCallback onClose;

  const _Header({required this.words, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                words.topUpHeaderTitle,
                style: AppText.serif(fontSize: 20, color: c.ink),
              ),
              const SizedBox(height: 4),
              Text(
                words.topUpHeaderSubtitle,
                style: AppText.regular(fontSize: 13, color: c.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: words.a11yClose,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.borderSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.close_rounded, size: 16, color: c.inkMuted),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Section label
// ═════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppText.semiBold(
            fontSize: 10,
            color: c.inkSoft,
          ).copyWith(letterSpacing: 0.8),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Balance chip
// ═════════════════════════════════════════════════════════════════════════════

class _BalanceChip extends StatelessWidget {
  final int balance;
  final AppLocalizations words;
  const _BalanceChip({required this.balance, required this.words});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PointIcon(size: 15, tintColor: c.accent),
          const SizedBox(width: 7),
          Text(
            words.topUpBalanceLabel,
            style: AppText.regular(fontSize: 13, color: c.inkMuted),
          ),
          const SizedBox(width: 6),
          Text('$balance', style: AppText.semiBold(fontSize: 14, color: c.ink)),
          const SizedBox(width: 4),
          Text(
            words.topUpTokensUnit,
            style: AppText.regular(fontSize: 12, color: c.inkSoft),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Packages 2 × 2 grid
// ═════════════════════════════════════════════════════════════════════════════

class _PackagesGrid extends StatelessWidget {
  final List<_TokenPackage> packages;
  final int? selectedIndex;
  final double rate;
  final AppLocalizations words;
  final ValueChanged<int> onSelect;

  const _PackagesGrid({
    required this.packages,
    required this.selectedIndex,
    required this.rate,
    required this.words,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 96,
      ),
      itemCount: packages.length,
      itemBuilder: (_, i) => _PackageCard(
        package: packages[i],
        isSelected: selectedIndex == i,
        rate: rate,
        words: words,
        onTap: () => onSelect(i),
      ),
    );
  }
}

// ─── Single package card ───────────────────────────────────────────────────────

class _PackageCard extends StatefulWidget {
  final _TokenPackage package;
  final bool isSelected;
  final double rate;
  final AppLocalizations words;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.isSelected,
    required this.rate,
    required this.words,
    required this.onTap,
  });

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  bool _pressed = false;

  String _formatPrice(double price) {
    return price == price.truncateToDouble()
        ? '${price.toInt()} TMT'
        : '${price.toStringAsFixed(1)} TMT';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final badge = _badgeText(widget.package.badge, widget.words);
    final price = widget.package.tokens * widget.rate;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? c.accent.withValues(alpha: 0.05)
                : c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected ? c.accent : c.border,
              width: widget.isSelected ? 2.0 : 1.0,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.package.tokens}',
                        style: AppText.bold(
                          fontSize: 26,
                          color: widget.isSelected ? c.accent : c.ink,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          widget.words.topUpTokensUnitShort,
                          style: AppText.regular(
                            fontSize: 11,
                            color: c.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(price),
                    style: AppText.semiBold(
                      fontSize: 13,
                      color: widget.isSelected ? c.ink : c.inkMuted,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.emeraldTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: AppText.semiBold(fontSize: 9, color: c.ink),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Custom amount field
// ═════════════════════════════════════════════════════════════════════════════

class _CustomAmountField extends StatelessWidget {
  final TextEditingController controller;
  final AppLocalizations words;
  final bool isActive; // true when user chose custom over a preset
  final ValueChanged<String> onChanged;

  const _CustomAmountField({
    required this.controller,
    required this.words,
    required this.isActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppText.medium(fontSize: 15, color: c.ink),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: words.topUpCustomAmountHint,
        hintStyle: AppText.regular(fontSize: 13, color: c.inkSoft),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Icon(
            Icons.edit_outlined,
            size: 16,
            color: isActive ? c.accent : c.inkSoft,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: isActive ? c.accent.withValues(alpha: 0.04) : c.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isActive ? c.accent : c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: c.accent.withValues(alpha: 0.65),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Summary row
// ═════════════════════════════════════════════════════════════════════════════

class _SummaryRow extends StatelessWidget {
  final int points;
  final double rate;
  final AppLocalizations words;

  const _SummaryRow({
    required this.points,
    required this.rate,
    required this.words,
  });

  String _formatAmount(double v) => v == v.truncateToDouble()
      ? '${v.toInt()} TMT'
      : '${v.toStringAsFixed(1)} TMT';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final amount = points * rate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            words.topUpSummaryYouGet,
            style: AppText.regular(fontSize: 14, color: c.inkMuted),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$points',
                  style: AppText.bold(fontSize: 17, color: c.accent),
                ),
                TextSpan(
                  // Пробел перед сокращением — намеренно (см. визуал).
                  text: ' ${words.topUpTokensUnitShort}',
                  style: AppText.regular(fontSize: 13, color: c.inkMuted),
                ),
                TextSpan(
                  text: '  ·  ',
                  style: AppText.regular(fontSize: 13, color: c.borderSoft),
                ),
                TextSpan(
                  text: _formatAmount(amount),
                  style: AppText.semiBold(fontSize: 15, color: c.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Pay button
// ═════════════════════════════════════════════════════════════════════════════

class _PayButton extends StatefulWidget {
  final bool enabled;
  final bool isLoading;
  final AppLocalizations words;
  final VoidCallback onTap;

  const _PayButton({
    required this.enabled,
    required this.isLoading,
    required this.words,
    required this.onTap,
  });

  @override
  State<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<_PayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final active = widget.enabled && !widget.isLoading;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.enabled ? c.ink : c.borderSoft,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.bg),
                )
              : Text(
                  widget.words.topUpPayBtn,
                  style: AppText.semiBold(
                    fontSize: 14,
                    color: widget.enabled ? c.bg : c.inkSoft,
                  ).copyWith(letterSpacing: 0.3),
                ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Security note
// ═════════════════════════════════════════════════════════════════════════════

class _SecurityNote extends StatelessWidget {
  final AppLocalizations words;
  const _SecurityNote({required this.words});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 11, color: c.inkSoft),
        const SizedBox(width: 5),
        Text(
          words.topUpSecurityNote,
          style: AppText.regular(fontSize: 11, color: c.inkSoft),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sheet handle
// ═════════════════════════════════════════════════════════════════════════════

// Граббер вынесен в общий core/widgets/sheet_handle.dart (SheetHandle).
