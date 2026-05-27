import 'package:flutter/material.dart';

class AuthColors {
  // Brand colors (kept for gradient compat)
  static const Color green = Color(0xFF1A7A3C);
  static const Color red = Color(0xFFD32F1E);

  // Anthropic-inspired palette (Claude.ai)
  static const Color bg = Color(0xFFFBF9F6); // warm ivory paper
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF191919); // deep charcoal
  static const Color inkMuted = Color(0xFF6B6B6B);
  static const Color inkSoft = Color(0xFF9A958D); // for placeholders/tertiary
  static const Color accent = Color(0xFFCC785C); // signature terracotta
  static const Color border = Color(0xFFE7E2D8);
  static const Color borderSoft = Color(0xFFEFEAE0);

  // ── Error / warning (muted terracotta — no harsh neon red) ─────────────
  static const Color errorMuted = Color(
    0xFFC85A53,
  ); // border / icon / text accent
  static const Color errorTint = Color(0xFFF9F1EF); // soft pink-beige bg
  static const Color bannerBg = Color(0xFFF1ECE3); // gray-beige toast bg
  static const Color bannerBorder = Color(0xFFD8D2C5);

  // ── Onboarding accents (noble, restrained) ─────────────────────────────
  static const Color emerald = Color(0xFF2D5A27); // noble dark green
  static const Color emeraldTint = Color(0xFFE9EFE5); // soft sage bg
  static const Color amber = Color(0xFFD4AF37); // archival amber/brass
  static const Color amberTint = Color(0xFFF7F0DB); // soft sand bg

  static const LinearGradient gradient = LinearGradient(
    colors: [green, red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
