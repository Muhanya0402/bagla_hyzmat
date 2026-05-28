import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/api_client.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  List<_TermItem> _items = [];
  bool _isLoading = true;
  String? _error;
  int? _expandedIndex;

  final _scrollCtrl = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _loadTerms();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasScrolledToBottom &&
        _scrollCtrl.offset >= _scrollCtrl.position.maxScrollExtent - 60) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  Future<void> _loadTerms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get(
        '/items/terms_items',
        queryParameters: {
          'sort': 'sort',
          'fields': 'id,sort,title_ru,title_tk,body_ru,body_tk',
        },
      );
      final data = (res.data['data'] as List?) ?? [];
      setState(() {
        _items = data.map((e) => _TermItem.fromJson(e)).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();
    final isRu = lang.isRu;
    final words = lang.words;

    final String fullName = '${auth.name} ${auth.surname}'.trim().isNotEmpty
        ? '${auth.name} ${auth.surname}'.trim()
        : auth.phone;

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.of(context).ink,
              size: 16,
            ),
          ),
        ),
        title: Text(
          words.termsOfUse,
          style: AppText.serif(fontSize: 20, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.of(context).border),
        ),
      ),
      body: _buildBody(isRu, fullName, words),
    );
  }

  Widget _buildBody(bool isRu, String fullName, AppLocalizations words) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.of(context).emerald,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.of(context).errorTint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.of(context).border),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.of(context).errorMuted,
                  size: 26,
                ),
              ),
              SizedBox(height: 14),
              Text(
                words.downloadError,
                style: AppText.semiBold(fontSize: 15, color: AppColors.of(context).ink),
              ),
              SizedBox(height: 14),
              _RetryButton(label: words.retry, onTap: _loadTerms),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              // ── Quick summary ───────────────────────────────────────────
              _QuickSummary(isRu: isRu),
              SizedBox(height: 16),

              // ── Section label ───────────────────────────────────────────
              _SectionLabel(
                text: isRu ? 'РАЗДЕЛЫ СОГЛАШЕНИЯ' : 'YLALAŞYK BÖLÜMLERI',
              ),
              SizedBox(height: 8),

              // ── Term tiles ──────────────────────────────────────────────
              ..._items.asMap().entries.map(
                (e) => _TermTile(
                  item: e.value,
                  index: e.key,
                  isRu: isRu,
                  isExpanded: _expandedIndex == e.key,
                  onTap: () => setState(() {
                    _expandedIndex = _expandedIndex == e.key ? null : e.key;
                  }),
                ),
              ),

              if (!_hasScrolledToBottom && _items.isNotEmpty) ...[
                SizedBox(height: 12),
                _ScrollHint(isRu: isRu),
              ],
              SizedBox(height: 8),
            ],
          ),
        ),

        // ── Footer ──────────────────────────────────────────────────────
        _SignatureFooter(
          isRu: isRu,
          fullName: fullName,
          canAccept: _hasScrolledToBottom || _items.isEmpty,
          onAccept: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

// ─── Quick summary strip ──────────────────────────────────────────────────────

class _QuickSummary extends StatelessWidget {
  final bool isRu;
  const _QuickSummary({required this.isRu});

  @override
  Widget build(BuildContext context) {
    final items = isRu
        ? [
            _SummaryItem(
              icon: Icons.bolt_rounded,
              iconColor: AppColors.of(context).amber,
              iconBg: AppColors.of(context).amberTint,
              text: '5 жетонов за выкуп заказа',
            ),
            _SummaryItem(
              icon: Icons.local_shipping_rounded,
              iconColor: AppColors.of(context).emerald,
              iconBg: AppColors.of(context).emeraldTint,
              text: 'Доставка строго в срок',
            ),
            _SummaryItem(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.of(context).errorMuted,
              iconBg: AppColors.of(context).errorTint,
              text: 'Штраф за срыв доставки',
            ),
          ]
        : [
            _SummaryItem(
              icon: Icons.bolt_rounded,
              iconColor: AppColors.of(context).amber,
              iconBg: AppColors.of(context).amberTint,
              text: 'Zakaz üçin 5 žeton',
            ),
            _SummaryItem(
              icon: Icons.local_shipping_rounded,
              iconColor: AppColors.of(context).emerald,
              iconBg: AppColors.of(context).emeraldTint,
              text: 'Eltip bermek wagtynda',
            ),
            _SummaryItem(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.of(context).errorMuted,
              iconBg: AppColors.of(context).errorTint,
              text: 'Goýbolsun üçin jerime',
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.of(context).accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 7),
              Text(
                isRu ? 'ГЛАВНОЕ' : 'ESASY',
                style: AppText.semiBold(
                  fontSize: 10,
                  color: AppColors.of(context).inkSoft,
                ).copyWith(letterSpacing: 0.9),
              ),
            ],
          ),
          SizedBox(height: 11),
          Row(
            children: items
                .map((item) => Expanded(child: _SummaryCard(item: item)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String text;
  const _SummaryItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.text,
  });
}

class _SummaryCard extends StatelessWidget {
  final _SummaryItem item;
  const _SummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: item.iconColor.withValues(alpha: 0.15)),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 16),
          ),
          SizedBox(height: 7),
          Text(
            item.text,
            textAlign: TextAlign.center,
            style: AppText.medium(
              fontSize: 11,
              color: AppColors.of(context).inkMuted,
            ).copyWith(height: 1.35),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.of(context).emerald,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 7),
        Text(
          text,
          style: AppText.semiBold(
            fontSize: 10,
            color: AppColors.of(context).inkSoft,
          ).copyWith(letterSpacing: 0.9),
        ),
      ],
    );
  }
}

