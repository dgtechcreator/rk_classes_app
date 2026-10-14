import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../services/class_rep_service.dart';
import '../../services/lookup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Class Representatives (CR / Monitor) - admin only. Pick a student of a class, give him a login, switch him on / off.
/// A CR can mark only his own class's student attendance and add teacher attendance (subject + topic).
class ClassRepListScreen extends StatefulWidget {
  const ClassRepListScreen({super.key});

  @override
  State<ClassRepListScreen> createState() => _ClassRepListScreenState();
}

class _ClassRepListScreenState extends State<ClassRepListScreen> {
  final _service = ClassRepService();
  bool _loading = true;
  String? _error;
  List<ClassRep> _reps = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _service.getAll();
      if (mounted) setState(() { _reps = list; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AssignSheet(service: _service),
    );
    if (saved == true) _load();
  }

  Future<void> _edit(ClassRep r) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _EditDialog(service: _service, rep: r));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Class Representatives${_reps.isNotEmpty ? ' (${_reps.length})' : ''}')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _buildList()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Make CR'),
      ),
    );
  }

  Widget _buildList() {
    if (_reps.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        EmptyState(
          message: 'No Class Representative yet.\nTap "Make CR" to pick a student of a class.',
          icon: Icons.shield_outlined,
        ),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _reps.length,
      itemBuilder: (_, i) {
        final r = _reps[i];
        final status = r.isWorking ? 'Working' : (!r.studentActive ? 'Student inactive' : 'Switched off');
        return Card(
          child: ListTile(
            onTap: () => _edit(r),
            leading: CircleAvatar(
              backgroundColor: r.isWorking ? AppColors.primarySoft : AppColors.border,
              child: Icon(Icons.shield_outlined, color: r.isWorking ? AppColors.primary : AppColors.textSecondary),
            ),
            title: Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${r.classLabel}\nLogin: ${r.username}  •  ${r.limitToBatch && r.hasBatch ? 'own batch only' : 'whole class'}\n${r.rights.isEmpty ? 'No rights' : r.rights.map((k) => crRightLabels[k] ?? k).join(', ')}'),
            isThreeLine: true,
            trailing: Text(status,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: r.isWorking ? AppColors.success : AppColors.danger)),
          ),
        );
      },
    );
  }
}

String _randomPassword() => (100000 + Random().nextInt(900000)).toString();

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.service});
  final ClassRepService service;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final _lookup = LookupService();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController(text: _randomPassword());

  List<LookupItem> _classes = [], _sections = [];
  List<CrCandidate> _students = [];
  int? _classId, _sectionId, _studentId;
  bool _limit = true;
  final Set<String> _rights = {...crRightLabels.keys};
  bool _loadingStudents = false;
  bool _saving = false;
  String? _error;

  CrCandidate? get _student => _students.where((s) => s.studentId == _studentId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final c = await _lookup.getClasses();
      final s = await _lookup.getSections();
      if (mounted) setState(() { _classes = c; _sections = s; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadStudents() async {
    if (_classId == null) return;
    setState(() { _loadingStudents = true; _studentId = null; _students = []; _error = null; });
    try {
      final list = await widget.service.getStudents(classId: _classId!, sectionId: _sectionId);
      if (mounted) setState(() { _students = list; _loadingStudents = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loadingStudents = false; });
    }
  }

  void _studentPicked(int? id) {
    setState(() {
      _studentId = id;
      _limit = true;
      final s = _student;
      if (s != null && _userCtrl.text.isEmpty) {
        _userCtrl.text = ('cr${s.admissionNo}').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      }
    });
  }

  Future<void> _save() async {
    final user = _userCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();
    if (_studentId == null) { setState(() => _error = 'Select the student.'); return; }
    if (user.length < 3 || user.contains(RegExp(r'\s'))) { setState(() => _error = 'Username: at least 3 characters, no spaces.'); return; }
    if (pass.length < 4) { setState(() => _error = 'Password: at least 4 characters.'); return; }
    if (_rights.isEmpty) { setState(() => _error = 'Tick at least one right.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.service.assign(
        studentId: _studentId!, username: user, password: pass,
        limitToBatch: _limit && (_student?.hasBatch ?? false),
        rights: _rights.toList(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Class Representative created'),
          content: Text('Share this login with ${_student?.name ?? 'the student'}:\n\nUsername: $user\nPassword: $pass'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _saving = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not save. Please try again.'; _saving = false; });
    }
  }

  Widget _drop(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged, {bool allowAll = false}) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowAll) const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _student;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Make a student CR', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('He gets his own login and can work only inside his class.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _drop('Std *', _classId, _classes, (v) { setState(() => _classId = v); _loadStudents(); })),
              const SizedBox(width: 12),
              Expanded(child: _drop('Medium', _sectionId, _sections, (v) { setState(() => _sectionId = v); _loadStudents(); }, allowAll: true)),
            ]),
            const SizedBox(height: 12),
            if (_loadingStudents)
              const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _studentId,
                decoration: InputDecoration(labelText: _classId == null ? 'Student * (select Std first)' : 'Student * (${_students.length})'),
                items: _students
                    .map((e) => DropdownMenuItem<int?>(value: e.studentId, child: Text('${e.name} (${e.admissionNo})', overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: _studentPicked,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtrl,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Login username *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Login password *',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.casino_outlined),
                  tooltip: 'Generate',
                  onPressed: () => setState(() => _passCtrl.text = _randomPassword()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Rights (what he can do)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            for (final e in crRightLabels.entries)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _rights.contains(e.key),
                onChanged: (v) => setState(() { if (v == true) { _rights.add(e.key); } else { _rights.remove(e.key); } }),
                title: Text(e.value),
              ),
            if (s != null && s.hasBatch)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _limit,
                onChanged: (v) => setState(() => _limit = v ?? true),
                title: Text('Only the ${s.batchName ?? 'student\'s'} batch', style: const TextStyle(fontSize: 14)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.shield_outlined),
              label: const Text('Make CR'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.service, required this.rep});
  final ClassRepService service;
  final ClassRep rep;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late bool _active = widget.rep.isActive;
  late bool _limit = widget.rep.limitToBatch;
  late final Set<String> _rights = {...widget.rep.rights};
  final _passCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pass = _passCtrl.text.trim();
    if (pass.isNotEmpty && pass.length < 4) { setState(() => _error = 'Password: at least 4 characters.'); return; }
    if (_rights.isEmpty) { setState(() => _error = 'Tick at least one right.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.service.update(widget.rep.crId, limitToBatch: _limit, isActive: _active, newPassword: pass, rights: _rights.toList());
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _saving = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not save. Please try again.'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rep;
    return AlertDialog(
      title: Text(r.studentName, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.classLabel}\nLogin: ${r.username}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('CR access is ON'),
            ),
            for (final e in crRightLabels.entries)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _rights.contains(e.key),
                onChanged: (v) => setState(() { if (v == true) { _rights.add(e.key); } else { _rights.remove(e.key); } }),
                title: Text(e.value),
              ),
            if (r.hasBatch)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _limit,
                onChanged: (v) => setState(() => _limit = v ?? true),
                title: const Text('Only his own batch'),
              ),
            TextField(
              controller: _passCtrl,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'New password (blank = keep)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
