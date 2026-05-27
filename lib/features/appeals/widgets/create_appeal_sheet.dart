import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/api_client.dart';
import 'package:bagla/features/auth/auth_constants.dart';
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
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedPreset;
  final FocusNode _subjectFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _subjectFocus.dispose();
    _bodyFocus.dispose();
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
        final words = context.read<LanguageProvider>().words;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${words.error}: $e'),
            backgroundColor: AuthColors.errorMuted,
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
          color: AuthColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ─────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AuthColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Title ───────────────────────────────────────────────────
              Text(
                words.appealsCreateTitle,
                style: AppText.serif(fontSize: 20, letterSpacing: -0.3),
              ),
              const SizedBox(height: 3),
              Text(
                words.appealsCreateSubtitle,
                style: AppText.regular(
                  fontSize: 13,
                  color: AuthColors.inkMuted,
                ),
              ),
              const SizedBox(height: 18),

              // ── Topic presets ───────────────────────────────────────────
              Text(
                words.appealsTopicLabel,
                style: AppText.semiBold(
                  fontSize: 10,
                  color: AuthColors.inkSoft,
                ).copyWith(letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
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
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? AuthColors.ink : AuthColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AuthColors.ink : AuthColors.border,
                        ),
                      ),
                      child: Text(
                        p,
                        style: AppText.semiBold(
                          fontSize: 12,
                          color: sel ? Colors.white : AuthColors.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // ── Subject field ───────────────────────────────────────────
              TextFormField(
                controller: _subjectCtrl,
                focusNode: _subjectFocus,
                style: AppText.regular(fontSize: 14, color: AuthColors.ink),
                decoration: _inputDeco(
                  hint: words.appealsTopicHint,
                  icon: Icons.edit_outlined,
                  focused: _subjectFocus.hasFocus,
                ),
                onTap: () => setState(() {}),
                onEditingComplete: () {
                  setState(() {});
                  FocusScope.of(context).requestFocus(_bodyFocus);
                },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? words.appealsTopicRequired
                    : null,
              ),
              const SizedBox(height: 10),

              // ── Body field ──────────────────────────────────────────────
              TextFormField(
                controller: _bodyCtrl,
                focusNode: _bodyFocus,
                maxLines: 4,
                style: AppText.regular(fontSize: 14, color: AuthColors.ink),
                decoration: _inputDeco(
                  hint: words.appealsBodyHint,
                  icon: Icons.description_outlined,
                  focused: _bodyFocus.hasFocus,
                ),
                onTap: () => setState(() {}),
                onEditingComplete: () => setState(() {}),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? words.appealsBodyRequired
                    : null,
              ),
              const SizedBox(height: 18),

              // ── Submit button ───────────────────────────────────────────
              _SubmitButton(
                isLoading: _isLoading,
                label: words.appealsSend,
                onTap: _isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    required bool focused,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.regular(fontSize: 13, color: AuthColors.inkSoft),
      prefixIcon: Icon(
        icon,
        color: focused ? AuthColors.emerald : AuthColors.inkSoft,
        size: 17,
      ),
      filled: true,
      fillColor: AuthColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.emerald.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.errorMuted.withValues(alpha: 0.5),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AuthColors.errorMuted,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
    );
  }
}

// ── Submit button ─────────────────────────────────────────────────────────────

class _SubmitButton extends StatefulWidget {
  final bool isLoading;
  final String label;
  final VoidCallback? onTap;

  const _SubmitButton({
    required this.isLoading,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
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
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: widget.isLoading ? AuthColors.borderSoft : AuthColors.ink,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AuthColors.inkSoft,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  widget.label,
                  style: AppText.semiBold(
                    fontSize: 14,
                    color: Colors.white,
                  ).copyWith(letterSpacing: 0.5),
                ),
        ),
      ),
    );
  }
}
