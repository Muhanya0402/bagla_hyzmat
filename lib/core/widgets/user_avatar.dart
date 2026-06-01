import 'package:bagla/core/base_url.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Круглый аватар пользователя.
///
/// Если `fileId` задан — грузит картинку из Directus `/assets/<id>`.
/// Если файл недоступен / не задан — отрисовывает **первую букву имени**
/// на фоне `c.ink` (старое поведение).
///
/// Размер задаётся через `size` (диаметр в логических px).
/// Опциональный `borderColor` рисует круговой outline (например, цвет статуса).
class UserAvatar extends StatelessWidget {
  /// UUID файла в Directus (`selfie_scan` или произвольный). Пустая строка
  /// или `null` → используется fallback с буквой.
  final String? fileId;

  /// Имя пользователя — берётся первая буква для fallback.
  final String name;

  /// Диаметр аватара в логических px.
  final double size;

  /// Цвет круговой рамки (опц.). Если задан, рисуется outline толщиной
  /// `borderWidth`, внутри — `borderPadding` зазор и сам аватар.
  final Color? borderColor;
  final double borderWidth;
  final double borderPadding;

  const UserAvatar({
    super.key,
    required this.fileId,
    required this.name,
    required this.size,
    this.borderColor,
    this.borderWidth = 2,
    this.borderPadding = 3,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final inner = ClipOval(
      child: Container(
        width: size,
        height: size,
        color: c.ink,
        child: (fileId != null && fileId!.isNotEmpty)
            ? _NetworkAvatar(fileId: fileId!, name: name, size: size)
            : _LetterAvatar(name: name, size: size),
      ),
    );

    if (borderColor == null) return inner;
    final total = size + (borderWidth + borderPadding) * 2;
    return Container(
      width: total,
      height: total,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor!, width: borderWidth),
      ),
      padding: EdgeInsets.all(borderPadding),
      child: inner,
    );
  }
}

class _LetterAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _LetterAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty
        ? 'U'
        : name.trim().substring(0, 1).toUpperCase();
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
        ),
      ),
    );
  }
}

/// Картинка из Directus. Авторизуется через Bearer-токен в заголовке.
/// Токен читается из SharedPreferences один раз при первом build —
/// FutureBuilder показывает letter-fallback пока токен не подгружен.
class _NetworkAvatar extends StatelessWidget {
  final String fileId;
  final String name;
  final double size;
  const _NetworkAvatar({
    required this.fileId,
    required this.name,
    required this.size,
  });

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _readToken(),
      builder: (_, snap) {
        final token = snap.data;
        if (token == null || token.isEmpty) {
          return _LetterAvatar(name: name, size: size);
        }
        // Просим Directus отдать square crop через transform.
        // fit=cover + width/height → центрированный кроп без искажений.
        final url = '${BaseUrl.url}/assets/$fileId'
            '?fit=cover&width=${(size * 2).toInt()}&height=${(size * 2).toInt()}';
        return Image.network(
          url,
          fit: BoxFit.cover,
          headers: {'Authorization': 'Bearer $token'},
          // Плейсхолдер пока грузится — буква, чтобы не было «дёрга».
          loadingBuilder: (ctx, child, prog) {
            if (prog == null) return child;
            return _LetterAvatar(name: name, size: size);
          },
          errorBuilder: (_, _, _) => _LetterAvatar(name: name, size: size),
        );
      },
    );
  }
}

