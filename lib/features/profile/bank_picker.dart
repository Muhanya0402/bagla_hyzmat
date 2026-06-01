import 'package:bagla/core/api_client.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class BankOption {
  final String id;
  final String nameRu;
  final String nameTk;
  final String? logoFileId;
  final String? primaryColor;
  final bool isActive;

  const BankOption({
    required this.id,
    required this.nameRu,
    required this.nameTk,
    this.logoFileId,
    this.primaryColor,
    this.isActive = true,
  });

  factory BankOption.fromJson(Map<String, dynamic> j) {
    String? logoId;
    final raw = j['logo'];
    if (raw is String) {
      logoId = raw;
    } else if (raw is Map) {
      logoId = raw['id']?.toString();
    }
    return BankOption(
      id: j['id'].toString(),
      nameRu: j['name_ru'] ?? '',
      nameTk: j['name_tk'] ?? '',
      logoFileId: logoId,
      primaryColor: j['primary_color']?.toString(),
      isActive: j['is_active'] ?? true,
    );
  }

  /// Бренд-цвет банка (опц.). Используется ТОЛЬКО как маленький акцент
  /// в fallback-иконке (когда нет логотипа). На основной UI карточки
  /// не влияет — общий дизайн остаётся нейтральным.
  /// Возвращает `null` если поле пустое/невалидное — вызывающий код
  /// сам подставит нейтральный fallback из AppColors.
  Color? get brandColor {
    if (primaryColor == null) return null;
    try {
      final hex = primaryColor!.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class BankService {
  final ApiClient _api = ApiClient();

  Future<List<BankOption>> getBanks() async {
    try {
      final res = await _api.dio.get(
        '/items/banks',
        queryParameters: {
          'filter[is_active][_eq]': true,
          'sort': 'sort_order',
          'fields': 'id,name_ru,name_tk,primary_color,is_active,logo.id',
        },
      );
      final List data = res.data['data'] as List;
      return data.map((e) => BankOption.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BankPickerSection
// ─────────────────────────────────────────────────────────────────────────────

class BankPickerSection extends StatefulWidget {
  final bool isRu;
  final BankOption? selected;
  final ValueChanged<BankOption> onSelected;

  const BankPickerSection({
    super.key,
    required this.isRu,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<BankPickerSection> createState() => _BankPickerSectionState();
}

class _BankPickerSectionState extends State<BankPickerSection> {
  final BankService _service = BankService();
  late Future<List<BankOption>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getBanks();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final words = context.watch<LanguageProvider>().words;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                words.bankPickerTitle,
                style: AppText.semiBold(
                  fontSize: 10,
                  color: c.inkSoft,
                ).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
        ),

        FutureBuilder<List<BankOption>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, _) => _BankSkeleton(),
                ),
              );
            }

            final banks = snap.data ?? [];

            if (banks.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: c.inkSoft, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      words.bankPickerEmpty,
                      style: AppText.regular(fontSize: 13, color: c.inkSoft),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: banks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final bank = banks[i];
                  return _BankCard(
                    bank: bank,
                    isSelected: widget.selected?.id == bank.id,
                    isRu: widget.isRu,
                    onTap: () => widget.onSelected(bank),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single bank card
// ─────────────────────────────────────────────────────────────────────────────

class _BankCard extends StatelessWidget {
  final BankOption bank;
  final bool isSelected;
  final bool isRu;
  final VoidCallback onTap;

  static const _baseUrl = BaseUrl.url;

  const _BankCard({
    required this.bank,
    required this.isSelected,
    required this.isRu,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final name = isRu ? bank.nameRu : bank.nameTk;
    // Бренд-цвет используется только в fallback-иконке (когда нет логотипа).
    // По умолчанию — нейтральный c.ink, чтобы не выбиваться из палитры UI.
    final accent = bank.brandColor ?? c.ink;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? c.emeraldTint : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? c.ink.withValues(alpha: 0.35)
                : c.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(c, accent),
            const SizedBox(height: 6),
            Text(
              name,
              style: AppText.semiBold(
                fontSize: 11,
                color: c.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(AppColors c, Color accent) {
    if (bank.logoFileId == null || bank.logoFileId!.isEmpty) {
      return _fallbackIcon(c, accent);
    }

    final url = '$_baseUrl/assets/${bank.logoFileId}';

    return SizedBox(
      width: 60,
      height: 32,
      child: Image.network(
        url,
        width: 60,
        height: 32,
        fit: BoxFit.contain,
        cacheWidth: 120,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: c.inkSoft,
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _fallbackIcon(c, accent),
      ),
    );
  }

  /// Fallback когда нет логотипа: плитка с иконкой банка.
  /// Здесь — единственное место где используется `bank.brandColor`,
  /// и только если он задан; иначе нейтральный c.ink.
  Widget _fallbackIcon(AppColors c, Color accent) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(Icons.account_balance_rounded, color: accent, size: 18),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loader
// ─────────────────────────────────────────────────────────────────────────────

class _BankSkeleton extends StatelessWidget {
  const _BankSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 100,
      height: 82,
      decoration: BoxDecoration(
        color: c.borderSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
    );
  }
}
