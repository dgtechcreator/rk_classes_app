import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/attendance.dart';
import '../../models/lookup.dart';
import '../../services/attendance_service.dart';
import '../../services/lookup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'attendance_report_screen.dart';

/// Daily "take attendance" flow — mirrors AttendanceController.Index + Save. Pick a date and a
/// class/section/batch, get every student in that combo defaulted to Present, tap each student's chip
/// row to change their status, then Save All posts the batch in one AttSaveReq.
class AttendanceMarkScreen extends StatefulWidget {
  const AttendanceMarkScreen({super.key});

  @override
  State<AttendanceMarkScreen> createState() => _AttendanceMarkScreenState();
}

class _AttendanceMarkScreenState extends State<AttendanceMarkScreen> {
  final _service = AttendanceService();
  final _lookup = LookupService();

  bool _loadingFilters = true;
  bool _loadingList = false;
  bool _saving = false;
  String? _filtersError;
  String? _listError;

  List<LookupItem> _classes = [], _sections = [], _batches = [];
  DateTime _date = DateTime.now();
  int? _classId, _sectionId, _batchId;

  List<AttendanceRecord> _records = [];
  final Map<int, String> _statuses = {};

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    setState(() { _loadingFilters = true; _filtersError = null; });
    try {
      final classes = await _lookup.getClasses();
      final sections = await _lookup.getSections();
      final batches = await _lookup.getBatches();
      if (!mounted) return;
      setState(() { _classes = classes; _sections = sections; _batches = batches; _loadingFilters = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _filtersError = e.message; _loadingFilters = false; });
    }
  }

  Future<void> _load() async {
    if (_classId == null) {
      setState(() { _records = []; _statuses.clear(); _listError = null; });
      return;
    }
    setState(() { _loadingList = true; _listError = null; });
    try {
      final result = await _service.getForDate(date: _date, classId: _classId, sectionId: _sectionId, batchId: _batchId);
      if (!mounted) return;
      setState(() {
        _records = result.records;
        _statuses
          ..clear()
          ..addEntries(result.records.map((r) => MapEntry(r.studentId, r.attendanceStatus)));
        _loadingList = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _listError = e.message; _loadingList = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked == null) return;
    setState(() => _date = picked);
    _load();
  }

  void _setStatus(int studentId, String status) => setState(() => _statuses[studentId] = status);

  int get _presentCount => _statuses.values.where((s) => s == 'Present').length;
  int get _absentCount => _statuses.values.where((s) => s == 'Absent').length;
  int get _lateCount => _statuses.values.where((s) => s == 'Late').length;

  Future<void> _saveAll() async {
    if (_records.isEmpty) return;
    setState(() => _saving = true);
    try {
      final message = await _service.save(
        date: _date,
        classId: _classId,
        sectionId: _sectionId,
        batchId: _batchId,
        entries: _records
            .map((r) => {'studentId': r.studentId, 'status': _statuses[r.studentId] ?? 'Present', 'remarks': null})
            .toList(),
      );
      if (mounted) {
        showSnack(context, message);
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.hasPerm('attendance_entry')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Take Attendance')),
        body: const EmptyState(message: 'You do not have permission to take attendance.', icon: Icons.lock_outline),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        actions: [
          if (session.hasPerm('attendance_report'))
            IconButton(
              icon: const Icon(Icons.bar_chart_outlined),
              tooltip: 'Report',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceReportScreen())),
            ),
        ],
      ),
      body: _loadingFilters
          ? const LoadingView()
          : _filtersError != null
              ? ErrorView(message: _filtersError!, onRetry: _loadFilters)
              : Column(
                  children: [
                    _buildFilters(),
                    if (_records.isNotEmpty) _buildStats(),
                    Expanded(child: _buildBody()),
                  ],
                ),
      bottomNavigationBar: _records.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveAll,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save All (${_records.length})'),
                ),
              ),
            ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(DateFormat.yMMMd().format(_date)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dropdown('Class', _classId, _classes, (v) {
                  setState(() { _classId = v; _sectionId = null; _batchId = null; });
                  _load();
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown('Section', _sectionId, _sections, (v) {
                  setState(() => _sectionId = v);
                  _load();
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dropdown('Batch', _batchId, _batches, (v) {
            setState(() => _batchId = v);
            _load();
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _dropdown(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(child: StatCard(label: 'Present', value: '$_presentCount', color: AppColors.present, icon: Icons.check_circle_outline)),
          const SizedBox(width: 10),
          Expanded(child: StatCard(label: 'Absent', value: '$_absentCount', color: AppColors.absent, icon: Icons.cancel_outlined)),
          const SizedBox(width: 10),
          Expanded(child: StatCard(label: 'Late', value: '$_lateCount', color: AppColors.late, icon: Icons.schedule_outlined)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_classId == null) {
      return const EmptyState(message: 'Pick a class to load students.', icon: Icons.groups_outlined);
    }
    if (_loadingList) return const LoadingView();
    if (_listError != null) return ErrorView(message: _listError!, onRetry: _load);
    if (_records.isEmpty) {
      return const EmptyState(message: 'No students found for this class/section/batch.', icon: Icons.groups_outlined);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: _records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _StudentAttendanceTile(
          record: _records[i],
          status: _statuses[_records[i].studentId] ?? 'Present',
          onChanged: (s) => _setStatus(_records[i].studentId, s),
        ),
      ),
    );
  }
}

class _StudentAttendanceTile extends StatelessWidget {
  const _StudentAttendanceTile({required this.record, required this.status, required this.onChanged});
  final AttendanceRecord record;
  final String status;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Text(
                record.fullName.isNotEmpty ? record.fullName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.fullName, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  Text(record.rollNo?.isNotEmpty == true ? '${record.admissionNo} • Roll ${record.rollNo}' : record.admissionNo,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            _statusChip('P', 'Present', AppColors.present),
            const SizedBox(width: 6),
            _statusChip('A', 'Absent', AppColors.absent),
            const SizedBox(width: 6),
            _statusChip('L', 'Late', AppColors.late),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, String value, Color color) {
    final selected = status == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: selected ? 0 : 1),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}
