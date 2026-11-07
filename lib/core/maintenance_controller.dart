import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';

/// Maintenance mode, switched from the website (App Settings). The server then answers every API call with 503, and
/// GET /api/app-config (always answered) tells the app when it is over. Fails open: if the check itself cannot reach
/// the server, nobody is blocked because of it.
class MaintenanceController extends ChangeNotifier {
  static const defaultMessage = 'RK Classes is under maintenance for a short while. Please try again shortly.';

  bool active = false;
  String message = defaultMessage;
  bool checking = false;
  Timer? _poll;

  // New app version (published by the admin in wwwroot/app/version.json, delivered through /api/app-config).
  bool updateAvailable = false;
  bool forceUpdate = false;
  String? latestVersion;
  String? updateUrl;
  String? updateMessage;
  bool updateDismissed = false;   // "Later" hides the card until the app is opened again

  void dismissUpdate() {
    updateDismissed = true;
    notifyListeners();
  }

  Future<void> _checkUpdate(Map data) async {
    final latest = (data['latestBuild'] as num?)?.toInt() ?? 0;
    if (latest <= 0) {
      updateAvailable = false;
      return;
    }
    try {
      final installed = int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
      updateAvailable = latest > installed;
    } catch (_) {
      updateAvailable = false;
    }
    forceUpdate = updateAvailable && data['forceUpdate'] == true;
    latestVersion = data['latestVersion']?.toString();
    updateMessage = data['updateMessage']?.toString();
    final url = data['apkUrl']?.toString();
    updateUrl = (url == null || url.isEmpty) ? null : (url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url');
  }

  /// Asks the server whether maintenance mode is on. Safe to call any time; never throws.
  Future<void> check() async {
    if (checking) return;
    checking = true;
    notifyListeners();
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (s) => s != null && s < 500,
      ));
      final res = await dio.get('/api/app-config');
      final data = res.data;
      if (res.statusCode == 200 && data is Map) {
        _set(data['maintenanceEnabled'] == true, data['maintenanceMessage']?.toString());
        await _checkUpdate(data);
      }
    } catch (_) {
      // unreachable / old server without the endpoint: keep the current state
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  /// Called by [ApiClient] when any request is answered with the server's maintenance 503.
  void markActive(String? serverMessage) {
    _set(true, serverMessage);
    notifyListeners();
  }

  void _set(bool on, String? serverMessage) {
    active = on;
    if (serverMessage != null && serverMessage.trim().isNotEmpty) message = serverMessage.trim();
    // While blocked, look again every 30 s so the page lifts by itself soon after the admin switches it off.
    if (on) {
      _poll ??= Timer.periodic(const Duration(seconds: 30), (_) => check());
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
