import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/api_client.dart';
import 'package:bagla/features/profile/lang_toggle.dart';
import 'package:bagla/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppealsScreen — список обращений + создание нового
// Directus endpoint: /items/appeals
// Fields: id, status, subject, body, created_at, user_id, reply
// ─────────────────────────────────────────────────────────────────────────────

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
          'Мои обращения',
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
      floatingActionButton: _buildFab(context),
      body: RefreshIndicator(
        color: _green,
        onRefresh: _loadAppeals,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
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
              color: _green.withOpacity(0.3),
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
              'Новое обращение',
              style: AppText.semiBold(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
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
                  'Ошибка загрузки',
                  style: AppText.semiBold(fontSize: 15, color: _grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'Потяните вниз для повтора',
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
                  'Обращений пока нет',
                  style: AppText.semiBold(fontSize: 15, color: _grey),
                ),
                const SizedBox(height: 6),
                Text(
                  'Создайте первое обращение\nнажав кнопку снизу',
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
      itemBuilder: (_, i) => _AppealCard(
        appeal: _appeals[i],
        onTap: () => _showDetailSheet(context, _appeals[i]),
      ),
    );
  }

  // ── Create sheet ───────────────────────────────────────────────────────────

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateAppealSheet(
        onCreated: () {
          Navigator.pop(context);
          _loadAppeals();
        },
      ),
    );
  }

  // ── Detail sheet ───────────────────────────────────────────────────────────

  void _showDetailSheet(BuildContext context, dynamic appeal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppealDetailSheet(appeal: appeal),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Appeal card
// ═════════════════════════════════════════════════════════════════════════════

class _AppealCard extends StatelessWidget {
  final dynamic appeal;
  final VoidCallback onTap;
  const _AppealCard({required this.appeal, required this.onTap});

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);

  @override
  Widget build(BuildContext context) {
    final String status = (appeal['status'] ?? 'open').toString();
    final String subject = (appeal['subject'] ?? '').toString();
    final String body = (appeal['body'] ?? '').toString();
    final String date = _formatDate(appeal['date_created']);
    final bool hasReply = (appeal['reply'] ?? '').toString().isNotEmpty;

    final _StatusCfg cfg = _statusCfg(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEF0F3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top gradient strip — color by status
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: cfg.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject.isEmpty ? 'Без темы' : subject,
                          style: AppText.semiBold(
                            fontSize: 14,
                            color: const Color(0xFF0F1117),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cfg.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: cfg.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              cfg.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: cfg.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: AppText.regular(fontSize: 13, color: _grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: _grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: AppText.regular(fontSize: 11, color: _grey),
                      ),
                      const Spacer(),
                      if (hasReply)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.reply_rounded,
                                size: 11,
                                color: _green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Есть ответ',
                                style: AppText.semiBold(
                                  fontSize: 10,
                                  color: _green,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return 'Сегодня ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (diff.inDays == 1) return 'Вчера';
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }

  _StatusCfg _statusCfg(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return _StatusCfg(_red, 'Открыто');
      case 'in_progress':
        return _StatusCfg(const Color(0xFFE67E22), 'В работе');
      case 'resolved':
      case 'closed':
        return _StatusCfg(_green, 'Закрыто');
      default:
        return _StatusCfg(const Color(0xFF9AA3AF), status);
    }
  }
}

class _StatusCfg {
  final Color color;
  final String label;
  const _StatusCfg(this.color, this.label);
}

// ═════════════════════════════════════════════════════════════════════════════
// Create appeal sheet
// ═════════════════════════════════════════════════════════════════════════════

class _CreateAppealSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateAppealSheet({required this.onCreated});

  @override
  State<_CreateAppealSheet> createState() => _CreateAppealSheetState();
}

class _CreateAppealSheetState extends State<_CreateAppealSheet> {
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);
  static const _gradient = LinearGradient(colors: [_green, _red]);

  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Subject presets
  static const _presets = [
    'Проблема с заказом',
    'Вопрос по балансу',
    'Техническая ошибка',
    'Другое',
  ];
  String? _selectedPreset;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      await ApiClient().dio.post(
        '/items/appeals',
        data: {
          'user_id': int.tryParse(auth.userId) ?? auth.userId,
          'subject': _subjectCtrl.text.trim(),
          'body': _bodyCtrl.text.trim(),
          'status': 'open',
        },
      );
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0F3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              ShaderMask(
                shaderCallback: (b) => _gradient.createShader(b),
                child: Text(
                  'Новое обращение',
                  style: AppText.extraBold(fontSize: 20, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Опишите вашу проблему — мы ответим',
                style: AppText.regular(fontSize: 13, color: _grey),
              ),
              const SizedBox(height: 20),

              // Subject presets
              Text(
                'ТЕМА',
                style: AppText.semiBold(
                  fontSize: 10,
                  color: _grey,
                ).copyWith(letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((p) {
                  final sel = _selectedPreset == p;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPreset = p;
                        _subjectCtrl.text = p;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: sel ? _gradient : null,
                        color: sel ? null : const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(20),
                        border: sel
                            ? null
                            : Border.all(color: const Color(0xFFEEF0F3)),
                      ),
                      child: Text(
                        p,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : const Color(0xFF0F1117),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Custom subject
              TextFormField(
                controller: _subjectCtrl,
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                ),
                decoration: _inputDeco(
                  hint: 'Или напишите свою тему',
                  icon: Icons.edit_outlined,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Укажите тему' : null,
              ),
              const SizedBox(height: 12),

              // Body
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 4,
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                ),
                decoration: _inputDeco(
                  hint: 'Подробно опишите проблему...',
                  icon: Icons.description_outlined,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Опишите проблему' : null,
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isLoading ? null : _gradient,
                    color: _isLoading ? const Color(0xFFEEF0F3) : null,
                    borderRadius: BorderRadius.circular(14),
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
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: _green,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'ОТПРАВИТЬ',
                            style: AppText.bold(
                              fontSize: 14,
                              color: Colors.white,
                            ).copyWith(letterSpacing: 0.5),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.regular(fontSize: 13, color: const Color(0xFF9AA3AF)),
      prefixIcon: Icon(icon, color: const Color(0xFF9AA3AF), size: 18),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEEF0F3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF1A7A3C).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Appeal detail sheet
// ═════════════════════════════════════════════════════════════════════════════

class _AppealDetailSheet extends StatelessWidget {
  final dynamic appeal;
  const _AppealDetailSheet({required this.appeal});

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);
  static const _gradient = LinearGradient(colors: [_green, _red]);

  @override
  Widget build(BuildContext context) {
    final String subject = (appeal['subject'] ?? 'Без темы').toString();
    final String body = (appeal['body'] ?? '').toString();
    final String reply = (appeal['reply'] ?? '').toString();
    final String status = (appeal['status'] ?? 'open').toString();
    final String date = _formatDate(appeal['date_created']);
    final bool hasReply = reply.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0F3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Subject + status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: AppText.bold(
                      fontSize: 17,
                      color: const Color(0xFF0F1117),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 4),
            Text(date, style: AppText.regular(fontSize: 12, color: _grey)),
            const SizedBox(height: 16),

            // Gradient divider
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: _gradient,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 16),

            // Your message
            _sectionLabel('ВАШ ЗАПРОС'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEF0F3)),
              ),
              child: Text(
                body,
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                ).copyWith(height: 1.5),
              ),
            ),

            if (hasReply) ...[
              const SizedBox(height: 20),
              _sectionLabel('ОТВЕТ ПОДДЕРЖКИ'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: _gradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reply,
                        style: AppText.regular(
                          fontSize: 14,
                          color: const Color(0xFF0F1117),
                        ).copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE67E22).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFFE67E22),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ожидайте ответа поддержки',
                      style: AppText.medium(
                        fontSize: 13,
                        color: const Color(0xFFE67E22),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEEF0F3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Закрыть',
                  style: AppText.medium(fontSize: 14, color: _grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: Color(0xFF9AA3AF),
      letterSpacing: 0.8,
    ),
  );

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'open':
        color = _red;
        label = 'Открыто';
        break;
      case 'in_progress':
        color = const Color(0xFFE67E22);
        label = 'В работе';
        break;
      case 'resolved':
      case 'closed':
        color = _green;
        label = 'Закрыто';
        break;
      default:
        color = _grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
