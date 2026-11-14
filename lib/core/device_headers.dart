import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Who is calling: sent on every request so the server can record, for each sign-in, which phone (model + Android / iOS
/// version) and which app version it came from (Privacy -> Login Activity). Plain ASCII only: it travels in HTTP headers.
class DeviceHeaders {
  static Map<String, String> value = const {'X-Platform': 'app'};

  static Future<void> init() async {
    try {
      final plugin = DeviceInfoPlugin();
      String device;
      if (kIsWeb) {
        device = '${(await plugin.webBrowserInfo).browserName.name} browser';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final a = await plugin.androidInfo;
            device = '${_cap(a.manufacturer)} ${a.model} - Android ${a.version.release}';
          case TargetPlatform.iOS:
            final i = await plugin.iosInfo;
            device = '${i.name} (${i.utsname.machine}) - iOS ${i.systemVersion}';
          default:
            device = defaultTargetPlatform.name;
        }
      }
      final pkg = await PackageInfo.fromPlatform();
      value = {'X-Platform': 'app', 'X-Device': _ascii(device), 'X-App-Version': _ascii(pkg.version)};
    } catch (_) {
      // keep the plain "app" marker: signing in must never depend on this
    }
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  static String _ascii(String s) => s.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
}
