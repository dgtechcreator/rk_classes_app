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

/// Monthly attendance summary per student — mirrors AttendanceController.Report. Filter by
/// class/section/batch + month/year, see each student's present/absent/late/total, tap a student for
/// their day-by-day detail (built from the date-grid endpoint, scoped to the same filters and month).
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final _service = AttendanceService();
  final _lookup = LookupService();

  bool _loadingFilters = true;
  bool _loadingList = false;
  String? _filtersError;
  String? _listError;

  List<LookupItem> _classes = [], _sections = [], _batches = [];
  int? _classId, _sectionId, _batchId;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  List<AttendanceReportRow> _report = [];

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
      // Don't auto-load a whole-school report — with no class filter this queries every student for
      // the whole month at once, which is slow enough to hit the client's receive timeout. Wait for the
      // user to pick a class via the filter sheet instead (same pattern as AttendanceMarkScreen).
    } on ApiException catch (e) {
      if (mounted) setState(() { _filtersError = e.message; _loadingFilters = false; });
    }
  }

  Future<void> _load() async {
    setState(() { _loadingList = true; _listError = null; });
    try {
      final result = await _service.getReport(classId: _classId, sectionId: _sectionId, batchId: _batchId, month: _month, year: _year);
      if (!mounted) return;
      setState(() { _report = result.report; _loadingList = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _listError = e.message; _loadingList = false; });
    }
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        classes: _classes, sections: _sections, batches: _batches,
        classId: _classId, sectionId: _sectionId, batchId: _batchId, month: _month, year: _year,
        onApply: (classId, sectionId, batchId, month, year) {
          setState(() { _classId = classId; _sectionId = sectionId; _batchId = batchId; _month = month; _year = year; });
          _load();
        },
      ),
    );
  }

  Future<void> _openDetail(AttendanceReportRow row) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _StudentAttendanceDetailScreen(
        studentId: row.studentId,
        studentName: row.fullName,
        classId: _classId,
        sectionId: _sectionId,
        batchId: _batchId,
        month: _month,
        year: _year,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.hasPerm('attendance_report')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Report')),
        body: const EmptyState(message: 'You do not have permission to view attendance reports.', icon: Icons.lock_outline),
      );
    }

    final hasFilters = _classId != null || _sectionId != null || _batchId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Report — ${DateFormat.MMMM().format(DateTime(_year, _month))} $_year'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: hasFilters ? AppColors.primary : null),
            tooltip: 'Filter',
            onPressed: _loadingFilters ? null : _openFilterSheet,
          ),
        ],
      ),
      body: _loadingFilters
          ? const LoadingView()
          : _filtersError != null
              ? ErrorView(message: _filtersError!, onRetry: _loadFilters)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingList) return const LoadingView();
    if (_listError != null) return ErrorView(message: _listError!, onRetry: _load);
    if (_classId == null && _sectionId == null && _batchId == null && _report.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_list, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text('Choose a class to load its attendance report.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _openFilterSheet, child: const Text('Choose Filter')),
            ],
          ),
        ),
      );
    }
    if (_report.isEmpty) return const EmptyState(message: 'No attendance records for this filter.', icon: Icons.event_busy_outlined);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _report.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final row = _report[i];
          final pctColor = row.attendancePct >= 75 ? AppColors.success : (row.attendancePct >= 50 ? AppColors.warning : AppColors.danger);
          return Card(
            child: ListTile(
              onTap: () => _openDetail(row),
              title: Text(row.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${row.admissionNo} • ${row.className ?? ''}\nP:${row.presentDays} A:${row.absentDays} L:${row.lateDays} / ${row.totalDays} days'),
              isThreeLine: true,
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${row.attendancePct.toStringAsFixed(0)}%', style: TextStyle(color: pctColor, fontWeight: FontWeight.w700, fontSize: 16)),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.classes, required this.sections, required this.batches,
    required this.classId, required this.sectionId, required this.batchId, required this.month, required this.year,
    required this.onApply,
  });
  final List<LookupItem> classes, sections, batches;
  final int? classId, sectionId, batchId;
  final int month, year;
  final void Function(int?, int?, int?, int, int) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  int? _classId, _sectionId, _batchId;
  late int _month, _year;

  @override
  void initState() {
    super.initState();
    _classId = widget.classId; _sectionId = widget.sectionId; _batchId = widget.batchId;
    _month = widget.month; _year = widget.year;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filter Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _dropdown('Class', _classId, widget.classes, (v) => setState(() => _classId = v)),
          const SizedBox(height: 12),
          _dropdown('Section', _sectionId, widget.sections, (v) => setState(() => _sectionId = v)),
          const SizedBox(height: 12),
          _dropdown('Batch', _batchId, widget.batches, (v) => setState(() => _batchId = v)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
      isExpanded: true,
                  initialValue: _month,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(value: m, child: Text(DateFormat.MMMM().format(DateTime(_year, m)))))
                      .toList(),
                  onChanged: (v) => setState(() => _month = v ?? _month),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
      isExpanded: true,
                  initialValue: _year,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: List.generate(6, (i) => DateTime.now().year - i)
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) => setState(() => _year = v ?? _year),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _classId = null; _sectionId = null; _batchId = null;
                    _month = DateTime.now().month; _year = DateTime.now().year;
                  }),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { widget.onApply(_classId, _sectionId, _batchId, _month, _year); Navigator.of(context).pop(); },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))),
      ],
      onChanged: onChanged,
    );
  }
}

/// Day-by-day detail for one student in one month — built from the date-grid endpoint (the API has no
/// dedicated per-student attendance-history route), filtered client-side to this student's rows.
class _StudentAttendanceDetailScreen extends StatefulWidget {
  const _StudentAttendanceDetailScreen({
    required this.studentId, required this.studentName,
    this.classId, this.sectionId, this.batchId, required this.month, required this.year,
  });
  final int studentId;
  final String studentName;
  final int? classId, sectionId, batchId;
  final int month, year;

  @override
  State<_StudentAttendanceDetailScreen> createState() => _StudentAttendanceDetailScreenState();
}

class _StudentAttendanceDetailScreenState extends State<_StudentAttendanceDetailScreen> {
  final _service = AttendanceService();
  bool _loading = true;
  String? _error;
  List<DateAttendanceEntry> _days = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final from = DateTime(widget.year, widget.month, 1);
      final to = DateTime(widget.year, widget.month + 1, 0);
      final grid = await _service.getDateGrid(classId: widget.classId, sectionId: widget.sectionId, batchId: widget.batchId, fromDate: from, toDate: to);
      if (!mounted) return;
      setState(() { _days = grid.forStudent(widget.studentId); _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.studentName)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _days.isEmpty
                  ? const EmptyState(message: 'No attendance marked in this month.', icon: Icons.event_busy_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _days.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final day = _days[i];
                          return Card(
                            child: ListTile(
                              dense: true,
                              title: Text(DateFormat.yMMMEd().format(day.attendanceDate)),
                              trailing: StatusBadge(status: day.status),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
