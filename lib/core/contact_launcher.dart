import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer / WhatsApp for a number. Returns false when nothing could handle the link
/// (e.g. WhatsApp not installed) so the caller can show a message.
class ContactLauncher {
  static Future<bool> call(String number) async {
    final digits = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return false;
    return launchUrl(Uri(scheme: 'tel', path: digits));
  }

  /// [internationalNumber] is digits only, with country code (see ContactNumber.whatsappNumber).
  static Future<bool> whatsapp(String internationalNumber, String message) {
    final uri = Uri.https('wa.me', '/$internationalNumber', {'text': message});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
