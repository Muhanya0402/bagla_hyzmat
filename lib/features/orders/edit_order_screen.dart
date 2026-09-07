import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/auth_provider.dart';
import 'package:bagla/features/auth/auth_repository.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/core/widgets/photo_picker_sheet.dart';
import 'package:bagla/core/image_compression.dart';
import 'package:bagla/core/image_picker_presets.dart';
import 'package:bagla/l10n/app_localizations.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:bagla/models/district.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Правка уже опубликованного заказа магазином.
///
/// Меняются суммы, адрес, время, комментарий и фотографии. Отправляем только
/// то, что заказчик действительно тронул: флоу на сервере смотрит, какие поля
/// пришли, и именно их перечисляет курьеру в уведомлении. Отправь мы всё
/// подряд — курьер получал бы «изменился адрес» после правки одной цифры.
///
/// Фотографии не показываем у кафе и ресторанов: там нечего снимать, в
/// создании заказа их по той же причине не спрашивают.
class EditOrderScreen extends StatefulWidget {
  final OrderDto dto;

  const EditOrderScreen({super.key, required this.dto});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  final _service = OrderService();
  final _authRepo = AuthRepository();

  late final TextEditingController _itemCtrl;
  late final TextEditingController _deliveryCtrl;
  late final TextEditingController _commentCtrl;

  // ── Исходные значения: по ним понимаем, что человек тронул ──────────────
  late final double _origItem;
  late final double _origDelivery;
  late final String _origComment;
  DateTime? _origTime;
  late final List<String> _origFileIds;

  DateTime? _time;
  District? _district;
  List<String> _fileIds = [];
  final List<File> _newImages = [];

  List<District> _districts = const [];
  bool _loadingDistricts = false;
  bool _saving = false;
  bool _failed = false;

  /// У кафе и ресторанов фотографий у заказа нет и не должно быть.
  bool get _photosAllowed => widget.dto.category != 'cafe';

  @override
  void initState() {
    super.initState();
    final d = widget.dto;
    _origDelivery = d.deliveryAmount;
    _origItem = d.totalAmount - d.deliveryAmount;
    _origComment = d.comment;

    _itemCtrl = TextEditingController(text: _origItem.toStringAsFixed(0));
    _deliveryCtrl =
        TextEditingController(text: _origDelivery.toStringAsFixed(0));
    _commentCtrl = TextEditingController(text: _origComment);

    final raw = d.timeOfDelivery;
    _origTime = (raw == null || raw.isEmpty)
        ? null
        : DateTime.tryParse(raw)?.toLocal();
    _time = _origTime;

    _origFileIds = _extractFileIds(d.pictures);
    _fileIds = List<String>.from(_origFileIds);

    if (_photosAllowed) {
      // Ничего не грузим заранее: районы нужны, только если человек полезет
      // менять адрес.
    }
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _deliveryCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  static List<String> _extractFileIds(List<dynamic> pictures) {
    final out = <String>[];
    for (final p in pictures) {
      if (p is Map) {
        final id = p['directus_files_id'];
        if (id is String && id.isNotEmpty) out.add(id);
      }
    }
    return out;
  }

  double get _item => double.tryParse(_itemCtrl.text.trim()) ?? 0;
  double get _delivery => double.tryParse(_deliveryCtrl.text.trim()) ?? 0;

  bool get _amountsChanged =>
      _item != _origItem || _delivery != _origDelivery;
  bool get _commentChanged => _commentCtrl.text.trim() != _origComment.trim();
  bool get _timeChanged => _time != _origTime;
  bool get _addressChanged => _district != null;
  bool get _photosChanged =>
      _newImages.isNotEmpty ||
      _fileIds.length != _origFileIds.length ||
      !_fileIds.every(_origFileIds.contains);

  bool get _dirty =>
      _amountsChanged ||
      _commentChanged ||
      _timeChanged ||
      _addressChanged ||
      (_photosAllowed && _photosChanged);

  bool get _canSave {
    if (_saving || !_dirty) return false;
    if (_itemCtrl.text.trim().isEmpty || _deliveryCtrl.text.trim().isEmpty) {
      return false;
    }
    return _delivery > 0;
  }

  Future<void> _loadDistricts() async {
    if (_districts.isNotEmpty || _loadingDistricts) return;
    setState(() => _loadingDistricts = true);
    try {
      final provinceId = context.read<AuthProvider>().provinceId;
      final list = await _authRepo.getDistrictsByProvince(provinceId);
      if (mounted) setState(() => _districts = list);
    } catch (_) {
      // Молчим: шторка покажет пустой список, и это видно без слов.
    } finally {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _pickDistrict(AppLocalizations words, bool isRu) async {
    await _loadDistricts();
    if (!mounted) return;
    final picked = await showModalBottomSheet<District>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DistrictSheet(
        districts: _districts,
        isRu: isRu,
        words: words,
      ),
    );
    if (picked != null && mounted) setState(() => _district = picked);
  }

  Future<void> _pickTime(AppLocalizations words) async {
    final now = DateTime.now();
    final base = _time ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    setState(() {
      _time = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _addPhotos() async {
    final remaining = 3 - (_fileIds.length + _newImages.length);
    if (remaining <= 0) return;
    final files = await PhotoPickerSheet.show(context, maxAssets: remaining);
    if (files.isEmpty || !mounted) return;
    // Сжимаем так же, как при создании заказа: иначе правка фотографий
    // отправляла бы на сервер оригиналы с камеры.
    final compressed = await Future.wait(
      files.map((f) => ImageCompression.compress(f, ImagePresets.orderItem)),
    );
    if (!mounted) return;
    setState(() => _newImages.addAll(compressed.take(remaining)));
  }

  Future<void> _save(AppLocalizations words) async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _failed = false;
    });

    final d = _district;
    final ok = await _service.updateOrder(
      orderId: widget.dto.id,
      // Суммы отправляем парой и только если их трогали.
      itemPrice: _amountsChanged ? _item : null,
      deliveryFee: _amountsChanged ? _delivery : null,
      address: d == null
          ? null
          : (d.etrapRu.isNotEmpty ? '${d.etrapRu} - ${d.ru}' : d.ru),
      addressTk: d == null
          ? null
          : (d.etrapTk.isNotEmpty ? '${d.etrapTk} - ${d.tk}' : d.tk),
      districtId: d?.id,
      etrapId: d != null && d.etrapId.isNotEmpty ? d.etrapId : null,
      comment: _commentChanged ? _commentCtrl.text.trim() : null,
      deliveryTime: _timeChanged ? _time : null,
      keepFileIds: (_photosAllowed && _photosChanged) ? _fileIds : null,
      newImages: (_photosAllowed && _photosChanged) ? _newImages : null,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = !ok;
    });
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final isRu = lang.isRu;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child:
                Icon(Icons.arrow_back_ios_new_rounded, color: c.ink, size: 16),
          ),
        ),
        title: Text(
          words.editOrderTitle,
          style: AppText.serif(fontSize: 20, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: c.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (widget.dto.courierId.isNotEmpty) ...[
            _Notice(text: words.editOrderCourierNotice),
            const SizedBox(height: 12),
          ],

          // ── Стоимость ──────────────────────────────────────────────────
          _Section(title: words.priceSection, children: [
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(words.orderTotal,
                    style: AppText.medium(fontSize: 13.5, color: c.inkMuted)),
                Text(
                  '${(_item + _delivery).toStringAsFixed(0)} TMT',
                  style: AppText.semiBold(fontSize: 17, color: c.ink),
                ),
              ],
            ),
          ]),

