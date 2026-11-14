import '../core/api_client.dart';

class LoginEntry {
  LoginEntry.fromJson(Map<String, dynamic> j)
      : accountType = j['accountType']?.toString() ?? 'staff',
        accountId = (j['accountId'] as num?)?.toInt(),
        loginName = j['loginName']?.toString() ?? '',
        displayName = j['displayName']?.toString(),
        roleName = j['roleName']?.toString(),
        success = j['success'] == true,
        platform = j['platform']?.toString(),
        device = j['device']?.toString(),
        appVersion = j['appVersion']?.toString(),
        ip = j['ip']?.toString(),
        loggedAt = DateTime.tryParse(j['loggedAt']?.toString() ?? '') ?? DateTime.now();

  final String accountType;
  final int? accountId;
  final String loginName;
  final String? displayName;
  final String? roleName;
  final bool success;
  final String? platform;
  final String? device;
  final String? appVersion;
  final String? ip;
  final DateTime loggedAt;

  bool get isApp => platform == 'app';
  String get who => (displayName ?? '').trim().isNotEmpty ? displayName!.trim() : (loginName.isEmpty ? 'Unknown login' : loginName);
}

class LoginDevice {
  LoginDevice.fromJson(Map<String, dynamic> j)
      : device = j['device']?.toString() ?? 'Unknown device',
        platform = j['platform']?.toString(),
        logins = (j['logins'] as num?)?.toInt() ?? 0,
        lastUsed = DateTime.tryParse(j['lastUsed']?.toString() ?? '') ?? DateTime.now(),
        lastIp = j['lastIp']?.toString();

  final String device;
  final String? platform;
  final int logins;
  final DateTime lastUsed;
  final String? lastIp;
  bool get isApp => platform == 'app';
}

class LoginActivityData {
  LoginActivityData(this.entries, this.devices);
  final List<LoginEntry> entries;
  final List<LoginDevice> devices;
}

/// Sign-in history (Privacy / Security): everyone sees their own; the admin can also see everybody's.
class LoginActivityService {
  final _client = ApiClient.instance;

  LoginActivityData _parse(dynamic data) {
    final m = data as Map<String, dynamic>;
    return LoginActivityData(
      ((m['entries'] as List?) ?? const []).map((e) => LoginEntry.fromJson(e as Map<String, dynamic>)).toList(),
      ((m['devices'] as List?) ?? const []).map((e) => LoginDevice.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<LoginActivityData> mine() async => _parse((await _client.get('/api/login-activity/mine')).data);

  /// [type] staff | parent, [result] ok | failed, [account] "staff:3" / "parent:12" (one person: also returns their devices).
  Future<LoginActivityData> all({String? type, String? q, String? result, String? account}) async {
    final res = await _client.get('/api/login-activity/all', query: {
      if (type != null) 'type': type,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (result != null) 'result': result,
      if (account != null) 'account': account,
    });
    return _parse(res.data);
  }
}
