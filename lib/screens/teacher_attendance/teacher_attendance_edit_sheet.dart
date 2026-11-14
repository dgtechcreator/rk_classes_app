import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../models/teacher_attendance.dart';
import '../../services/teacher_attendance_service.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/common.dart';

/// Edit one teacher attendance entry (teacher, class, medium, batch, date, in / out time, subject, topic).
/// Resolves to true when saved. The teacher is notified by the server (what changed, who did it, when).
Future<bool> showTeacherAttendanceEditSheet(BuildContext context, TeacherAttendance entry) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EditSheet(entry: entry),
  );
  return saved == true;
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.entry});
  final TeacherAttendance entry;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _service = TeacherAttendanceService();
  final _subject = TextEditingController();
  final _topic = TextEditingController();
  TeacherAttendanceIndexData? _lookups;
  bool _loading = true;
  bool _saving = false;
  int? _facultyId, _classId, _sectionId, _batchId;
  late DateTime _date;
  TimeOfDay? _in, _out;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _facultyId = e.facultyId;
    _classId = e.classId;
    _sectionId = e.sectionId;
    _batchId = e.batchId;
    _date = e.attendanceDate;
    _subject.text = e.subjectName ?? '';
    _topic.text = e.topic ?? '';
    _in = _parse(e.inTime);
    _out = _parse(e.outTime);
    _service.getIndex().then((d) { if (mounted) setState(() { _lookups = d; _loading = false; }); }).catchError((_) { if (mounted) setState(() => _loading = false); });
  }

  @override
  void dispose() {
    _subject.dispose();
    _topic.dispose();
    super.dispose();
  }

  static TimeOfDay? _parse(String? t) {
    if (t == null || t.length < 5) return null;
    final h = int.tryParse(t.substring(0, 2)), m = int.tryParse(t.substring(3, 5));
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  static String? _fmt(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isIn) async {
    final picked = await showTimePicker(context: context, initialTime: (isIn ? _in : _out) ?? TimeOfDay.now());
    if (picked != null) setState(() { if (isIn) { _in = picked; } else { _out = picked; } });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_facultyId == null) { showSnack(context, 'Choose the teacher.', isError: true); return; }
    setState(() => _saving = true);
    try {
      await _service.update(
        widget.entry.attendanceId,
        facultyId: _facultyId!,
        classId: _classId,
        batchId: _batchId,
        sectionId: _sectionId,
        subject: _subject.text.trim(),
        topic: _topic.text.trim(),
        attendanceDate: DateFormat('yyyy-MM-dd').format(_date),
        inTime: _fmt(_in),
        outTime: _fmt(_out),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) { setState(() => _saving = false); showSnack(context, e.message, isError: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _lookups;
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: _loading
          ? const SizedBox(height: 160, child: LoadingView())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Edit attendance entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('The teacher gets a notification with what changed, who did it and when.', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                  const SizedBox(height: 14),
                  if (l != null) ...[
                    AppDropdown<int?>(
                      initialValue: _facultyId,
                      alwaysSearch: true,
                      decoration: const InputDecoration(labelText: 'Teacher'),
                      items: [for (final t in l.teachers) DropdownMenuItem<int?>(value: t.id, child: Text(t.name))],
                      onChanged: (v) => setState(() => _facultyId = v),
                    ),
                    const SizedBox(height: 12),
                    AppDropdown<int?>(
                      initialValue: l.classes.any((e) => e.id == _classId) ? _classId : null,
                      decoration: const InputDecoration(labelText: 'Class'),
                      items: [const DropdownMenuItem<int?>(value: null, child: Text('-')), for (final c in l.classes) DropdownMenuItem<int?>(value: c.id, child: Text(c.name))],
                      onChanged: (v) => setState(() => _classId = v),
                    ),
                    const SizedBox(height: 12),
                    AppDropdown<int?>(
                      initialValue: l.sections.any((e) => e.id == _sectionId) ? _sectionId : null,
                      decoration: const InputDecoration(labelText: 'Stream / Medium'),
                      items: [const DropdownMenuItem<int?>(value: null, child: Text('-')), for (final c in l.sections) DropdownMenuItem<int?>(value: c.id, child: Text(c.name))],
                      onChanged: (v) => setState(() => _sectionId = v),
                    ),
                    const SizedBox(height: 12),
                    AppDropdown<int?>(
                      initialValue: l.batches.any((e) => e.id == _batchId) ? _batchId : null,
                      decoration: const InputDecoration(labelText: 'Batch'),
                      items: [const DropdownMenuItem<int?>(value: null, child: Text('-')), for (final c in l.batches) DropdownMenuItem<int?>(value: c.id, child: Text(c.name))],
                      onChanged: (v) => setState(() => _batchId = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)), child: Text(DateFormat.yMMMd().format(_date))),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: InkWell(onTap: () => _pickTime(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'In time', suffixIcon: Icon(Icons.access_time, size: 18)), child: Text(_in == null ? 'Not set' : _in!.format(context))))),
                    const SizedBox(width: 12),
                    Expanded(child: InkWell(onTap: () => _pickTime(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'Out time', suffixIcon: Icon(Icons.access_time, size: 18)), child: Text(_out == null ? 'Not set' : _out!.format(context))))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
                  const SizedBox(height: 12),
                  TextField(controller: _topic, maxLines: 2, decoration: const InputDecoration(labelText: 'Topic', alignLabelWithHint: true)),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save changes'),
                  ),
                ],
              ),
            ),
    );
  }
}
