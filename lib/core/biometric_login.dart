import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint (or face / screen-lock biometrics) sign-in.
///
/// After a normal password sign-in the person may switch it on. The login id + password are then kept in the phone's secure
/// storage (Android Keystore / iOS Keychain - encrypted, never leave the phone). "Login with fingerprint" asks the phone to
/// check the fingerprint and then signs in with those saved details through the normal login, so the server still checks
/// the account, the rights and a changed password every time. [kind] is "staff" or "parent".
class BiometricLogin {
  static final _auth = LocalAuthentication();
  static const _store = FlutterSecureStorage();

  static String _key(String kind) => 'bio_login_$kind';

  /// The phone has a fingerprint / face sensor with something enrolled.
  static Future<bool> available() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled(String kind) async {
    try {
      return (await _store.read(key: _key(kind))) != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> enable(String kind, String loginId, String password) async {
    await _store.write(key: _key(kind), value: jsonEncode({'id': loginId, 'pw': password}));
  }

  static Future<void> disable(String kind) async {
    try {
      await _store.delete(key: _key(kind));
    } catch (_) {}
  }

  /// Asks for the fingerprint; the saved login details when it matches, null when cancelled / refused / nothing saved.
  static Future<({String id, String password})?> unlock(String kind) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Use your fingerprint to sign in to RK Classes',
        biometricOnly: true,
      );
      if (!ok) return null;
      final raw = await _store.read(key: _key(kind));
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (id: (m['id'] ?? '').toString(), password: (m['pw'] ?? '').toString());
    } catch (_) {
      return null;
    }
  }
}
