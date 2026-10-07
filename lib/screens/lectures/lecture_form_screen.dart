import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/lecture.dart';
import '../../services/lecture_service.dart';
import '../../widgets/common.dart';

/// Create or edit one lecture. For a new lecture "Repeat every week" creates one lecture per chosen weekday up
/// to the end date (the server rejects the whole batch if anything clashes with an existing lecture).
class LectureFormScreen extends StatefulWidget {
  const LectureFormScreen({super.key, required this.options, this.lecture, this.initialDate});
  final LectureOptions options;
  final Lecture? lecture;
  final DateTime? initialDate;

  @override
  State<LectureFormScreen> createState() => _LectureFormScreenState();
}

class _LectureFormScreenState extends State<LectureFormScreen> {
  final _service = LectureService();
  final _topic = TextEditingController();
  final _remarks = TextEditingController();

  late DateTime _date;
  TimeOfDay? _start, _end;
  int? _classId, _sectionId, _batchId, _facultyId;
  String? _subject;
  bool _repeat = false;
  final Set<int> _days = {};
  DateTime? _until;
  bool _saving = false;

  bool get _isEdit => widget.lecture != null;

  static const _weekdays = [(1, 'Mon'), (2, 'Tue'), (3, 'Wed'), (4, 'Thu'), (5, 'Fri'), (6, 'Sat'), (0, 'Sun')];

  @override
  void initState() {
    super.initState();
    final l = widget.lecture;
    _date = DateUtils.dateOnly(l?.date ?? widget.initialDate ?? DateTime.now());
    if (l != null) {
      _start = _parse(l.startTime);
      _end = _parse(l.endTime);
      _classId = l.classId;
      _sectionId = l.sectionId;
      _batchId = l.batchId;
      _facultyId = l.facultyId;
      _subject = l.subject;
      _topic.text = l.topic ?? '';
      _remarks.text = l.remarks ?? '';
    }
  }

  @override
  void dispose() {
    _topic.dispose();
    _remarks.dispose();
    super.dispose();
  }

  TimeOfDay? _parse(String v) {
    final p = v.split(':');
    if (p.length < 2) return null;
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(DateTime initial, ValueChanged<DateTime> onPicked, {DateTime? first}) async {
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: first ?? DateTime(2024), lastDate: DateTime(2030));
    if (d != null) onPicked(DateUtils.dateOnly(d));
  }

  Future<void> _pickTime(TimeOfDay? initial, ValueChanged<TimeOfDay> onPicked) async {
    final t = await showTimePicker(context: context, initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0));
    if (t != null) onPicked(t);
  }

  Future<void> _save() async {
    String? problem;
    if (_classId == null) {
      problem = 'Select a class.';
    } else if (_subject == null) {
      problem = 'Select a subject.';
    } else if (_facultyId == null) {
      problem = 'Select a teacher.';
    } else if (_start == null || _end == null) {
      problem = 'Pick the start and end time.';
    } else if (_end!.hour * 60 + _end!.minute <= _start!.hour * 60 + _start!.minute) {
      problem = 'End time must be after the start time.';
    } else if (_repeat && _days.isEmpty) {
      problem = 'Pick at least one weekday to repeat on.';
    } else if (_repeat && _until == null) {
      problem = 'Choose the date until which it repeats.';
    }
    if (problem != null) {
      showSnack(context, problem, isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final msg = await _service.save(
        lectureId: widget.lecture?.lectureId ?? 0,
        date: _date,
        startTime: _fmt(_start!),
        endTime: _fmt(_end!),
        classId: _classId!,
        sectionId: _sectionId,
        batchId: _batchId,
        subject: _subject!,
        facultyId: _facultyId!,
        topic: _topic.text.trim().isEmpty ? null : _topic.text.trim(),
        remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
        repeatDays: _repeat ? _days.toList() : const [],
        repeatUntil: _until,
      );
      if (!mounted) return;
      showSnack(context, msg);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _idDrop(String label, int? value, List<IdName> items, ValueChanged<int?> onChanged, {String allLabel = 'All', bool required = false}) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: required ? '$label *' : label),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(required ? '— Select —' : allLabel)),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name.trim(), overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _timeField(String label, TimeOfDay? v, ValueChanged<TimeOfDay> onPicked) => InkWell(
        onTap: () => _pickTime(v, (t) => setState(() => onPicked(t))),
        child: InputDecorator(
          decoration: InputDecoration(labelText: '$label *', suffixIcon: const Icon(Icons.access_time, size: 18)),
          child: Text(v == null ? '—' : v.format(context)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Lecture' : 'Add Lecture')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          InkWell(
            onTap: () => _pickDate(_date, (d) => setState(() => _date = d)),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date *', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(DateFormat('EEEE, d MMM yyyy').format(_date)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _timeField('Start', _start, (t) => _start = t)),
            const SizedBox(width: 12),
            Expanded(child: _timeField('End', _end, (t) => _end = t)),
          ]),
          const SizedBox(height: 12),
          _idDrop('Class', _classId, o.classes, (v) => setState(() => _classId = v), required: true),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _idDrop('Medium', _sectionId, o.sections, (v) => setState(() => _sectionId = v), allLabel: 'All mediums')),
            const SizedBox(width: 12),
            Expanded(child: _idDrop('Batch', _batchId, o.batches, (v) => setState(() => _batchId = v), allLabel: 'All batches')),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: o.subjects.contains(_subject) ? _subject : null,
            decoration: const InputDecoration(labelText: 'Subject *'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('— Select —')),
              ...o.subjects.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _subject = v),
          ),
          const SizedBox(height: 12),
          _idDrop('Teacher', _facultyId, o.teachers, (v) => setState(() => _facultyId = v), required: true),
          const SizedBox(height: 12),
          TextField(controller: _topic, maxLength: 200, decoration: const InputDecoration(labelText: 'Topic (optional)', counterText: '')),
          const SizedBox(height: 12),
          TextField(controller: _remarks, maxLength: 300, decoration: const InputDecoration(labelText: 'Remarks (optional)', counterText: '')),
          if (!_isEdit) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _repeat,
              onChanged: (v) => setState(() => _repeat = v),
              title: const Text('Repeat every week', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Create the same lecture on chosen weekdays'),
            ),
            if (_repeat) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final d in _weekdays)
                    FilterChip(
                      label: Text(d.$2),
                      selected: _days.contains(d.$1),
                      onSelected: (s) => setState(() => s ? _days.add(d.$1) : _days.remove(d.$1)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickDate(_until ?? _date.add(const Duration(days: 30)), (d) => setState(() => _until = d), first: _date),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Repeat until *', suffixIcon: Icon(Icons.event_repeat, size: 18)),
                  child: Text(_until == null ? '—' : DateFormat('d MMM yyyy').format(_until!)),
                ),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isEdit ? 'Save Changes' : (_repeat ? 'Schedule Lectures' : 'Schedule Lecture')),
          ),
        ),
      ),
    );
  }
}
