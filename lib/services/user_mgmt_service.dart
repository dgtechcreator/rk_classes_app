import '../core/api_client.dart';
import '../models/app_user.dart';

/// Wraps GET/POST api/users/* (UsersApiController). Mirrors UsersController's own authorization logic:
/// most actions are admin-only (RoleId == 1) checked server-side; Save/ChangePassword/ToggleActive
/// additionally allow a user to act on their own record.
class UserMgmtService {
  final _client = ApiClient.instance;

  Future<List<AppUser>> getAll() async {
    final res = await _client.get('/api/users');
    return (res.data as List).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Role>> getRoles() async {
    final res = await _client.get('/api/users/roles');
    return (res.data as List).map((e) => Role.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserDetail> getById(int id) async {
    final res = await _client.get('/api/users/$id');
    return UserDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<int> save({
    required int userId,
    required String fullName,
    required String username,
    String? email,
    String? phone,
    required int roleId,
    required bool isActive,
    String? newPassword,
  }) async {
    final res = await _client.post('/api/users/save', data: {
      'userId': userId,
      'fullName': fullName,
      'username': username,
      'email': email,
      'phone': phone,
      'roleId': roleId,
      'isActive': isActive,
      'newPassword': newPassword,
    });
    final data = res.data as Map<String, dynamic>;
    return data['userId'] is int ? data['userId'] as int : int.tryParse(data['userId'].toString()) ?? 0;
  }

  Future<UserRights> getUserRights(int userId) async {
    final res = await _client.get('/api/users/$userId/rights');
    return UserRights.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> savePermissions(int userId, List<AppModule> modules) async {
    final res = await _client.post('/api/users/permissions/save', data: {
      'userId': userId,
      'entries': modules.map((m) => {'moduleId': m.moduleId, 'canView': m.canView, 'canEdit': m.canEdit}).toList(),
    });
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ApiException(data['message']?.toString().isNotEmpty == true ? data['message'].toString() : 'Failed to save permissions.');
    }
  }

  Future<void> changePassword({required int userId, required String oldPassword, required String newPassword}) async {
    final res = await _client.post('/api/users/change-password', data: {
      'userId': userId,
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ApiException(data['message']?.toString().isNotEmpty == true ? data['message'].toString() : 'Failed to change password.');
    }
  }

  Future<void> toggleActive(int userId) async => _client.post('/api/users/$userId/toggle-active');
}
