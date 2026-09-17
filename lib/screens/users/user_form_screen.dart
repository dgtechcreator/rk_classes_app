import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/app_user.dart';
import '../../services/user_mgmt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

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

  bool _loadingRoles = true;
  String? _rolesError;
  List<Role> _roles = [];
  int? _roleId;
  late bool _isActive = widget.user?.isActive ?? true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _roleId = widget.user?.roleId;
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
      if (mounted) setState(() { _roles = roles; _loadingRoles = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _rolesError = e.message; _loadingRoles = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleId == null) { showSnack(context, 'Select a role.', isError: true); return; }
    setState(() => _saving = true);
    try {
      await widget.service.save(
        userId: widget.user?.userId ?? 0,
        fullName: _fullNameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        roleId: _roleId!,
        isActive: _isActive,
        newPassword: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
      );
      if (mounted) {
        showSnack(context, widget.isEdit ? 'User updated.' : 'User created.');
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save user. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
