import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/widgets/sheet_handle.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Шторка «Изменить сумму заказа» для магазина.
///
/// Правятся две суммы — товар и доставка; итог считается сам и показан крупно,
/// чтобы заказчик видел, что уйдёт курьеру, до нажатия кнопки.
///
/// Кнопка подтверждения остаётся выключенной, пока суммы не изменились: без
/// этого магазин мог «сохранить» то же самое и без нужды дёрнуть курьера
/// пушем об изменении.
class EditAmountModal extends StatefulWidget {
  final AppLocalizations words;

  /// Текущие суммы заказа.
  final double itemPrice;
  final double deliveryFee;

  /// Курьер уже взял заказ — предупреждаем, что он получит уведомление.
  final bool courierAssigned;

  /// Возвращает `true`, если шторку нужно закрыть.
  final Future<bool> Function(double itemPrice, double deliveryFee) onSubmit;

  const EditAmountModal({
    super.key,
    required this.words,
    required this.itemPrice,
    required this.deliveryFee,
    required this.courierAssigned,
    required this.onSubmit,
  });

  @override
  State<EditAmountModal> createState() => _EditAmountModalState();
}

class _EditAmountModalState extends State<EditAmountModal> {
  late final TextEditingController _itemCtrl;
  late final TextEditingController _deliveryCtrl;
  bool _isLoading = false;

  /// Последняя попытка сохранить не удалась. Держим шторку открытой и
  /// пишем об этом здесь же: снек за шторкой пользователю не виден.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _itemCtrl = TextEditingController(
      text: widget.itemPrice.toStringAsFixed(0),
    );
    _deliveryCtrl = TextEditingController(
      text: widget.deliveryFee.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _deliveryCtrl.dispose();
    super.dispose();
  }

  double get _item => double.tryParse(_itemCtrl.text.trim()) ?? 0;
  double get _delivery => double.tryParse(_deliveryCtrl.text.trim()) ?? 0;
  double get _total => _item + _delivery;

  /// Обе суммы заполнены, доставка не нулевая и хоть что-то отличается
  /// от текущих значений.
  bool get _canSubmit {
    if (_isLoading) return false;
    if (_itemCtrl.text.trim().isEmpty || _deliveryCtrl.text.trim().isEmpty) {
      return false;
    }
    if (_delivery <= 0) return false;
    return _item != widget.itemPrice || _delivery != widget.deliveryFee;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    final ok = await widget.onSubmit(_item, _delivery);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _failed = !ok;
    });
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = widget.words;
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

            // ── Заголовок ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    words.editAmountTitle,
                    style: AppText.serif(fontSize: 17, color: c.ink),
                  ),
                ),
              ],
            ),

            // Предупреждение показываем только когда есть кого предупреждать:
            // у заказа без курьера пуш никому не уйдёт.
            if (widget.courierAssigned) ...[
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1.5),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 11,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      words.editAmountCourierNotice,
                      style: AppText.regular(fontSize: 12, color: c.inkMuted)
                          .copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),

            _AmountField(
              controller: _itemCtrl,
              label: words.itemPrice,
              icon: Icons.payments_outlined,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            _AmountField(
              controller: _deliveryCtrl,
              label: words.delivery,
              icon: Icons.delivery_dining_outlined,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ── Новый итог ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.borderSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    words.orderTotal,
                    style: AppText.medium(fontSize: 13.5, color: c.inkMuted),
                  ),
                  Text(
                    '${_total.toStringAsFixed(0)} TMT',
                    style: AppText.semiBold(fontSize: 17, color: c.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Кнопка ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: GestureDetector(
                onTap: _canSubmit ? _submit : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: _canSubmit ? c.ink : c.borderSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _canSubmit ? c.ink : c.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.surface,
                          ),
                        )
                      : Text(
                          words.editAmountSave,
                          style: AppText.semiBold(
                            fontSize: 14.5,
                            color: _canSubmit ? c.surface : c.inkSoft,
                          ),
                        ),
                ),
              ),
            ),

            if (_failed) ...[
              const SizedBox(height: 10),
              Text(
                words.editAmountFailed,
                style: AppText.regular(fontSize: 12.5, color: c.errorMuted)
                    .copyWith(height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Поле суммы ───────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onChanged;

  const _AmountField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => onChanged(),
      style: AppText.semiBold(fontSize: 16, color: c.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.regular(fontSize: 13, color: c.inkSoft),
        prefixIcon: Icon(icon, color: c.ink, size: 18),
        suffixText: 'TMT',
        suffixStyle: AppText.regular(fontSize: 13, color: c.inkSoft),
        filled: true,
        fillColor: c.borderSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: c.ink.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}
