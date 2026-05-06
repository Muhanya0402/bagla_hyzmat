import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/api_client.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:bagla/providers/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);
  static const _bg = Color(0xFFF5F7FA);
  static const _border = Color(0xFFEEF0F3);
  static const _gradient = LinearGradient(
    colors: [_green, _red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── State ──────────────────────────────────────────────────────────────────
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

    final String fullName = '${auth.name} ${auth.surname}'.trim().isNotEmpty
        ? '${auth.name} ${auth.surname}'.trim()
        : auth.phone;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _green,
              size: 16,
            ),
          ),
        ),
        title: Text(
          isRu ? 'Условия использования' : 'Ulanyş şertleri',
          style: AppText.semiBold(fontSize: 17, color: const Color(0xFF0F1117)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _border),
        ),
      ),
      body: _buildBody(isRu, fullName),
    );
  }

  Widget _buildBody(bool isRu, String fullName) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _green, strokeWidth: 2),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: _grey, size: 40),
            const SizedBox(height: 12),
            Text(
              isRu ? 'Ошибка загрузки' : 'Ýüklemek ýalňyşlygy',
              style: AppText.semiBold(fontSize: 15, color: _grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadTerms,
              child: Text(
                isRu ? 'Повторить' : 'Gaýtalaň',
                style: AppText.semiBold(fontSize: 14, color: _green),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Scrollable terms ────────────────────────────────────────────────
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Header card
              _buildHeader(isRu),
              const SizedBox(height: 16),

              // Terms items
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

              const SizedBox(height: 24),

              // Scroll hint
              if (!_hasScrolledToBottom) _scrollHint(isRu),
            ],
          ),
        ),

        // ── Signature footer ────────────────────────────────────────────────
        _buildSignatureFooter(isRu, fullName),
      ],
    );
  }

  // ── Header card ────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isRu) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top gradient bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: _gradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_green.withOpacity(0.12), _red.withOpacity(0.07)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: _green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => _gradient.createShader(b),
                      child: Text(
                        isRu ? 'Условия использования' : 'Ulanyş şertleri',
                        style: AppText.extraBold(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isRu
                          ? 'Пожалуйста, ознакомьтесь со всеми пунктами'
                          : 'Ähli nokatlary okaň',
                      style: AppText.regular(fontSize: 12, color: _grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 13, color: _grey),
              const SizedBox(width: 6),
              Text(
                isRu
                    ? 'Прокрутите до конца, чтобы принять'
                    : 'Kabul etmek üçin aşak aýlaň',
                style: AppText.regular(fontSize: 12, color: _grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Scroll hint ─────────────────────────────────────────────────────────────

  Widget _scrollHint(bool isRu) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.keyboard_arrow_down_rounded, color: _grey, size: 20),
          Text(
            isRu
                ? 'Прокрутите вниз для принятия'
                : 'Kabul etmek üçin aşak aýlaň',
            style: AppText.regular(fontSize: 11, color: _grey),
          ),
        ],
      ),
    );
  }

  // ── Signature footer ────────────────────────────────────────────────────────

  Widget _buildSignatureFooter(bool isRu, String fullName) {
    final bool canAccept = _hasScrolledToBottom || _items.isEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Signature card
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: canAccept ? _green.withOpacity(0.06) : _bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: canAccept ? _green.withOpacity(0.25) : _border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: canAccept
                        ? _green.withOpacity(0.12)
                        : _grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: canAccept ? _green : _grey,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu ? 'Принял условия' : 'Kabul etdi',
                        style: AppText.regular(fontSize: 11, color: _grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fullName.isNotEmpty
                            ? fullName
                            : (isRu ? 'Пользователь' : 'Ulanyjy'),
                        style: AppText.bold(
                          fontSize: 15,
                          color: canAccept ? const Color(0xFF0F1117) : _grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkmark
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: canAccept
                      ? Container(
                          key: const ValueKey('check'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: _gradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        )
                      : Container(
                          key: const ValueKey('lock'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: _grey,
                            size: 14,
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Accept button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: canAccept ? _gradient : null,
                color: canAccept ? null : _bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: canAccept
                    ? [
                        BoxShadow(
                          color: _green.withOpacity(0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: canAccept ? () => Navigator.pop(context) : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isRu ? 'ПОНЯТНО' : 'DÜŞÜNDÜM',
                      style: AppText.bold(
                        fontSize: 14,
                        color: canAccept ? Colors.white : _grey,
                      ).copyWith(letterSpacing: 0.4),
                    ),
                    if (canAccept) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Term tile — accordion style
// ─────────────────────────────────────────────────────────────────────────────

class _TermTile extends StatelessWidget {
  final _TermItem item;
  final int index;
  final bool isRu;
  final bool isExpanded;
  final VoidCallback onTap;

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);
  static const _border = Color(0xFFEEF0F3);
  static const _gradient = LinearGradient(colors: [_green, _red]);

  const _TermTile({
    required this.item,
    required this.index,
    required this.isRu,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String title = isRu ? item.titleRu : item.titleTk;
    final String body = isRu ? item.bodyRu : item.bodyTk;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? _green.withOpacity(0.3) : _border,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: _green.withOpacity(0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Number badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: isExpanded ? _gradient : null,
                      color: isExpanded ? null : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isExpanded ? Colors.white : _grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title.isEmpty
                          ? (isRu
                                ? 'Пункт ${index + 1}'
                                : '${index + 1}-nji madda')
                          : title,
                      style: AppText.semiBold(
                        fontSize: 14,
                        color: isExpanded
                            ? const Color(0xFF0F1117)
                            : const Color(0xFF0F1117),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? _green : _grey,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Body (animated)
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: _border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Text(
                      body.isEmpty
                          ? (isRu
                                ? 'Текст пункта не заполнен.'
                                : 'Madda teksti doldurylmady.')
                          : body,
                      style: AppText.regular(
                        fontSize: 13,
                        color: const Color(0xFF4A4A4A),
                      ).copyWith(height: 1.65),
                    ),
                  ),
                ],
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

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
