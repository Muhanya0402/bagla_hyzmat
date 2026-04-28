import 'package:flutter/material.dart';

class AppText {
  AppText._();

  static const String _font = 'Nunito';

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
