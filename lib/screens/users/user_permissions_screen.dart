import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/app_user.dart';
import '../../services/user_mgmt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Per-module view/edit permission matrix for one staff user — mirrors UsersController's
/// AssignRights/SavePermissions flow. Admin (RoleId==1) always has full access regardless of these
/// rows, so this screen is only meaningful for non-admin staff (the Users list only shows it for them).
class UserPermissionsScreen extends StatefulWidget {
  const UserPermissionsScreen({super.key, required this.service, required this.userId});
  final UserMgmtService service;
  final int userId;

  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  bool _loading = true;
  String? _error;
  bool _saving = false;
  String _userName = '';
  List<AppModule> _modules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rights = await widget.service.getUserRights(widget.userId);
      if (mounted) setState(() { _userName = rights.userName; _modules = rights.modules; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _setView(int moduleId, bool v) {
    setState(() {
      _modules = _modules.map((m) => m.moduleId == moduleId ? m.copyWith(canView: v, canEdit: v ? m.canEdit : false) : m).toList();
    });
  }

  void _setEdit(int moduleId, bool v) {
    setState(() {
      _modules = _modules.map((m) => m.moduleId == moduleId ? m.copyWith(canEdit: v, canView: v ? true : m.canView) : m).toList();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.savePermissions(widget.userId, _modules);
      if (mounted) { showSnack(context, 'Permissions saved.'); Navigator.of(context).pop(true); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save permissions. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AppModule>>{};
    for (final m in _modules) {
      groups.putIfAbsent(m.groupName?.isNotEmpty == true ? m.groupName! : 'Other', () => []).add(m);
    }

    return Scaffold(
      appBar: AppBar(title: Text(_userName.isEmpty ? 'Permissions' : '$_userName — Permissions')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('View grants read-only access to a module; Edit also allows creating/changing its data.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    for (final entry in groups.entries) ...[
                      SectionHeader(title: entry.key),
                      Card(
                        child: Column(
                          children: entry.value.map((m) {
                            return ListTile(
                              title: Text(m.moduleName),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _permCheckbox('View', m.canView, (v) => _setView(m.moduleId, v)),
                                  const SizedBox(width: 8),
                                  _permCheckbox('Edit', m.canEdit, (v) => _setEdit(m.moduleId, v)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
      floatingActionButton: (!_loading && _error == null)
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
              label: const Text('Save'),
            )
          : null,
    );
  }

  Widget _permCheckbox(String label, bool value, ValueChanged<bool> onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), visualDensity: VisualDensity.compact),
      ],
    );
  }
}
