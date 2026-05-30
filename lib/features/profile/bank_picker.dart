import 'package:bagla/core/api_client.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand constants — intentional accent colours, not adapted to theme.
// ─────────────────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF1A7A3C);
const _kRed = Color(0xFFD32F1E);
const _kGradient = LinearGradient(colors: [_kGreen, _kRed]);

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

  Color get color {
    if (primaryColor == null) return _kGreen;
    try {
      final hex = primaryColor!.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return _kGreen;
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
                  gradient: _kGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isRu ? 'ВЫБЕРИТЕ БАНК' : 'BANK SAÝLAŇ',
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
                      widget.isRu ? 'Банки недоступны' : 'Banklar ýok',
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
    final color = bank.color;
    final name = isRu ? bank.nameRu : bank.nameTk;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : c.border,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(color),
            const SizedBox(height: 6),
            Text(
              name,
              style: AppText.semiBold(
                fontSize: 11,
                color: isSelected ? color : c.ink,
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

  Widget _buildLogo(Color color) {
    if (bank.logoFileId == null || bank.logoFileId!.isEmpty) {
      return _fallbackIcon(color);
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
                color: color.withValues(alpha: 0.4),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _fallbackIcon(color),
      ),
    );
  }

  Widget _fallbackIcon(Color color) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(Icons.account_balance_rounded, color: color, size: 18),
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
