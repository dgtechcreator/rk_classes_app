import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../models/teacher_attendance.dart';
import '../../services/teacher_attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'teacher_attendance_summary_screen.dart';

class TeacherAttendanceMarkScreen extends StatefulWidget {
  const TeacherAttendanceMarkScreen({super.key});

  @override
  State<TeacherAttendanceMarkScreen> createState() => _TeacherAttendanceMarkScreenState();
}

class _TeacherAttendanceMarkScreenState extends State<TeacherAttendanceMarkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TeacherAttendanceService();
  final _subjectCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  bool _saving = false;

  List<LookupItem> _teachers = [];
  List<LookupItem> _classes = [];
  List<LookupItem> _batches = [];
  List<TeacherAttendance> _attendance = [];

  int? _facultyId;
  int? _classId;
  int? _batchId;
  DateTime _date = DateTime.now();
  TimeOfDay? _inTime;
  TimeOfDay? _outTime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getIndex();
      setState(() {
        _teachers = data.teachers;
        _classes = data.classes;
        _batches = data.batches;
        _attendance = data.attendance;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  String _formatTimeOfDay(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isIn}) async {
    final picked = await showTimePicker(context: context, initialTime: (isIn ? _inTime : _outTime) ?? TimeOfDay.now());
    if (picked == null) return;
    setState(() { if (isIn) { _inTime = picked; } else { _outTime = picked; } });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.save(
        facultyId: _facultyId!,
        classId: _classId,
        batchId: _batchId,
        subject: _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
        topic: _topicCtrl.text.trim().isEmpty ? null : _topicCtrl.text.trim(),
        attendanceDate: DateFormat('yyyy-MM-dd').format(_date),
        inTime: _inTime == null ? null : _formatTimeOfDay(_inTime!),
        outTime: _outTime == null ? null : _formatTimeOfDay(_outTime!),
      );
      if (mounted) {
        showSnack(context, 'Attendance recorded successfully.');
        setState(() { _subjectCtrl.clear(); _topicCtrl.clear(); _inTime = null; _outTime = null; });
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEntry(TeacherAttendance a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Remove attendance for ${a.facultyName} on ${DateFormat.yMMMd().format(a.attendanceDate)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(a.attendanceId);
      if (mounted) { showSnack(context, 'Attendance deleted.'); await _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Summary',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeacherAttendanceSummaryScreen())),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final entriesForDate = _attendance.where((a) => a.isOnDate(_date)).toList();
    final isToday = DateUtils.isSameDay(_date, DateTime.now());

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const SectionHeader(title: 'Mark Attendance'),
          _dropdown('Faculty *', _facultyId, _teachers, (v) => setState(() => _facultyId = v), validator: true),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dropdown('Class', _classId, _classes, (v) => setState(() => _classId = v))),
            const SizedBox(width: 12),
            Expanded(child: _dropdown('Batch', _batchId, _batches, (v) => setState(() => _batchId = v))),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
          const SizedBox(height: 12),
          TextFormField(controller: _topicCtrl, decoration: const InputDecoration(labelText: 'Topic')),
          const SizedBox(height: 12),
          _dateField('Date', _date, _pickDate),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _timeField('In Time', _inTime, () => _pickTime(isIn: true))),
            const SizedBox(width: 12),
            Expanded(child: _timeField('Out Time', _outTime, () => _pickTime(isIn: false))),
          ]),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Attendance'),
          ),
          const SizedBox(height: 28),
          SectionHeader(title: isToday ? "Today's Entries" : 'Entries on ${DateFormat.yMMMd().format(_date)}'),
          if (entriesForDate.isEmpty)
            const EmptyState(message: 'No attendance marked for this date yet.', icon: Icons.event_busy_outlined)
          else
            ...entriesForDate.map((a) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Text(a.facultyName.isNotEmpty ? a.facultyName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(a.facultyName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (a.classBatchLabel.isNotEmpty) a.classBatchLabel,
                      if ((a.subjectName ?? '').isNotEmpty) a.subjectName!,
                      if ((a.topic ?? '').isNotEmpty) a.topic!,
                      if (a.inTimeDisplay != null || a.outTimeDisplay != null) '${a.inTimeDisplay ?? '--'} - ${a.outTimeDisplay ?? '--'}',
                      if (a.totalHours != null) '${a.totalHours!.toStringAsFixed(2)} hrs',
                    ].where((e) => e.isNotEmpty).join(' • ')),
                    isThreeLine: false,
                    trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _deleteEntry(a)),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _dropdown(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged, {bool validator = false}) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      validator: validator ? (v) => v == null ? 'Required' : null : null,
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
        child: Text(DateFormat.yMMMd().format(value)),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.access_time, size: 18)),
        child: Text(value == null ? 'Not set' : value.format(context), style: TextStyle(color: value == null ? AppColors.textSecondary : null)),
      ),
    );
  }
}
