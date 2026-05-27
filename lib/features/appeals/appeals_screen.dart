import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/api_client.dart';
import 'package:bagla/features/appeals/widgets/appeal_card.dart';
import 'package:bagla/features/appeals/widgets/appeal_detail_sheet.dart';
import 'package:bagla/features/appeals/widgets/create_appeal_sheet.dart';
import 'package:bagla/features/auth/auth_constants.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppealsScreen extends StatefulWidget {
  const AppealsScreen({super.key});

  @override
  State<AppealsScreen> createState() => _AppealsScreenState();
}

class _AppealsScreenState extends State<AppealsScreen> {
  List<dynamic> _appeals = [];
  bool _isLoading = true;
  String? _error;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _loadAppeals();
  }

  Future<void> _loadAppeals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final res = await ApiClient().dio.get(
        '/items/appeals',
        queryParameters: {
          'filter[user_id][_eq]': auth.userId,
          'sort': '-date_created',
          'fields': 'id,status,subject,body,date_created,reply',
        },
      );
      setState(() => _appeals = res.data['data'] ?? []);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    return PopScope(
      canPop: !_sheetOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sheetOpen) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
      child: Scaffold(
      backgroundColor: AuthColors.bg,
      appBar: AppBar(
        backgroundColor: AuthColors.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AuthColors.border),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AuthColors.ink,
              size: 16,
            ),
          ),
        ),
        title: Text(
          words.appealsTitle,
          style: AppText.serif(fontSize: 20, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AuthColors.border),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Кнопка нового обращения ──────────────────────────────────
          _NewAppealButton(
            label: words.appealsNew,
            hint: words.appealsHint,
            onTap: () => _showCreateSheet(context, words),
          ),
          Container(height: 0.5, color: AuthColors.border),

          // ── Список апелляций ─────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AuthColors.emerald,
              backgroundColor: AuthColors.surface,
              onRefresh: _loadAppeals,
              child: _buildBody(context, words),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations words) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AuthColors.emerald,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          _CenterState(
            icon: Icons.wifi_off_rounded,
            iconColor: AuthColors.errorMuted,
            iconBg: AuthColors.errorTint,
            title: words.appealsLoadError,
            subtitle: words.appealsPullRefresh,
          ),
        ],
      );
    }

    if (_appeals.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          _CenterState(
            icon: Icons.inbox_outlined,
            iconColor: AuthColors.inkSoft,
            iconBg: AuthColors.borderSoft,
            title: words.appealsEmpty,
            subtitle: words.appealsEmptyDesc,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: _appeals.length,
      itemBuilder: (_, i) => AppealCard(
        appeal: _appeals[i],
        words: words,
        onTap: () => _showDetailSheet(context, _appeals[i], words),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, AppLocalizations words) {
    setState(() => _sheetOpen = true);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateAppealSheet(
        onCreated: () {
          Navigator.of(context, rootNavigator: true).pop();
          _loadAppeals();
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  void _showDetailSheet(
    BuildContext context,
    dynamic appeal,
    AppLocalizations words,
  ) {
    setState(() => _sheetOpen = true);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppealDetailSheet(appeal: appeal, words: words),
    ).whenComplete(() {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }
}

// ─── New appeal button block ───────────────────────────────────────────────────

class _NewAppealButton extends StatefulWidget {
  final String label;
  final String hint;
  final VoidCallback onTap;

  const _NewAppealButton({
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  State<_NewAppealButton> createState() => _NewAppealButtonState();
}

class _NewAppealButtonState extends State<_NewAppealButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AuthColors.ink,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AuthColors.ink.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.label,
                      style: AppText.semiBold(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 12,
                color: AuthColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.hint,
                  style: AppText.regular(
                    fontSize: 12,
                    color: AuthColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Center empty / error state ────────────────────────────────────────────────

class _CenterState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _CenterState({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AuthColors.border),
            ),
            child: Icon(icon, size: 26, color: iconColor),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppText.semiBold(fontSize: 15, color: AuthColors.ink),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppText.regular(
              fontSize: 13,
              color: AuthColors.inkMuted,
            ).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
