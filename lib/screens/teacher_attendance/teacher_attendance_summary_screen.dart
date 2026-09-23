import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/teacher_attendance.dart';
import '../../services/teacher_attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class _FacultyAgg {
  _FacultyAgg(this.facultyId, this.facultyName);
  final int facultyId;
  final String facultyName;
  double totalHours = 0;
  int entries = 0;
  final Set<String> days = {};
}

class TeacherAttendanceSummaryScreen extends StatefulWidget {
  const TeacherAttendanceSummaryScreen({super.key});

  @override
  State<TeacherAttendanceSummaryScreen> createState() => _TeacherAttendanceSummaryScreenState();
}

class _TeacherAttendanceSummaryScreenState extends State<TeacherAttendanceSummaryScreen> {
  final _service = TeacherAttendanceService();
  bool _loading = true;
  String? _error;
  List<TeacherAttendance> _all = [];

  int? _facultyId;
  int? _month;
  int? _year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getSummary();
      setState(() { _all = data.attendance; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  List<TeacherAttendance> get _filtered => _all.where((a) {
        if (_facultyId != null && a.facultyId != _facultyId) return false;
        if (_month != null && a.attendanceDate.month != _month) return false;
        if (_year != null && a.attendanceDate.year != _year) return false;
        return true;
      }).toList();

  List<_FacultyAgg> get _byFaculty {
    final map = <int, _FacultyAgg>{};
    for (final a in _filtered) {
      final agg = map.putIfAbsent(a.facultyId, () => _FacultyAgg(a.facultyId, a.facultyName));
      agg.entries++;
      agg.totalHours += a.totalHours ?? 0;
      agg.days.add(DateFormat('yyyy-MM-dd').format(a.attendanceDate));
    }
    final list = map.values.toList()..sort((x, y) => y.totalHours.compareTo(x.totalHours));
    return list;
  }

  Future<void> _openFilterSheet() async {
    final faculties = {for (final a in _all) a.facultyId: a.facultyName}.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final years = _all.map((a) => a.attendanceDate.year).toSet().toList()..sort((a, b) => b.compareTo(a));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SummaryFilterSheet(
        faculties: faculties, years: years,
        facultyId: _facultyId, month: _month, year: _year,
        onApply: (f, m, y) => setState(() { _facultyId = f; _month = m; _year = y; }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _facultyId != null || _month != null || _year != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Summary'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: hasFilters ? AppColors.primary : null),
            tooltip: 'Filter',
            onPressed: _loading || _error != null ? null : _openFilterSheet,
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _all.isEmpty
                  ? const EmptyState(message: 'No attendance records yet.', icon: Icons.event_busy_outlined)
                  : RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final filtered = _filtered;
    final totalHours = filtered.fold<double>(0, (sum, a) => sum + (a.totalHours ?? 0));
    final totalDays = filtered.map((a) => DateFormat('yyyy-MM-dd').format(a.attendanceDate)).toSet().length;
    final byFaculty = _byFaculty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: StatCard(label: 'Total Hours', value: totalHours.toStringAsFixed(1), color: AppColors.info, icon: Icons.timer_outlined)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(label: 'Total Days', value: '$totalDays', color: AppColors.success, icon: Icons.event_available_outlined)),
        ]),
        const SizedBox(height: 20),
        const SectionHeader(title: 'By Faculty'),
        if (byFaculty.isEmpty)
          const EmptyState(message: 'No records for the selected filters.', icon: Icons.filter_alt_off_outlined)
        else
          ...byFaculty.map((f) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Text(f.facultyName.isNotEmpty ? f.facultyName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(f.facultyName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${f.days.length} day${f.days.length == 1 ? '' : 's'} • ${f.entries} ${f.entries == 1 ? 'entry' : 'entries'}'),
                  trailing: Text('${f.totalHours.toStringAsFixed(1)} hrs', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              )),
      ],
    );
  }
}

class _SummaryFilterSheet extends StatefulWidget {
  const _SummaryFilterSheet({
    required this.faculties, required this.years,
    required this.facultyId, required this.month, required this.year,
    required this.onApply,
  });
  final List<MapEntry<int, String>> faculties;
  final List<int> years;
  final int? facultyId, month, year;
  final void Function(int?, int?, int?) onApply;

  @override
  State<_SummaryFilterSheet> createState() => _SummaryFilterSheetState();
}

class _SummaryFilterSheetState extends State<_SummaryFilterSheet> {
  int? _facultyId, _month, _year;

  @override
  void initState() {
    super.initState();
    _facultyId = widget.facultyId; _month = widget.month; _year = widget.year;
  }

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filter Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
      isExpanded: true,
            initialValue: widget.faculties.any((e) => e.key == _facultyId) ? _facultyId : null,
            decoration: const InputDecoration(labelText: 'Faculty'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All')),
              ...widget.faculties.map((e) => DropdownMenuItem<int?>(value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) => setState(() => _facultyId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
      isExpanded: true,
            initialValue: _month,
            decoration: const InputDecoration(labelText: 'Month'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All')),
              ...List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem<int?>(value: m, child: Text(_months[m]))),
            ],
            onChanged: (v) => setState(() => _month = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
      isExpanded: true,
            initialValue: widget.years.contains(_year) ? _year : null,
            decoration: const InputDecoration(labelText: 'Year'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All')),
              ...widget.years.map((y) => DropdownMenuItem<int?>(value: y, child: Text('$y'))),
            ],
            onChanged: (v) => setState(() => _year = v),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() { _facultyId = null; _month = null; _year = null; }),
                child: const Text('Clear'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () { widget.onApply(_facultyId, _month, _year); Navigator.of(context).pop(); },
                child: const Text('Apply'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
