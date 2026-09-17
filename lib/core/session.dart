import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

enum AuthStatus { unknown, signedOut, signedIn }

enum UserType { staff, parent }

/// App-wide session state — mirrors what AccountController/ParentController put in the web session,
/// carried as a JWT instead of a cookie. `userType` picks which shell (StaffShell/ParentShell) the app
/// shows, matching RK Classes' two separate login systems (staff username/password vs parent
/// phone/password) rather than one shared account table.
class Session extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  UserType userType = UserType.staff;

  // Staff fields
  int userId = 0;
  String fullName = '';
  String username = '';
  int roleId = 0;
  String roleName = '';
  Map<String, bool> permissions = {};

  // Parent fields
  int parentId = 0;
  String phone = '';
  String parentName = '';

  bool get isAdmin => roleId == 1;
  bool hasPerm(String key) => isAdmin || (permissions[key] ?? false);
  bool hasEditPerm(String key) => isAdmin || (permissions['${key}_edit'] ?? false);

  static const _kUserType = 'session_userType';
  static const _kUserId = 'session_userId';
  static const _kFullName = 'session_fullName';
  static const _kUsername = 'session_username';
  static const _kRoleId = 'session_roleId';
  static const _kRoleName = 'session_roleName';
  static const _kPermissions = 'session_permissions';
  static const _kParentId = 'session_parentId';
  static const _kPhone = 'session_phone';
  static const _kParentName = 'session_parentName';

  Future<void> restore() async {
    await ApiClient.instance.loadPersistedToken();
    final prefs = await SharedPreferences.getInstance();
    if (!ApiClient.instance.hasToken) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    userType = (prefs.getString(_kUserType) ?? 'staff') == 'parent' ? UserType.parent : UserType.staff;
    userId = prefs.getInt(_kUserId) ?? 0;
    fullName = prefs.getString(_kFullName) ?? '';
    username = prefs.getString(_kUsername) ?? '';
    roleId = prefs.getInt(_kRoleId) ?? 0;
    roleName = prefs.getString(_kRoleName) ?? '';
    final permJson = prefs.getString(_kPermissions);
    permissions = permJson == null ? {} : Map<String, bool>.from(jsonDecode(permJson) as Map);
    parentId = prefs.getInt(_kParentId) ?? 0;
    phone = prefs.getString(_kPhone) ?? '';
    parentName = prefs.getString(_kParentName) ?? '';

    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> applyStaffLogin({
    required String token,
    required int userId,
    required String fullName,
    required String username,
    required int roleId,
    required String roleName,
    required Map<String, bool> permissions,
  }) async {
    await ApiClient.instance.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserType, 'staff');
    await prefs.setInt(_kUserId, userId);
    await prefs.setString(_kFullName, fullName);
    await prefs.setString(_kUsername, username);
    await prefs.setInt(_kRoleId, roleId);
    await prefs.setString(_kRoleName, roleName);
    await prefs.setString(_kPermissions, jsonEncode(permissions));

    userType = UserType.staff;
    this.userId = userId;
    this.fullName = fullName;
    this.username = username;
    this.roleId = roleId;
    this.roleName = roleName;
    this.permissions = permissions;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> applyParentLogin({
    required String token,
    required int parentId,
    required String phone,
    String? parentName,
  }) async {
    await ApiClient.instance.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserType, 'parent');
    await prefs.setInt(_kParentId, parentId);
    await prefs.setString(_kPhone, phone);
    await prefs.setString(_kParentName, parentName ?? '');

    userType = UserType.parent;
    this.parentId = parentId;
    this.phone = phone;
    this.parentName = parentName ?? '';
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signOut() async {
    await ApiClient.instance.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    userId = 0;
    fullName = '';
    username = '';
    roleId = 0;
    roleName = '';
    permissions = {};
    parentId = 0;
    phone = '';
    parentName = '';
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
