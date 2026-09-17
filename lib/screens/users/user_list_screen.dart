import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/app_user.dart';
import '../../services/user_mgmt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'user_form_screen.dart';
import 'user_permissions_screen.dart';

/// Staff user list — admin-only, matches UsersController.Index's hard RoleId==1 gate.
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _service = UserMgmtService();
  bool _loading = true;
  String? _error;
  List<AppUser> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users = await _service.getAll();
      if (mounted) setState(() { _users = users; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _openForm({AppUser? user}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => UserFormScreen(service: _service, user: user)));
    if (saved == true) _load();
  }

  Future<void> _toggleActive(AppUser u) async {
    try {
      await _service.toggleActive(u.userId);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not update user. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Users${_users.isNotEmpty ? ' (${_users.length})' : ''}')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.person_add_alt_1)),
    );
  }

  Widget _buildBody() {
    if (_users.isEmpty) return const EmptyState(message: 'No staff users found.', icon: Icons.admin_panel_settings_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: _users.length,
        itemBuilder: (_, i) {
          final u = _users[i];
          return Card(
            child: ListTile(
              onTap: () => _openForm(user: u),
              leading: CircleAvatar(
                backgroundColor: u.isActive ? AppColors.primarySoft : AppColors.border,
                child: Text(u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${u.username} • ${u.roleName ?? ''}${u.roleId != 1 ? ' • ${u.permCount} modules' : ''}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (u.roleId != 1)
                    IconButton(
                      icon: const Icon(Icons.security_outlined),
                      tooltip: 'Permissions',
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserPermissionsScreen(service: _service, userId: u.userId))),
                    ),
                  Switch(value: u.isActive, onChanged: (_) => _toggleActive(u), activeThumbColor: AppColors.success),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
