import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
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
  String displayName = '';   // "Kapil Sir" / "Pooja Ma'am" for teachers & admins, else the full name
  String username = '';
  int roleId = 0;
  String roleName = '';
  String? profilePicPath;    // site-relative path of the login's own photo (shared with the web app)
  Map<String, bool> permissions = {};

  // Class Representative (CR / Monitor): a student login limited to his own class. Set from the server.
  bool isClassRep = false;
  String crLabel = '';       // e.g. "5th · English · Morning"
  int crEditDays = 2;        // may mark today and this many previous days
  int crMarksEditDays = 7;   // test marks: tests of the last N days
  int? crClassId;            // his own class (marks entry is locked to it)

  /// Oldest date a CR may still mark / edit.
  DateTime get crEarliestDate => DateUtils.dateOnly(DateTime.now().subtract(Duration(days: crEditDays)));
  DateTime get crEarliestMarksDate => DateUtils.dateOnly(DateTime.now().subtract(Duration(days: crMarksEditDays)));

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
  static const _kDisplayName = 'session_displayName';
  static const _kUsername = 'session_username';
  static const _kRoleId = 'session_roleId';
  static const _kRoleName = 'session_roleName';
  static const _kProfilePic = 'session_profilePic';
  static const _kPermissions = 'session_permissions';
  static const _kClassRep = 'session_classRep';
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
    displayName = prefs.getString(_kDisplayName) ?? fullName;
    username = prefs.getString(_kUsername) ?? '';
    roleId = prefs.getInt(_kRoleId) ?? 0;
    roleName = prefs.getString(_kRoleName) ?? '';
    profilePicPath = prefs.getString(_kProfilePic);
    final permJson = prefs.getString(_kPermissions);
    permissions = permJson == null ? {} : Map<String, bool>.from(jsonDecode(permJson) as Map);
    _readClassRep(prefs.getString(_kClassRep));
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
    String? displayName,
    required String username,
    required int roleId,
    required String roleName,
    String? profilePicPath,
    required Map<String, bool> permissions,
    Map<String, dynamic>? classRep,
  }) async {
    await ApiClient.instance.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserType, 'staff');
    await prefs.setInt(_kUserId, userId);
    await prefs.setString(_kFullName, fullName);
    await prefs.setString(_kDisplayName, (displayName ?? '').isEmpty ? fullName : displayName!);
    await prefs.setString(_kUsername, username);
    await prefs.setInt(_kRoleId, roleId);
    await prefs.setString(_kRoleName, roleName);
    await _storePic(prefs, profilePicPath);
    await prefs.setString(_kPermissions, jsonEncode(permissions));
    await prefs.setString(_kClassRep, classRep == null ? '' : jsonEncode(classRep));

    userType = UserType.staff;
    this.userId = userId;
    this.fullName = fullName;
    this.displayName = (displayName ?? '').isEmpty ? fullName : displayName!;
    this.username = username;
    this.roleId = roleId;
    this.roleName = roleName;
    this.profilePicPath = (profilePicPath ?? '').isEmpty ? null : profilePicPath;
    this.permissions = permissions;
    _readClassRep(classRep == null ? null : jsonEncode(classRep));
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> _storePic(SharedPreferences prefs, String? path) async {
    if (path == null || path.isEmpty) {
      await prefs.remove(_kProfilePic);
    } else {
      await prefs.setString(_kProfilePic, path);
    }
  }

  /// Called right after the logged-in user uploads / removes their own photo (null or '' = removed).
  Future<void> setProfilePic(String? path) async {
    profilePicPath = (path ?? '').isEmpty ? null : path;
    await _storePic(await SharedPreferences.getInstance(), profilePicPath);
    notifyListeners();
  }

  void _readClassRep(String? json) {
    isClassRep = false;
    crLabel = '';
    crClassId = null;
    if (json == null || json.isEmpty) return;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      isClassRep = true;
      crEditDays = (m['editDays'] as num?)?.toInt() ?? 2;
      crMarksEditDays = (m['marksEditDays'] as num?)?.toInt() ?? 7;
      crClassId = (m['classId'] as num?)?.toInt();
      crLabel = [m['className'], m['sectionName'], m['batchName']]
          .where((e) => e != null && e.toString().isNotEmpty)
          .join(' · ');
    } catch (_) {
      isClassRep = false;
    }
  }

  /// Pulls the live rights from the server (GET /api/auth/me) so a right the admin just changed - or an
  /// account that was switched off - shows up without logging in again. Network errors are ignored;
  /// only an explicit 401 (account disabled / deleted) signs the user out.
  Future<void> refreshFromServer() async {
    if (status != AuthStatus.signedIn || userType != UserType.staff) return;
    try {
      final res = await ApiClient.instance.get('/api/auth/me');
      final data = res.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final perms = (data['permissions'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, v == true));
      final cr = data['classRep'] as Map<String, dynamic>?;
      final prefs = await SharedPreferences.getInstance();
      final dn = (user['displayName'] as String?) ?? '';
      if (dn.isNotEmpty) {
        await prefs.setString(_kDisplayName, dn);
        displayName = dn;
      }
      if (user.containsKey('profilePicPath')) {   // an older server does not send it - keep what we have then
        final pic = user['profilePicPath'] as String?;
        await _storePic(prefs, pic);
        profilePicPath = (pic ?? '').isEmpty ? null : pic;
      }
      await prefs.setInt(_kRoleId, (user['roleId'] as num).toInt());
      await prefs.setString(_kRoleName, user['roleName'] as String? ?? '');
      await prefs.setString(_kPermissions, jsonEncode(perms));
      await prefs.setString(_kClassRep, cr == null ? '' : jsonEncode(cr));
      roleId = (user['roleId'] as num).toInt();
      roleName = user['roleName'] as String? ?? '';
      permissions = perms;
      _readClassRep(cr == null ? null : jsonEncode(cr));
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401) await signOut();
    } catch (_) {
      // offline / server busy - keep what we have
    }
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
    displayName = '';
    username = '';
    roleId = 0;
    roleName = '';
    profilePicPath = null;
    permissions = {};
    isClassRep = false;
    crLabel = '';
    parentId = 0;
    phone = '';
    parentName = '';
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
