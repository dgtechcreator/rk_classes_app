import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/app_user.dart';
import '../../services/user_mgmt_service.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../services/photo_service.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_avatar.dart';

/// Create/edit a staff user — mirrors UsersController.Save. Role list is fetched fresh from
/// GET /api/users/roles (added alongside this screen; there was previously no way to know the role
/// options before an existing user's detail page had already loaded them).
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, required this.service, this.user});
  final UserMgmtService service;
  final AppUser? user;

  bool get isEdit => user != null;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _fullNameCtrl = TextEditingController(text: widget.user?.fullName ?? '');
  late final _usernameCtrl = TextEditingController(text: widget.user?.username ?? '');
  late final _emailCtrl = TextEditingController(text: widget.user?.email ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.user?.phone ?? '');
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  FacultyOptions? _facultyOptions;
  int _facultyId = 0; // 0 = automatic matching

  bool _loadingRoles = true;
  String? _rolesError;
  List<Role> _roles = [];
  int? _roleId;
  late bool _isActive = widget.user?.isActive ?? true;
  late String _gender = widget.user?.gender ?? '';
  bool _saving = false;

  // Photo: applied after the user is saved (a new user has no id until then), same as the website form.
  String? _pickedPhoto;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    _roleId = widget.user?.roleId;
    _facultyId = widget.user?.facultyId ?? 0;
    _loadRoles();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() { _loadingRoles = true; _rolesError = null; });
    try {
      final roles = await widget.service.getRoles();
      FacultyOptions? faculty;
      try {
        faculty = await widget.service.getFacultyOptions(widget.user?.userId ?? 0);
      } on ApiException {
        // optional section - the rest of the form still works without it
      }
      if (mounted) setState(() { _roles = roles; _facultyOptions = faculty; _loadingRoles = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _rolesError = e.message; _loadingRoles = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleId == null) { showSnack(context, 'Select a role.', isError: true); return; }
    setState(() => _saving = true);
    try {
      final id = await widget.service.save(
        userId: widget.user?.userId ?? 0,
        fullName: _fullNameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        roleId: _roleId!,
        isActive: _isActive,
        gender: _gender,
        facultyId: _facultyOptions == null ? null : _facultyId,
        newPassword: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
      );
      var photoFailed = false;
      if (id > 0 && (_pickedPhoto != null || _removePhoto)) {
        try {
          String? newPath;
          if (_pickedPhoto != null) {
            newPath = await PhotoService().upload(PhotoOwner.user, id, _pickedPhoto!);
          } else {
            await PhotoService().remove(PhotoOwner.user, id);
          }
          if (mounted && id == context.read<Session>().userId) await context.read<Session>().setProfilePic(newPath);
        } on ApiException catch (e) {
          photoFailed = true;
          if (mounted) showSnack(context, 'User saved, but the photo failed: ${e.message}', isError: true);
        }
      }
      if (mounted) {
        if (!photoFailed) showSnack(context, widget.isEdit ? 'User updated.' : 'User created.');
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
      // The user itself was saved, only the Faculty link was refused - leave the form so a retry does not hit "username exists".
      if (mounted && e.message.startsWith('User saved')) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save user. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "Linked Faculty profile" - which teacher this login belongs to (photo, payments, lectures).
  Widget _facultyLink(FacultyOptions o) {
    final linkedElsewhere = {for (final f in o.faculties) if (f.linkedUserId != null && f.linkedUserId != widget.user?.userId) f.facultyId};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: _facultyId == 0 || o.faculties.any((f) => f.facultyId == _facultyId) ? _facultyId : 0,
          decoration: const InputDecoration(labelText: 'Linked Faculty profile'),
          items: [
            const DropdownMenuItem(value: 0, child: Text('Automatic (match by phone / name)')),
            ...o.faculties.map((f) => DropdownMenuItem(
                  value: f.facultyId,
                  enabled: !linkedElsewhere.contains(f.facultyId),
                  child: Text(
                    linkedElsewhere.contains(f.facultyId) ? '${f.label} (linked to ${f.linkedUserName})' : f.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: (v) => setState(() => _facultyId = v ?? 0),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text(
            (o.autoFacultyName ?? '').isNotEmpty ? 'Automatic matching currently finds: ${o.autoFacultyName}.' : 'Automatic matching finds no Faculty profile for this login.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit User' : 'New User')),
      body: _loadingRoles
          ? const LoadingView()
          : _rolesError != null
              ? ErrorView(message: _rolesError!, onRetry: _loadRoles)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      PhotoPickerField(
                        name: _fullNameCtrl.text,
                        serverPath: widget.user?.profilePicPath,
                        pickedFile: _pickedPhoto,
                        removed: _removePhoto,
                        onChanged: (file, removed) => setState(() { _pickedPhoto = file; _removePhoto = removed; }),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fullNameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name *'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(labelText: 'Username *'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
      isExpanded: true,
                        initialValue: _roles.any((r) => r.roleId == _roleId) ? _roleId : null,
                        decoration: const InputDecoration(labelText: 'Role *'),
                        items: _roles.map((r) => DropdownMenuItem(value: r.roleId, child: Text(r.roleName))).toList(),
                        onChanged: (v) => setState(() => _roleId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: widget.isEdit ? 'New Password (leave blank to keep current)' : 'Password *',
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (widget.isEdit) return null;
                          return (v ?? '').trim().length < 4 ? 'At least 4 characters' : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _gender,
                        decoration: const InputDecoration(labelText: "Gender (for Sir / Ma'am greeting)"),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Not set')),
                          DropdownMenuItem(value: 'Male', child: Text('Male (Sir)')),
                          DropdownMenuItem(value: 'Female', child: Text("Female (Ma'am)")),
                        ],
                        onChanged: (v) => setState(() => _gender = v ?? ''),
                      ),
                      if (_facultyOptions != null) ...[
                        const SizedBox(height: 12),
                        _facultyLink(_facultyOptions!),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeThumbColor: AppColors.success,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
