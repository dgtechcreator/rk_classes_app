import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
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
  bool playUpdate = false;        // the update comes from Google Play (in-app update) - asked to Play itself, no server file needed
  bool _playImmediateOk = false;
  bool _playFlexibleOk = false;

  static const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.rkclasses.rk_classes_app';

  /// Asks Google Play whether a newer release of THIS app is live. Works only for a copy installed from the Play Store
  /// (a debug / side-loaded copy just throws, which is ignored). A release marked high priority (4-5) becomes compulsory.
  Future<void> _checkPlay() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        playUpdate = true;
        _playImmediateOk = info.immediateUpdateAllowed;
        _playFlexibleOk = info.flexibleUpdateAllowed;
        updateAvailable = true;
        forceUpdate = forceUpdate || (info.updatePriority >= 4 && _playImmediateOk);
        updateUrl ??= playStoreUrl;
      } else {
        playUpdate = false;
      }
    } catch (_) {
      playUpdate = false;   // not installed from Play / no Play services: the server file (if any) still applies
    }
  }

  /// "Update now": Google's own update screen when allowed, otherwise the Play Store page. Returns false when nothing could be opened.
  Future<bool> startUpdate(Future<bool> Function(String url) openUrl) async {
    if (playUpdate) {
      try {
        if (_playImmediateOk) {
          await InAppUpdate.performImmediateUpdate();
          return true;
        }
        if (_playFlexibleOk) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
          return true;
        }
      } catch (_) {
        // fall through to the Play Store page
      }
    }
    final url = updateUrl ?? playStoreUrl;
    return openUrl(url);
  }

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
    }
    try {
      await _checkPlay();
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