          // ── Адрес ──────────────────────────────────────────────────────
          _Section(title: words.orderDeliveryArea, children: [
            _PickerRow(
              icon: Icons.location_on_outlined,
              value: _district != null
                  ? (isRu
                      ? (_district!.etrapRu.isNotEmpty
                          ? '${_district!.etrapRu} - ${_district!.ru}'
                          : _district!.ru)
                      : (_district!.etrapTk.isNotEmpty
                          ? '${_district!.etrapTk} - ${_district!.tk}'
                          : _district!.tk))
                  : widget.dto.deliveryAddress(isRu),
              changed: _addressChanged,
              busy: _loadingDistricts,
              onTap: () => _pickDistrict(words, isRu),
            ),
          ]),

          // ── Время ──────────────────────────────────────────────────────
          _Section(title: words.editOrderTimeSection, children: [
            _PickerRow(
              icon: Icons.schedule_outlined,
              value: _time == null
                  ? words.editOrderTimeNotSet
                  : _formatTime(_time!),
              changed: _timeChanged,
              onTap: () => _pickTime(words),
            ),
          ]),

          // ── Комментарий ────────────────────────────────────────────────
          _Section(title: words.commentSection, children: [
            TextField(
              controller: _commentCtrl,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(300)],
              onChanged: (_) => setState(() {}),
              style: AppText.regular(fontSize: 15, color: c.ink),
              decoration: _decor(c, words.orderCommentHint,
                  Icons.notes_rounded),
            ),
          ]),

          // ── Фотографии ─────────────────────────────────────────────────
          if (_photosAllowed)
            _Section(title: words.orderPhoto, children: [
              _PhotoStrip(
                fileIds: _fileIds,
                newImages: _newImages,
                onRemoveExisting: (id) =>
                    setState(() => _fileIds.remove(id)),
                onRemoveNew: (x) => setState(() => _newImages.remove(x)),
                onAdd: _addPhotos,
              ),
            ]),

          const SizedBox(height: 8),
          if (_failed) ...[
            Text(
              words.editOrderFailed,
              style: AppText.regular(fontSize: 12.5, color: c.errorMuted)
                  .copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
          ],

          // ── Сохранить ──────────────────────────────────────────────────
          GestureDetector(
            onTap: _canSave ? () => _save(words) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 50,
              decoration: BoxDecoration(
                color: _canSave ? c.ink : c.borderSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _canSave ? c.ink : c.border),
              ),
              alignment: Alignment.center,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.surface,
                      ),
                    )
                  : Text(
                      words.editOrderSave,
                      style: AppText.semiBold(
                        fontSize: 14.5,
                        color: _canSave ? c.surface : c.inkSoft,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(t.day)}.${p(t.month)} ${p(t.hour)}:${p(t.minute)}';
  }

  InputDecoration _decor(AppColors c, String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: AppText.regular(fontSize: 14, color: c.inkSoft),
        prefixIcon: Icon(icon, color: c.ink, size: 18),
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
      );
}

