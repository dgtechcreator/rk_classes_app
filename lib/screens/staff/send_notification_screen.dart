import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../services/lookup_service.dart';
import '../../services/notify_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/common.dart';

/// Admin: send a notification to everybody, to all students / staff / teachers, to one class (+ medium, batch),
/// or to particular students / particular staff. Students and parents see it in their notifications, staff in theirs.
class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _Aud {
  const _Aud(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

const _audiences = [
  _Aud('everyone', 'Everybody', Icons.groups_rounded),
  _Aud('students', 'All students', Icons.school_rounded),
  _Aud('staff', 'All staff', Icons.badge_rounded),
  _Aud('teachers', 'All teachers', Icons.co_present_rounded),
  _Aud('class', 'One class', Icons.class_rounded),
  _Aud('pick_students', 'Particular students', Icons.person_search_rounded),
  _Aud('pick_staff', 'Particular staff', Icons.how_to_reg_rounded),
];

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _notify = NotifyService();
  final _lookup = LookupService();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _stuQ = TextEditingController();
  final _stfQ = TextEditingController();

  String _aud = 'everyone';
  bool _sending = false;

  List<LookupItem> _classes = [], _sections = [], _batches = [];
  int? _classId, _sectionId, _batchId;

  final _pickedStudents = <int, NotifyPerson>{};
  List<NotifyPerson> _found = [];
  bool _searching = false;
  Timer? _debounce;
  int _searchSeq = 0;

  List<NotifyPerson> _staff = [];
  bool _staffLoaded = false;
  final _pickedStaff = <int>{};

  @override
  void initState() {
    super.initState();
    _lookup.getClasses().then((v) { if (mounted) setState(() => _classes = v.where((e) => e.isActive).toList()); }).catchError((_) {});
    _lookup.getSections().then((v) { if (mounted) setState(() => _sections = v.where((e) => e.isActive).toList()); }).catchError((_) {});
    _lookup.getBatches().then((v) { if (mounted) setState(() => _batches = v.where((e) => e.isActive).toList()); }).catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _message.dispose();
    _stuQ.dispose();
    _stfQ.dispose();
    super.dispose();
  }

  void _setAud(String a) {
    setState(() => _aud = a);
    if (a == 'pick_staff' && !_staffLoaded) {
      _notify.staff().then((v) { if (mounted) setState(() { _staff = v; _staffLoaded = true; }); }).catchError((e) {
        if (mounted) showSnack(context, e is ApiException ? e.message : 'Could not load the staff list.', isError: true);
      });
    }
  }

  void _onStudentQuery(String q) {
    _debounce?.cancel();
    final text = q.trim();
    if (text.length < 2) { setState(() { _found = []; _searching = false; }); return; }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final seq = ++_searchSeq;
      try {
        final r = await _notify.students(text);
        if (mounted && seq == _searchSeq) setState(() { _found = r; _searching = false; });
      } catch (_) {
        if (mounted && seq == _searchSeq) setState(() { _found = []; _searching = false; });
      }
    });
  }

  String get _audLabel => _audiences.firstWhere((a) => a.key == _aud).label;

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Write a title.';
    if (_message.text.trim().isEmpty) return 'Write the message.';
    if (_aud == 'class' && _classId == null) return 'Choose the class.';
    if (_aud == 'pick_students' && _pickedStudents.isEmpty) return 'Choose at least one student.';
    if (_aud == 'pick_staff' && _pickedStaff.isEmpty) return 'Choose at least one staff member.';
    return null;
  }

  Future<void> _send() async {
    final err = _validate();
    if (err != null) { showSnack(context, err, isError: true); return; }
    if (_aud == 'everyone' || _aud == 'students') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Send to everybody?'),
          content: Text(_aud == 'everyone'
              ? 'This goes to every active student & parent and every staff member.'
              : 'This goes to every active student & parent.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Send')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _sending = true);
    try {
      final r = await _notify.send(
        audience: _aud,
        title: _title.text.trim(),
        message: _message.text.trim(),
        classId: _classId,
        sectionId: _sectionId,
        batchId: _batchId,
        studentIds: _pickedStudents.keys.toList(),
        userIds: _pickedStaff.toList(),
      );
      if (!mounted) return;
      showSnack(context, r.message);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 14, 16, sheetBottomInset(context) + 24),
          children: [
            const Text('Send to', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final a in _audiences) _audChip(a)],
            ),
            const SizedBox(height: 14),
            if (_aud == 'class') _classPicker(),
            if (_aud == 'pick_students') _studentPicker(),
            if (_aud == 'pick_staff') _staffPicker(),
            const SizedBox(height: 6),
            TextField(controller: _title, maxLength: 150, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Title *', hintText: 'e.g. Holiday tomorrow')),
            const SizedBox(height: 8),
            TextField(controller: _message, maxLength: 900, maxLines: 5, minLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Message *', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending...' : 'Send to $_audLabel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audChip(_Aud a) {
    final on = _aud == a.key;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _setAud(a.key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? AppColors.primary : AppColors.borderNeutral, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(a.icon, size: 16, color: on ? Colors.white : AppColors.primary),
            const SizedBox(width: 6),
            Text(a.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: on ? Colors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _classPicker() {
    DropdownMenuItem<int?> item(int? v, String t) => DropdownMenuItem<int?>(value: v, child: Text(t, overflow: TextOverflow.ellipsis));
    return Column(
      children: [
        AppDropdown<int?>(
          value: _classId,
          decoration: const InputDecoration(labelText: 'Class *'),
          items: [item(null, '— Select —'), for (final c in _classes) item(c.id, c.name)],
          onChanged: (v) => setState(() => _classId = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppDropdown<int?>(
                value: _sectionId,
                decoration: const InputDecoration(labelText: 'Medium / stream'),
                items: [item(null, 'All'), for (final c in _sections) item(c.id, c.name)],
                onChanged: (v) => setState(() => _sectionId = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppDropdown<int?>(
                value: _batchId,
                decoration: const InputDecoration(labelText: 'Batch'),
                items: [item(null, 'All'), for (final c in _batches) item(c.id, c.name)],
                onChanged: (v) => setState(() => _batchId = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _studentPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListSearchField(controller: _stuQ, onChanged: _onStudentQuery, hint: 'Search student (name, father, mother, admission no)', padding: EdgeInsets.zero),
        if (_pickedStudents.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in _pickedStudents.values)
                InputChip(
                  label: Text(p.label.split(' · ').first, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onDeleted: () => setState(() => _pickedStudents.remove(p.id)),
                ),
            ],
          ),
        ],
        if (_searching) const Padding(padding: EdgeInsets.all(10), child: Text('Searching...', style: TextStyle(color: AppColors.textSecondary)))
        else if (_stuQ.text.trim().length >= 2 && _found.isEmpty)
          const Padding(padding: EdgeInsets.all(10), child: Text('No student found.', style: TextStyle(color: AppColors.textSecondary)))
        else
          for (final p in _found)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _pickedStudents.containsKey(p.id),
              title: Text(p.label, style: const TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() { if (v == true) { _pickedStudents[p.id] = p; } else { _pickedStudents.remove(p.id); } }),
            ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _staffPicker() {
    final list = _staff.where((s) => matchesSearch(_stfQ.text, [s.label, s.sub])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListSearchField(controller: _stfQ, onChanged: (_) => setState(() {}), hint: 'Search staff', padding: EdgeInsets.zero),
        if (!_staffLoaded) const Padding(padding: EdgeInsets.all(14), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (list.isEmpty) const Padding(padding: EdgeInsets.all(10), child: Text('No staff found.', style: TextStyle(color: AppColors.textSecondary)))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in list)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _pickedStaff.contains(s.id),
                    title: Text(s.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    subtitle: s.sub.isEmpty ? null : Text(s.sub, style: const TextStyle(fontSize: 12)),
                    onChanged: (v) => setState(() { if (v == true) { _pickedStaff.add(s.id); } else { _pickedStaff.remove(s.id); } }),
                  ),
              ],
            ),
          ),
        if (_pickedStaff.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_pickedStaff.length} selected', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary))),
        const SizedBox(height: 10),
      ],
    );
  }
}
