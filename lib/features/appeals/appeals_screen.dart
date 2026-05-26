import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/api_client.dart';
import 'package:bagla/features/appeals/widgets/appeal_card.dart';
import 'package:bagla/features/appeals/widgets/appeal_detail_sheet.dart';
import 'package:bagla/features/appeals/widgets/create_appeal_sheet.dart';
import 'package:bagla/features/profile/lang_toggle.dart';
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
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);
  static const _bg = Color(0xFFF5F7FA);
  static const _gradient = LinearGradient(
    colors: [_green, _red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  List<dynamic> _appeals = [];
  bool _isLoading = true;
  String? _error;

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
              color: _green.withValues(alpha: 0.07),
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
          words.appealsTitle,
          style: AppText.semiBold(fontSize: 17, color: const Color(0xFF0F1117)),
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16), child: LangToggle()),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF0F3)),
        ),
      ),
      floatingActionButton: _buildFab(context, words),
      body: RefreshIndicator(
        color: _green,
        onRefresh: _loadAppeals,
        child: _buildBody(context, words),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFab(BuildContext context, AppLocalizations words) {
    return GestureDetector(
      onTap: () => _showCreateSheet(context),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: _gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _green.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              words.appealsNew,
              style: AppText.semiBold(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, AppLocalizations words) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _green, strokeWidth: 2),
      );
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEEF0F3)),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: _grey,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  words.appealsLoadError,
                  style: AppText.semiBold(fontSize: 15, color: _grey),
                ),
                const SizedBox(height: 4),
                Text(
                  words.appealsPullRefresh,
                  style: AppText.regular(fontSize: 13, color: _grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_appeals.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEEF0F3)),
                  ),
                  child: const Icon(
                    Icons.inbox_rounded,
                    color: _grey,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  words.appealsEmpty,
                  style: AppText.semiBold(fontSize: 15, color: _grey),
                ),
                const SizedBox(height: 6),
                Text(
                  words.appealsEmptyDesc,
                  style: AppText.regular(fontSize: 13, color: _grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _appeals.length,
      itemBuilder: (_, i) => AppealCard(
        appeal: _appeals[i],
        words: words,
        onTap: () => _showDetailSheet(context, _appeals[i], words),
      ),
    );
  }

  // ── Sheets ─────────────────────────────────────────────────────────────────

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateAppealSheet(
        onCreated: () {
          Navigator.pop(context);
          _loadAppeals();
        },
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    dynamic appeal,
    AppLocalizations words,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppealDetailSheet(appeal: appeal, words: words),
    );
  }
}
