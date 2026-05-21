import 'package:flutter/material.dart';

class AuthColors {
  static const Color green = Color(0xFF1A7A3C);
  static const Color red = Color(0xFFD32F1E);

  static const LinearGradient gradient = LinearGradient(
    colors: [green, red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
