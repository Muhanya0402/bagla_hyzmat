import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/pressable_scale.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/profile/support_repository.dart';
import 'package:bagla/features/profile/utils/phone_launcher.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SupportModal extends StatefulWidget {
  final String phone;
  const SupportModal({super.key, required this.phone});

  @override
  State<SupportModal> createState() => _SupportModalState();
}

class _SupportModalState extends State<SupportModal> {
  final SupportRepository _repo = SupportRepository();
  String? _category;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<String> _categories(AppLocalizations w) => [
        w.supportCatOrder,
        w.supportCatTokens,
        w.supportCatBug,
        w.supportCatIdea,
      ];

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      _focus.requestFocus();
      return;
    }
    final c = AppColors.of(context);
    final words = context.read<LanguageProvider>().words;
    final auth = context.read<AuthProvider>();

    setState(() => _isLoading = true);
    try {
      await _repo.sendAppeal(
        userId: auth.userId,
        subject: _category ?? words.supportDefaultSubject,
        body: text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            words.supportSent,
            style: AppText.medium(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: c.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            words.supportSendError,
            style: AppText.medium(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: c.errorMuted,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          bottomInset > 0 ? bottomInset + 16 : bottomPadding + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(topPadding: 0),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.emeraldTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.headset_mic_outlined,
                    color: c.ink,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        words.supportTitle,
                        style: AppText.serif(fontSize: 17, color: c.ink),
                      ),
                      Text(
                        words.supportSubtitle,
                        style:
                            AppText.regular(fontSize: 11, color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category tags
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _categories(words).map((cat) {
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = sel ? null : cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? c.emeraldTint : c.borderSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? c.ink.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: AppText.medium(
                        fontSize: 12,
                        color: sel ? c.ink : c.inkMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Message field
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              maxLines: 4,
              minLines: 3,
              textInputAction: TextInputAction.newline,
              style: AppText.regular(fontSize: 14, color: c.ink),
              decoration: InputDecoration(
                hintText: words.supportHint,
                hintStyle: AppText.regular(fontSize: 14, color: c.inkSoft),
                filled: true,
                fillColor: c.bg,
                contentPadding: const EdgeInsets.all(12),
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
                  borderSide: BorderSide(color: c.ink, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                GestureDetector(
                  onTap: () => launchPhoneCall(widget.phone),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.borderSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.call_outlined,
                      color: c.inkMuted,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SendButton(
                    isLoading: _isLoading,
                    onTap: _submit,
                    label: words.supportSend,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final String label;

  const _SendButton({
    required this.isLoading,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PressableScale(
      onTap: isLoading ? null : onTap,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 46,
        decoration: BoxDecoration(
          color: isLoading ? c.ink.withValues(alpha: 0.5) : c.ink,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.send_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style:
                        AppText.semiBold(fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }
}