// ─── Кусочки формы ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title,
              style: AppText.semiBold(fontSize: 13, color: c.inkMuted),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.emeraldTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: c.ink),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppText.regular(fontSize: 12.5, color: c.inkMuted)
                  .copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

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

/// Строка «текущее значение + переход к выбору». Помечается, когда значение
/// изменили: иначе на длинной форме не видно, что уже тронуто.
class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool changed;
  final bool busy;
  final VoidCallback onTap;

  const _PickerRow({
    required this.icon,
    required this.value,
    required this.changed,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: AppText.medium(fontSize: 14, color: c.ink),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (changed) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c.amber, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          if (busy)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Icon(Icons.chevron_right_rounded, size: 20, color: c.inkSoft),
        ],
      ),
    );
  }
}

/// Полоса фотографий: уже загруженные и только что выбранные, вперемешку,
/// с крестиком на каждой и плиткой добавления в конце.
class _PhotoStrip extends StatelessWidget {
  final List<String> fileIds;
  final List<File> newImages;
  final void Function(String) onRemoveExisting;
  final void Function(File) onRemoveNew;
  final VoidCallback onAdd;

  const _PhotoStrip({
    required this.fileIds,
    required this.newImages,
    required this.onRemoveExisting,
    required this.onRemoveNew,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final total = fileIds.length + newImages.length;

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final id in fileIds)
            _Thumb(
              image: Image.network(
                '${BaseUrl.url}/assets/$id?width=200&quality=70',
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(color: c.borderSoft),
              ),
              onRemove: () => onRemoveExisting(id),
            ),
          for (final x in newImages)
            _Thumb(
              image: Image.file(
                x,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 84,
                  height: 84,
                  color: c.borderSoft,
                  child: Icon(Icons.image_outlined, color: c.inkSoft),
                ),
              ),
              onRemove: () => onRemoveNew(x),
            ),
          if (total < 3)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: c.borderSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Icon(Icons.add_rounded, color: c.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Widget image;
  final VoidCallback onRemove;
  const _Thumb({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: image),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border),
                ),
                child: Icon(Icons.close_rounded, size: 13, color: c.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Шторка выбора района с поиском.
class _DistrictSheet extends StatefulWidget {
  final List<District> districts;
  final bool isRu;
  final AppLocalizations words;

  const _DistrictSheet({
    required this.districts,
    required this.isRu,
    required this.words,
  });

  @override
  State<_DistrictSheet> createState() => _DistrictSheetState();
}

class _DistrictSheetState extends State<_DistrictSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _label(District d) => widget.isRu
      ? (d.etrapRu.isNotEmpty ? '${d.etrapRu} - ${d.ru}' : d.ru)
      : (d.etrapTk.isNotEmpty ? '${d.etrapTk} - ${d.tk}' : d.tk);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final q = _search.text.trim().toLowerCase();
    final items = q.isEmpty
        ? widget.districts
        : widget.districts
            .where((d) => _label(d).toLowerCase().contains(q))
            .toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          children: [
            Text(
              widget.words.editOrderPickDistrict,
              style: AppText.serif(fontSize: 17, color: c.ink),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: AppText.regular(fontSize: 15, color: c.ink),
              decoration: InputDecoration(
                hintText: widget.words.searchDistrict,
                hintStyle: AppText.regular(fontSize: 14, color: c.inkSoft),
                prefixIcon: Icon(Icons.search_rounded, color: c.inkSoft,
                    size: 18),
                filled: true,
                fillColor: c.borderSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        widget.words.noData,
                        style:
                            AppText.regular(fontSize: 13, color: c.inkSoft),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          Container(height: 0.5, color: c.borderSoft),
                      itemBuilder: (_, i) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(context, items[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Text(
                            _label(items[i]),
                            style:
                                AppText.regular(fontSize: 14.5, color: c.ink),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