// ─── Scroll hint ──────────────────────────────────────────────────────────────

class _ScrollHint extends StatelessWidget {
  final bool isRu;
  const _ScrollHint({required this.isRu});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
                    Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 15,
            color: AppColors.of(context).inkSoft,
          ),
          SizedBox(width: 4),
          Text(
            isRu
                ? 'Прокрутите вниз для принятия'
                : 'Kabul etmek üçin aşak aýlaň',
            style: AppText.regular(fontSize: 11, color: AppColors.of(context).inkSoft),
          ),
        ],
      ),
    );
  }
}

// ─── Signature footer ─────────────────────────────────────────────────────────

class _SignatureFooter extends StatelessWidget {
  final bool isRu;
  final String fullName;
  final bool canAccept;
  final VoidCallback onAccept;

  const _SignatureFooter({
    required this.isRu,
    required this.fullName,
    required this.canAccept,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        border: Border(
          top: BorderSide(color: AppColors.of(context).border, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Signature card ─────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: canAccept ? AppColors.of(context).emeraldTint : AppColors.of(context).bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canAccept
                    ? AppColors.of(context).ink.withValues(alpha: 0.3)
                    : AppColors.of(context).border,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: canAccept
                        ? AppColors.of(context).ink.withValues(alpha: 0.12)
                        : AppColors.of(context).borderSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: canAccept ? AppColors.of(context).ink : AppColors.of(context).inkSoft,
                    size: 17,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu ? 'Принял условия' : 'Kabul etdi',
                        style: AppText.regular(
                          fontSize: 11,
                          color: AppColors.of(context).inkSoft,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        fullName.isNotEmpty
                            ? fullName
                            : (isRu ? 'Пользователь' : 'Ulanyjy'),
                        style: AppText.semiBold(
                          fontSize: 14,
                          color: canAccept
                              ? AppColors.of(context).ink
                              : AppColors.of(context).inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: canAccept
                      ? Container(
                          key: const ValueKey('check'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.of(context).ink,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        )
                      : Container(
                          key: const ValueKey('lock'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.of(context).borderSoft,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.of(context).border),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.of(context).inkSoft,
                            size: 13,
                          ),
                        ),
                ),
              ],
            ),
          ),

          SizedBox(height: 10),

          // ── Accept button ──────────────────────────────────────────
          _AcceptButton(
            isRu: isRu,
            canAccept: canAccept,
            onTap: canAccept ? onAccept : null,
          ),
        ],
      ),
    );
  }
}

