import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/app_user.dart';
import '../../services/roles_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Roles & Access (admin): switch sections on / off for Student / Parent logins, and set the default rights of each staff role.
/// Same as the website's Users -> Roles & Access page.
class RolesAccessScreen extends StatefulWidget {
  const RolesAccessScreen({super.key});

  @override
  State<RolesAccessScreen> createState() => _RolesAccessScreenState();
}

class _RolesAccessScreenState extends State<RolesAccessScreen> {
  final _service = RolesService();
  bool _loading = true, _saving = false;
  String? _error;
  List<PortalSectionItem> _portal = [];
  Set<String> _visible = {};
  List<RoleItem> _roles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _service.getAll();
      if (mounted) setState(() { _portal = r.portal; _visible = r.portal.where((p) => p.visible).map((p) => p.key).toSet(); _roles = r.roles; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _savePortal() async {
    setState(() => _saving = true);
    try {
      await _service.savePortal(_visible.toList());
      if (mounted) showSnack(context, 'Saved. Students and parents see the change when they open or refresh the app.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Roles & Access')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  children: [
                    Row(children: [
                      const Icon(Icons.school_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Student / Parent login', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                      TextButton.icon(
                        onPressed: _saving ? null : _savePortal,
                        icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save'),
                      ),
                    ]),
                    const Text('Switch a section off to hide it from the parent website and the app. Students and parents share one login, so this applies to both.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(children: [
                        for (final p in _portal)
                          SwitchListTile(
                            value: _visible.contains(p.key),
                            onChanged: (v) => setState(() { v ? _visible.add(p.key) : _visible.remove(p.key); }),
                            title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(p.description, style: const TextStyle(fontSize: 12)),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    const Text('Home and the child switcher are always shown. "Test Marks" also controls the class toppers.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    const SizedBox(height: 22),
                    const Row(children: [
                      Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Staff roles — default rights', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
                    const SizedBox(height: 2),
                    const Text('New users of a role start with these rights. You can also apply them to everyone who already has the role.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    for (final r in _roles)
                      Card(
                        child: ListTile(
                          title: Text(r.roleName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${r.userCount} user(s)'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoleTemplateScreen(roleId: r.roleId, service: _service)));
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// The module matrix of one staff role (View / Edit per module).
class RoleTemplateScreen extends StatefulWidget {
  const RoleTemplateScreen({super.key, required this.roleId, required this.service});
  final int roleId;
  final RolesService service;

  @override
  State<RoleTemplateScreen> createState() => _RoleTemplateScreenState();
}

class _RoleTemplateScreenState extends State<RoleTemplateScreen> {
  bool _loading = true, _saving = false, _apply = false;
  String? _error;
  RoleTemplate? _t;
  List<AppModule> _modules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final t = await widget.service.getTemplate(widget.roleId);
      if (mounted) setState(() { _t = t; _modules = t.modules; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _setView(int id, bool v) => setState(() => _modules = _modules.map((m) => m.moduleId == id ? m.copyWith(canView: v, canEdit: v ? m.canEdit : false) : m).toList());
  void _setEdit(int id, bool v) => setState(() => _modules = _modules.map((m) => m.moduleId == id ? m.copyWith(canEdit: v, canView: v ? true : m.canView) : m).toList());

  Future<void> _save() async {
    if (_apply) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Apply to existing users?'),
          content: const Text('This replaces the individual rights of every existing user with this role.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _saving = true);
    try {
      final n = await widget.service.saveTemplate(widget.roleId, _modules, applyToExisting: _apply);
      if (!mounted) return;
      showSnack(context, _apply ? 'Saved and applied to $n existing user(s).' : 'Saved. New users of this role start with these rights.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) { setState(() => _saving = false); showSnack(context, e.message, isError: true); }
    }
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), visualDensity: VisualDensity.compact),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AppModule>>{};
    for (final m in _modules) {
      groups.putIfAbsent(m.groupName?.isNotEmpty == true ? m.groupName! : 'Other', () => []).add(m);
    }
    final src = _t == null ? '' : _t!.source == 'saved' ? 'Showing the rights saved for this role.' : _t!.source.startsWith('user:') ? 'No template saved yet — starting from the rights of ${_t!.source.substring(5)}.' : 'No template saved yet — nothing is ticked.';
    return Scaffold(
      appBar: AppBar(title: Text(_t == null ? 'Role rights' : '${_t!.roleName} — default rights')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    Text('${_t!.userCount} existing user(s) · $src', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    for (final e in groups.entries) ...[
                      SectionHeader(title: e.key),
                      Card(
                        child: Column(children: [
                          for (final m in e.value)
                            ListTile(
                              title: Text(m.moduleName),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                _check('View', m.canView, (v) => _setView(m.moduleId, v)),
                                const SizedBox(width: 8),
                                _check('Edit', m.canEdit, (v) => _setEdit(m.moduleId, v)),
                              ]),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],
                    CheckboxListTile(
                      value: _apply,
                      onChanged: (v) => setState(() => _apply = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text('Also apply to existing users (${_t!.userCount})'),
                    ),
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
}
