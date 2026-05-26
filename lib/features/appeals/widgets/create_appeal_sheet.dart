import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/api_client.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CreateAppealSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const CreateAppealSheet({super.key, required this.onCreated});

  @override
  State<CreateAppealSheet> createState() => CreateAppealSheetState();
}

class CreateAppealSheetState extends State<CreateAppealSheet> {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _grey = Color(0xFF9AA3AF);
  static const _gradient = LinearGradient(colors: [_green, _red]);

  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedPreset;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

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
        final words = context.read<LanguageProvider>().words;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${words.error}: $e'),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final words = context.watch<LanguageProvider>().words;
    final presets = [
      words.appealsPreset1,
      words.appealsPreset2,
      words.appealsPreset3,
      words.appealsPreset4,
    ];

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
              // ── Handle ────────────────────────────────────────────────
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

              // ── Заголовок ─────────────────────────────────────────────
              ShaderMask(
                shaderCallback: (b) => _gradient.createShader(b),
                child: Text(
                  words.appealsCreateTitle,
                  style: AppText.extraBold(fontSize: 20, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                words.appealsCreateSubtitle,
                style: AppText.regular(fontSize: 13, color: _grey),
              ),
              const SizedBox(height: 20),

              // ── Пресеты темы ──────────────────────────────────────────
              Text(
                words.appealsTopicLabel,
                style: AppText.semiBold(
                  fontSize: 10,
                  color: _grey,
                ).copyWith(letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((p) {
                  final sel = _selectedPreset == p;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedPreset = p;
                      _subjectCtrl.text = p;
                    }),
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

              // ── Поле темы ─────────────────────────────────────────────
              TextFormField(
                controller: _subjectCtrl,
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                ),
                decoration: _inputDeco(
                  hint: words.appealsTopicHint,
                  icon: Icons.edit_outlined,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? words.appealsTopicRequired
                    : null,
              ),
              const SizedBox(height: 12),

              // ── Поле описания ─────────────────────────────────────────
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 4,
                style: AppText.regular(
                  fontSize: 14,
                  color: const Color(0xFF0F1117),
                ),
                decoration: _inputDeco(
                  hint: words.appealsBodyHint,
                  icon: Icons.description_outlined,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? words.appealsBodyRequired
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Кнопка отправить ──────────────────────────────────────
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
                            words.appealsSend,
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

  // ── Helpers ────────────────────────────────────────────────────────────────

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
          color: _green.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