// ─── Accept button ────────────────────────────────────────────────────────────

class _AcceptButton extends StatefulWidget {
  final bool isRu;
  final bool canAccept;
  final VoidCallback? onTap;

  const _AcceptButton({
    required this.isRu,
    required this.canAccept,
    required this.onTap,
  });

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: widget.canAccept ? AppColors.of(context).ink : AppColors.of(context).borderSoft,
            borderRadius: BorderRadius.circular(13),
            boxShadow: widget.canAccept
                ? [
                    BoxShadow(
                      color: AppColors.of(context).ink.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppText.semiBold(
                  fontSize: 14,
                  color: widget.canAccept ? Colors.white : AppColors.of(context).ink,
                ).copyWith(letterSpacing: 0.4),
                child: Text(widget.isRu ? 'ПОНЯТНО' : 'DÜŞÜNDÜM'),
              ),
              if (widget.canAccept) ...[
                SizedBox(width: 10),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Retry button ─────────────────────────────────────────────────────────────

class _RetryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _RetryButton({required this.label, required this.onTap});

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.of(context).emeraldTint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.of(context).emerald.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            widget.label,
            style: AppText.semiBold(fontSize: 13, color: AppColors.of(context).emerald),
          ),
        ),
      ),
    );
  }
}

// ─── Term tile ────────────────────────────────────────────────────────────────

class _TermTile extends StatefulWidget {
  final _TermItem item;
  final int index;
  final bool isRu;
  final bool isExpanded;
  final VoidCallback onTap;

  const _TermTile({
    required this.item,
    required this.index,
    required this.isRu,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_TermTile> createState() => _TermTileState();
}

class _TermTileState extends State<_TermTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final String title = widget.isRu
        ? widget.item.titleRu
        : widget.item.titleTk;
    final String body = widget.isRu ? widget.item.bodyRu : widget.item.bodyTk;
    final fallbackTitle = widget.isRu
        ? 'Пункт ${widget.index + 1}'
        : '${widget.index + 1}-nji madda';
    final fallbackBody = widget.isRu
        ? 'Текст пункта не заполнен.'
        : 'Madda teksti doldurylmady.';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isExpanded
                  ? AppColors.of(context).emerald.withValues(alpha: 0.3)
                  : AppColors.of(context).border,
            ),
          ),
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    // Number badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: widget.isExpanded
                            ? AppColors.of(context).ink
                            : AppColors.of(context).borderSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${widget.index + 1}',
                        style: AppText.semiBold(
                          fontSize: 11,
                          color: widget.isExpanded
                              ? Colors.white
                              : AppColors.of(context).inkSoft,
                        ),
                      ),
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title.isEmpty ? fallbackTitle : title,
                        style: AppText.medium(
                          fontSize: 13,
                          color: AppColors.of(context).ink,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    AnimatedRotation(
                      turns: widget.isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: widget.isExpanded
                            ? AppColors.of(context).emerald
                            : AppColors.of(context).inkSoft,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ───────────────────────────────────────────────
              AnimatedCrossFade(
                firstChild: SizedBox(width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 0.5, color: AppColors.of(context).borderSoft),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Text(
                        body.isEmpty ? fallbackBody : body,
                        style: AppText.regular(
                          fontSize: 13,
                          color: AppColors.of(context).inkMuted,
                        ).copyWith(height: 1.65),
                      ),
                    ),
                  ],
                ),
                crossFadeState: widget.isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _TermItem {
  final int id;
  final String titleRu;
  final String titleTk;
  final String bodyRu;
  final String bodyTk;

  const _TermItem({
    required this.id,
    required this.titleRu,
    required this.titleTk,
    required this.bodyRu,
    required this.bodyTk,
  });

  factory _TermItem.fromJson(Map<String, dynamic> json) => _TermItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    titleRu: (json['title_ru'] ?? '').toString(),
    titleTk: (json['title_tk'] ?? '').toString(),
    bodyRu: (json['body_ru'] ?? '').toString(),
    bodyTk: (json['body_tk'] ?? '').toString(),
  );
}
