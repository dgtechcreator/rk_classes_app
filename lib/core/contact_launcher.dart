import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer / WhatsApp for a number. Returns false when nothing could handle the link
/// (e.g. WhatsApp not installed) so the caller can show a message.
enum WhatsAppApp {
  normal('WhatsApp', 'Normal WhatsApp'),
  business('WhatsApp Business', 'Business WhatsApp');

  const WhatsAppApp(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

class ContactLauncher {
  static const _channel = MethodChannel('rk/whatsapp');
  static const _prefKey = 'whatsapp_app';

  /// Which WhatsApp apps are installed on this phone. Empty when the platform can't tell.
  static Future<Set<WhatsAppApp>> installedWhatsApps() async {
    try {
      final m = await _channel.invokeMapMethod<String, bool>('installedApps');
      if (m == null) return {};
      return {
        if (m['normal'] == true) WhatsAppApp.normal,
        if (m['business'] == true) WhatsAppApp.business,
      };
    } on PlatformException {
      return {};
    } on MissingPluginException {
      return {};
    }
  }

  static Future<WhatsAppApp?> lastUsedWhatsApp() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_prefKey);
      return WhatsAppApp.values.where((a) => a.name == v).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  static Future<void> rememberWhatsApp(WhatsAppApp app) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_prefKey, app.name);
    } catch (_) {}
  }

  static Future<bool> call(String number) async {
    final digits = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return false;
    return launchUrl(Uri(scheme: 'tel', path: digits));
  }

  /// [internationalNumber] is digits only, with country code (see ContactNumber.whatsappNumber).
  static Future<bool> whatsapp(String internationalNumber, String message, {WhatsAppApp? app}) async {
    if (app != null) {
      try {
        final ok = await _channel.invokeMethod<bool>('openChat', {'phone': internationalNumber, 'text': message, 'app': app.name});
        if (ok == true) return true;
      } on PlatformException {
        // fall through to the generic link
      } on MissingPluginException {
        // fall through to the generic link
      }
    }
    final uri = Uri.https('wa.me', '/$internationalNumber', {'text': message});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
