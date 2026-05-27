import 'package:flutter/material.dart';

class AppText {
  AppText._();

  static const String _font = 'Nunito';
  static const String _serifFont = 'Lora';

  /// Editorial serif для крупных заголовков (Anthropic / Claude.ai look).
  /// Используй для display-текстов экранов авторизации, hero-заголовков,
  /// модалок. Body / UI должны оставаться на Nunito для читабельности.
  static TextStyle serif({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w500,
    Color color = const Color(0xFF191919),
    double height = 1.1,
    double letterSpacing = -0.5,
  }) => TextStyle(
    fontFamily: _serifFont,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle regular({
    double fontSize = 14,
    Color color = const Color(0xFF0F1117),
  }) => TextStyle(
    fontFamily: _font,
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle medium({
    double fontSize = 14,
    Color color = const Color(0xFF0F1117),
  }) => TextStyle(
    fontFamily: _font,
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    color: color,
  );

  static TextStyle semiBold({
    double fontSize = 14,
    Color color = const Color(0xFF0F1117),
  }) => TextStyle(
    fontFamily: _font,
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle bold({
    double fontSize = 14,
    Color color = const Color(0xFF0F1117),
  }) => TextStyle(
    fontFamily: _font,
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle extraBold({
    double fontSize = 14,
    Color color = const Color(0xFF0F1117),
  }) => TextStyle(
    fontFamily: _font,
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
    color: color,
  );

  static TextStyle display({
    double fontSize = 14,
    Color color = const Color(0xFF0F1117),
  }) => TextStyle(
    fontFamily: _font,
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
    color: color,
  );

  static TextStyle mono({
    double fontSize = 14,
    Color color = const Color(0xFF0F1117),
  }) => TextStyle(
    fontFamily: _font,
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    color: color,
  );
}
