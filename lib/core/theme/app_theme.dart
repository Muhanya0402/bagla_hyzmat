import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static const _font = 'Nunito';

  static ThemeData get light => _build(
    brightness:  Brightness.light,
    scheme: const ColorScheme.light(
      primary:   Color(0xFF1B3A6B),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFFCC785C),
      surface:   Color(0xFFFFFFFF),
      onSurface: Color(0xFF191919),
      error:     Color(0xFFC85A53),
      onError:   Color(0xFFFFFFFF),
    ),
    scaffold:  const Color(0xFFFBF9F6),
    appBarBg:  const Color(0xFFFBF9F6),
    appBarFg:  const Color(0xFF191919),
    colors:    AppColors.light,
  );

  static ThemeData get dark => _build(
    brightness:  Brightness.dark,
    scheme: const ColorScheme.dark(
      primary:   Color(0xFF5C8DD4),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFFD4876A),
      surface:   Color(0xFF1C1C1E),
      onSurface: Color(0xFFECE9E3),
      error:     Color(0xFFD97570),
      onError:   Color(0xFF1A0A09),
    ),
    scaffold:  const Color(0xFF121212),
    appBarBg:  const Color(0xFF1C1C1E),
    appBarFg:  const Color(0xFFECE9E3),
    colors:    AppColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
    required Color appBarBg,
    required Color appBarFg,
    required AppColors colors,
  }) => ThemeData(
    useMaterial3: true,
    fontFamily: _font,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    extensions: [colors],
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: appBarFg,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: _font,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        fontFamily: _font,
        color: colors.inkSoft,
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.borderSoft),
  );

  static const _textTheme = TextTheme(
    bodyLarge:   TextStyle(fontFamily: _font),
    bodyMedium:  TextStyle(fontFamily: _font),
    bodySmall:   TextStyle(fontFamily: _font),
    titleLarge:  TextStyle(fontFamily: _font),
    titleMedium: TextStyle(fontFamily: _font),
    titleSmall:  TextStyle(fontFamily: _font),
    labelLarge:  TextStyle(fontFamily: _font),
    labelMedium: TextStyle(fontFamily: _font),
    labelSmall:  TextStyle(fontFamily: _font),
  );
}
