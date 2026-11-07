import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording (Android FLAG_SECURE). Switched on for parent / student logins only -
/// staff share receipts and reports and need to be able to capture their own screen.
class ScreenSecurity {
  static const _channel = MethodChannel('rk/secure');
  static bool? _on;

  static Future<void> set(bool on) async {
    if (_on == on) return;
    _on = on;
    try {
      await _channel.invokeMethod<bool>('setSecure', {'on': on});
    } on PlatformException {
      _on = null;   // try again next time
    } on MissingPluginException {
      _on = null;   // non-Android build: nothing to block
    }
  }
}
