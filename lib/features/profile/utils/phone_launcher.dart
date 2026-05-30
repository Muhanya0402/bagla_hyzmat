import 'package:url_launcher/url_launcher.dart';

/// Открывает системный звонок на номер. Очищает всё кроме цифр и `+`.
Future<void> launchPhoneCall(String phone) async {
  final uri = Uri(
    scheme: 'tel',
    path: phone.replaceAll(RegExp(r'[^\d+]'), ''),
  );
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}
