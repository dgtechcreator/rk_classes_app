int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
bool _asBool(dynamic v) => v == true || v?.toString().toLowerCase() == 'true';
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();

class Role {
  Role({required this.roleId, required this.roleName});
  final int roleId;
  final String roleName;

  factory Role.fromJson(Map<String, dynamic> j) => Role(
        roleId: _asInt(j['roleId']),
        roleName: _asString(j['roleName']),
      );
}

class AppModule {
  AppModule({
    required this.moduleId,
    required this.moduleName,
    this.moduleKey,
    this.icon,
    this.groupName,
    this.orderNo = 0,
    this.canView = false,
    this.canEdit = false,
  });

  final int moduleId;
  final String moduleName;
  final String? moduleKey;
  final String? icon;
  final String? groupName;
  final int orderNo;
  final bool canView;
  final bool canEdit;

  factory AppModule.fromJson(Map<String, dynamic> j) => AppModule(
        moduleId: _asInt(j['moduleId']),
        moduleName: _asString(j['moduleName']),
        moduleKey: _asStringN(j['moduleKey']),
        icon: _asStringN(j['icon']),
        groupName: _asStringN(j['groupName']),
        orderNo: _asInt(j['orderNo']),
        canView: _asBool(j['canView']),
        canEdit: _asBool(j['canEdit']),
      );

  AppModule copyWith({bool? canView, bool? canEdit}) => AppModule(
        moduleId: moduleId,
        moduleName: moduleName,
        moduleKey: moduleKey,
        icon: icon,
        groupName: groupName,
        orderNo: orderNo,
        canView: canView ?? this.canView,
        canEdit: canEdit ?? this.canEdit,
      );
}

class AppUser {
  AppUser({
    required this.userId,
    required this.fullName,
    required this.username,
    this.email,
    this.phone,
    required this.roleId,
    this.roleName,
    this.isActive = true,
    this.permCount = 0,
  });

  final int userId;
  final String fullName;
  final String username;
  final String? email;
  final String? phone;
  final int roleId;
  final String? roleName;
  final bool isActive;
  final int permCount;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        userId: _asInt(j['userId']),
        fullName: _asString(j['fullName']),
        username: _asString(j['username']),
        email: _asStringN(j['email']),
        phone: _asStringN(j['phone']),
        roleId: _asInt(j['roleId']),
        roleName: _asStringN(j['roleName']),
        isActive: j['isActive'] == null ? true : _asBool(j['isActive']),
        permCount: _asInt(j['permCount']),
      );
}

class UserDetail {
  UserDetail({required this.user, required this.isOwnProfile, required this.isAdmin, required this.roles, required this.modules});
  final AppUser user;
  final bool isOwnProfile;
  final bool isAdmin;
  final List<Role> roles;
  final List<AppModule> modules;

  factory UserDetail.fromJson(Map<String, dynamic> j) => UserDetail(
        user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
        isOwnProfile: _asBool(j['isOwnProfile']),
        isAdmin: _asBool(j['isAdmin']),
        roles: (j['roles'] as List? ?? []).map((e) => Role.fromJson(e as Map<String, dynamic>)).toList(),
        modules: (j['modules'] as List? ?? []).map((e) => AppModule.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class UserRights {
  UserRights({required this.userId, required this.userName, required this.modules});
  final int userId;
  final String userName;
  final List<AppModule> modules;

  factory UserRights.fromJson(Map<String, dynamic> j) => UserRights(
        userId: _asInt(j['userId']),
        userName: _asString(j['userName']),
        modules: (j['modules'] as List? ?? []).map((e) => AppModule.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
