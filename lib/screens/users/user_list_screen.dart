import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/app_user.dart';
import '../../services/user_mgmt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_avatar.dart';
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
  String _query = '';

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

  void _openPermissions(AppUser u) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserPermissionsScreen(service: _service, userId: u.userId)));

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

  Future<void> _delete(AppUser u) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete ${u.fullName}? They will not be able to login. You can restore them later from Deleted Records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteUser(u.userId);
      if (mounted) { showSnack(context, '${u.fullName} deleted.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not delete user. Please try again.', isError: true);
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
    final myId = context.read<Session>().userId;
    if (_users.isEmpty) return const EmptyState(message: 'No staff users found.', icon: Icons.admin_panel_settings_outlined);
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _users
        : _users.where((u) => u.fullName.toLowerCase().contains(q) || u.username.toLowerCase().contains(q) || (u.roleName ?? '').toLowerCase().contains(q)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search name, username or role',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: shown.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(message: 'No user matches your search.', icon: Icons.search_off_rounded))])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _UserCard(
                      user: shown[i],
                      canDelete: shown[i].userId != 1 && shown[i].userId != myId,
                      onTap: () => _openForm(user: shown[i]),
                      onToggle: () => _toggleActive(shown[i]),
                      onPermissions: () => _openPermissions(shown[i]),
                      onDelete: () => _delete(shown[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.canDelete, required this.onTap, required this.onToggle, required this.onPermissions, required this.onDelete});
  final AppUser user;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onPermissions;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final isAdmin = u.roleId == 1;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                ProfileAvatar(
                  name: u.fullName,
                  photoPath: u.profilePicPath,
                  size: 44,
                  background: u.isActive ? AppColors.primarySoft : AppColors.borderNeutral,
                  foreground: u.isActive ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: u.isActive ? AppColors.textPrimary : AppColors.textMuted)),
                      const SizedBox(height: 1),
                      Text('@${u.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (!u.isActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            u.deactivatedByName == null && u.deactivatedAt == null
                                ? 'Switched off (who / when was not recorded)'
                                : 'Switched off by ${u.deactivatedByName ?? '—'}${u.deactivatedAt == null ? '' : ' • ${DateFormat('d MMM yyyy, h:mm a').format(u.deactivatedAt!)}'}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.danger),
                          ),
                        ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if ((u.roleName ?? '').isNotEmpty) _pill(u.roleName!, isAdmin ? AppColors.violet : AppColors.info),
                          if (!isAdmin) _pill('${u.permCount} ${u.permCount == 1 ? 'module' : 'modules'}', AppColors.teal),
                          if (!u.isActive) _pill('Inactive', AppColors.danger),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(value: u.isActive, onChanged: (_) => onToggle(), activeThumbColor: AppColors.success),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                  onSelected: (v) {
                    if (v == 'edit') onTap();
                    if (v == 'perm') onPermissions();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                    if (!isAdmin)
                      const PopupMenuItem(value: 'perm', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.security_outlined), title: Text('Permissions'))),
                    if (canDelete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline, color: AppColors.danger), title: Text('Delete', style: TextStyle(color: AppColors.danger))),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      );
}
