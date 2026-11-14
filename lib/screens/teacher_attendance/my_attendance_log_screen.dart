import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/teacher_attendance.dart';
import '../../services/teacher_attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// A teacher's own attendance log: every entry, with the deleted ones marked (who deleted it and when) and the edited
/// ones (who edited it and when). Read only. Opens from the "entry deleted / edited" notification too.
class MyAttendanceLogScreen extends StatefulWidget {
  const MyAttendanceLogScreen({super.key});

  @override
  State<MyAttendanceLogScreen> createState() => _MyAttendanceLogScreenState();
}

class _MyAttendanceLogScreenState extends State<MyAttendanceLogScreen> {
  final _service = TeacherAttendanceService();
  final _search = TextEditingController();
  String _q = '';
  bool _loading = true;
  String? _error;
  bool _linked = true;
  String? _message;
  List<TeacherAttendance> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = _entries.isEmpty; _error = null; });
    try {
      final r = await _service.myLog();
      if (mounted) setState(() { _linked = r.linked; _message = r.message; _entries = r.entries; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _entries.where((a) => matchesSearch(_q, [a.subjectName, a.topic, a.fullLabel, DateFormat('d MMM yyyy').format(a.attendanceDate)])).toList();
    final deleted = _entries.where((a) => a.isDeleted).length;
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : !_linked
                  ? EmptyState(message: _message ?? 'Your login is not linked to a faculty profile yet.', icon: Icons.link_off_rounded)
                  : Column(children: [
                      ListSearchField(controller: _search, onChanged: (v) => setState(() => _q = v), hint: 'Search subject, class, date...'),
                      if (deleted > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Align(alignment: Alignment.centerLeft, child: Text('$deleted deleted ${deleted == 1 ? 'entry' : 'entries'} - shown in red with who deleted it and when.', style: const TextStyle(fontSize: 12, color: AppColors.danger))),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: shown.isEmpty
                              ? ListView(children: const [SizedBox(height: 60), EmptyState(message: 'No attendance entries found.', icon: Icons.event_busy_outlined)])
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                  itemCount: shown.length,
                                  itemBuilder: (_, i) => _tile(shown[i]),
                                ),
                        ),
                      ),
                    ]),
    );
  }

  Widget _tile(TeacherAttendance a) {
    final dt = DateFormat('d MMM yyyy, h:mm a');
    final del = a.isDeleted;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: del ? AppColors.dangerSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                DateFormat('EEE, d MMM yyyy').format(a.attendanceDate),
                style: TextStyle(fontWeight: FontWeight.w800, decoration: del ? TextDecoration.lineThrough : null),
              ),
            ),
            if (a.isAuto) const _Tag('Auto', AppColors.info),
            if (del) const _Tag('Deleted', AppColors.danger),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              if (a.fullLabel.isNotEmpty) a.fullLabel,
              if ((a.subjectName ?? '').isNotEmpty) a.subjectName!,
              if (a.inTimeDisplay != null || a.outTimeDisplay != null) '${a.inTimeDisplay ?? '--'} - ${a.outTimeDisplay ?? '--'}',
              if (a.totalHours != null) '${a.totalHours!.toStringAsFixed(2)} hrs',
            ].join(' • '),
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          if (del)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Deleted by ${(a.deletedByName ?? '').isEmpty ? 'the admin' : a.deletedByName}${a.deletedAt == null ? '' : ' on ${dt.format(a.deletedAt!)}'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger),
              ),
            )
          else if (a.updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Edited by ${(a.updatedByName ?? '').isEmpty ? 'the admin' : a.updatedByName} on ${dt.format(a.updatedAt!)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}
