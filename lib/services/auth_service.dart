import '../core/api_client.dart';

class StaffLoginResult {
  StaffLoginResult({
    required this.token,
    required this.userId,
    required this.fullName,
    required this.username,
    required this.roleId,
    required this.roleName,
    required this.permissions,
  });

  final String token;
  final int userId;
  final String fullName;
  final String username;
  final int roleId;
  final String roleName;
  final Map<String, bool> permissions;
}

class ParentLoginResult {
  ParentLoginResult({required this.token, required this.parentId, required this.phone, this.fullName});

  final String token;
  final int parentId;
  final String phone;
  final String? fullName;
}

class AuthService {
  final _client = ApiClient.instance;

  Future<StaffLoginResult> staffLogin(String username, String password) async {
    final res = await _client.post('/api/auth/staff/login', data: {'username': username, 'password': password});
    final data = res.data as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    final perms = (data['permissions'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, v == true));
    return StaffLoginResult(
      token: data['token'] as String,
      userId: user['userId'] as int,
      fullName: user['fullName'] as String? ?? '',
      username: user['username'] as String? ?? '',
      roleId: user['roleId'] as int,
      roleName: user['roleName'] as String? ?? '',
      permissions: perms,
    );
  }

  Future<ParentLoginResult> parentLogin(String phone, String password) async {
    final res = await _client.post('/api/auth/parent/login', data: {'phone': phone, 'password': password});
    final data = res.data as Map<String, dynamic>;
    final p = data['parent'] as Map<String, dynamic>;
    return ParentLoginResult(token: data['token'] as String, parentId: p['parentId'] as int, phone: p['phone'] as String? ?? '', fullName: p['fullName'] as String?);
  }

  Future<ParentLoginResult> parentRegister(String phone, String password, String? fullName) async {
    final res = await _client.post('/api/auth/parent/register', data: {'phone': phone, 'password': password, 'fullName': fullName});
    final data = res.data as Map<String, dynamic>;
    final p = data['parent'] as Map<String, dynamic>;
    return ParentLoginResult(token: data['token'] as String, parentId: p['parentId'] as int, phone: p['phone'] as String? ?? '', fullName: p['fullName'] as String?);
  }
}
