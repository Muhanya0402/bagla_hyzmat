import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.inkSoft,
    required this.accent,
    required this.border,
    required this.borderSoft,
    required this.emerald,
    required this.emeraldTint,
    required this.amber,
    required this.amberTint,
    required this.errorMuted,
    required this.errorTint,
    required this.bannerBg,
    required this.bannerBorder,
  });

  final Color bg;
  final Color surface;
  final Color ink;
  final Color inkMuted;
  final Color inkSoft;
  final Color accent;
  final Color border;
  final Color borderSoft;
  final Color emerald;
  final Color emeraldTint;
  final Color amber;
  final Color amberTint;
  final Color errorMuted;
  final Color errorTint;
  final Color bannerBg;
  final Color bannerBorder;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  // ── Светлая палитра (зеркало AuthColors) ──────────────────────────────────
  static const light = AppColors(
    bg: Color(0xFFFBF9F6),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF191919),
    inkMuted: Color(0xFF6B6B6B),
    inkSoft: Color(0xFF9A958D),
    accent: Color(0xFFCC785C),
    border: Color(0xFFE7E2D8),
    borderSoft: Color(0xFFEFEAE0),
    emerald: Color(0xFF2D5A27),
    emeraldTint: Color(0xFFE9EFE5),
    amber: Color(0xFFD4AF37),
    amberTint: Color(0xFFF7F0DB),
    errorMuted: Color(0xFFC85A53),
    errorTint: Color(0xFFF9F1EF),
    bannerBg: Color(0xFFF1ECE3),
    bannerBorder: Color(0xFFD8D2C5),
  );

  // ── Тёмная палитра: графит + тёплые бумажные тона ────────────────────────
  static const dark = AppColors(
    bg: Color(0xFF121212),
    surface: Color(0xFF1C1C1E),
    ink: Color(0xFFCC785C),
    inkMuted: Color(0xFF8E8882),
    inkSoft: Color(0xFF5C5852),
    accent: Color(0xFFD4876A),
    border: Color(0xFF2C2826),
    borderSoft: Color(0xFF222020),
    emerald: Color(0xFF4A8C3F),
    emeraldTint: Color(0xFF0F1F0D),
    amber: Color(0xFFE0C44A),
    amberTint: Color(0xFF211C08),
    errorMuted: Color(0xFFD97570),
    errorTint: Color(0xFF2A1210),
    bannerBg: Color(0xFF1E1C1A),
    bannerBorder: Color(0xFF3A3530),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? inkMuted,
    Color? inkSoft,
    Color? accent,
    Color? border,
    Color? borderSoft,
    Color? emerald,
    Color? emeraldTint,
    Color? amber,
    Color? amberTint,
    Color? errorMuted,
    Color? errorTint,
    Color? bannerBg,
    Color? bannerBorder,
  }) => AppColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    inkSoft: inkSoft ?? this.inkSoft,
    accent: accent ?? this.accent,
    border: border ?? this.border,
    borderSoft: borderSoft ?? this.borderSoft,
    emerald: emerald ?? this.emerald,
    emeraldTint: emeraldTint ?? this.emeraldTint,
    amber: amber ?? this.amber,
    amberTint: amberTint ?? this.amberTint,
    errorMuted: errorMuted ?? this.errorMuted,
    errorTint: errorTint ?? this.errorTint,
    bannerBg: bannerBg ?? this.bannerBg,
    bannerBorder: bannerBorder ?? this.bannerBorder,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      emeraldTint: Color.lerp(emeraldTint, other.emeraldTint, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberTint: Color.lerp(amberTint, other.amberTint, t)!,
      errorMuted: Color.lerp(errorMuted, other.errorMuted, t)!,
      errorTint: Color.lerp(errorTint, other.errorTint, t)!,
      bannerBg: Color.lerp(bannerBg, other.bannerBg, t)!,
      bannerBorder: Color.lerp(bannerBorder, other.bannerBorder, t)!,
    );
  }
}
