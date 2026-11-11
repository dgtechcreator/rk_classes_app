import '../core/api_client.dart';
import '../models/app_user.dart';

class PortalSectionItem {
  PortalSectionItem({required this.key, required this.label, required this.description, required this.visible});
  final String key, label, description;
  final bool visible;
}

class RoleItem {
  RoleItem({required this.roleId, required this.roleName, required this.userCount});
  final int roleId, userCount;
  final String roleName;
}

class RoleTemplate {
  RoleTemplate({required this.roleName, required this.source, required this.userCount, required this.modules});
  final String roleName, source;
  final int userCount;
  final List<AppModule> modules;
}

/// Roles & Access (admin only): which sections Student / Parent logins see, and the default rights of every staff role.
/// Mirrors the website's Users -> Roles & Access page (api/roles).
class RolesService {
  final _client = ApiClient.instance;

  Future<({List<PortalSectionItem> portal, List<RoleItem> roles})> getAll() async {
    final res = await _client.get('/api/roles');
    final j = res.data as Map<String, dynamic>;
    return (
      portal: (j['portal'] as List? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return PortalSectionItem(key: '${m['key']}', label: '${m['label']}', description: '${m['description'] ?? ''}', visible: m['visible'] == true);
      }).toList(),
      roles: (j['roles'] as List? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return RoleItem(roleId: (m['roleId'] as num?)?.toInt() ?? 0, roleName: '${m['roleName']}', userCount: (m['userCount'] as num?)?.toInt() ?? 0);
      }).toList(),
    );
  }

  Future<void> savePortal(List<String> visibleKeys) async => _client.post('/api/roles/portal', data: {'visible': visibleKeys});

  Future<RoleTemplate> getTemplate(int roleId) async {
    final res = await _client.get('/api/roles/$roleId/template');
    final j = res.data as Map<String, dynamic>;
    return RoleTemplate(
      roleName: '${j['roleName']}', source: '${j['source']}', userCount: (j['userCount'] as num?)?.toInt() ?? 0,
      modules: (j['modules'] as List? ?? []).map((e) => AppModule.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Returns how many existing users were changed (0 unless [applyToExisting]).
  Future<int> saveTemplate(int roleId, List<AppModule> modules, {required bool applyToExisting}) async {
    final res = await _client.post('/api/roles/$roleId/template', data: {
      'applyToExisting': applyToExisting,
      'entries': [for (final m in modules) {'moduleId': m.moduleId, 'canView': m.canView || m.canEdit, 'canEdit': m.canEdit}],
    });
    return ((res.data as Map<String, dynamic>)['applied'] as num?)?.toInt() ?? 0;
  }
}
