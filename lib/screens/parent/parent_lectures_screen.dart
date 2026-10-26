import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/parent_data_controller.dart';
import '../../models/lecture.dart';
import '../../services/lecture_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/lecture_widgets.dart';
import '../attendance/attendance_entry_screen.dart' show AttendanceDateBar;

/// Parent view: which lectures the child's class has on a day (pick any day — today, tomorrow, last week).
/// No monthly summary here — parents only see the schedule.
class ParentLecturesScreen extends StatefulWidget {
  const ParentLecturesScreen({super.key});

  @override
  State<ParentLecturesScreen> createState() => _ParentLecturesScreenState();
}

class _ParentLecturesScreenState extends State<ParentLecturesScreen> {
  final _service = LectureService();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  int? _studentId;
  ParentLectures? _data;
  bool _loading = false;
  String? _error;

  Future<void> _load(int studentId) async {
    final asked = _date;
    setState(() { _loading = true; _error = null; _studentId = studentId; });
    try {
      final d = await _service.forParent(studentId, asked);
      if (mounted && asked == _date && studentId == _studentId) setState(() { _data = d; _loading = false; });
    } on ApiException catch (e) {
      if (mounted && asked == _date) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _setDate(DateTime d, int studentId) {
    setState(() => _date = DateUtils.dateOnly(d));
    _load(studentId);
  }

  Future<void> _pick(int studentId) async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2024), lastDate: DateTime(2030));
    if (d != null) _setDate(d, studentId);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ParentDataController>();
    final child = ctrl.selected;
    // (Re)load when the shell has a child and we have not loaded for this one yet.
    if (child != null && _studentId != child.studentId && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(child.studentId); });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TabHeader(title: 'Lectures', subtitle: 'Daily schedule'),
            Expanded(
              child: child == null
                  ? (ctrl.loading ? const LoadingView() : const EmptyState(message: 'No children linked to this account yet.', icon: Icons.family_restroom))
                  : _body(child.studentId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(int studentId) {
    return RefreshIndicator(
      onRefresh: () => _load(studentId),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 32),
        children: [
          AttendanceDateBar(date: _date, allowFuture: true, onChanged: (d) => _setDate(d, studentId), onPick: () => _pick(studentId)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _loading && _data == null
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: () => _load(studentId))
                    : _content(studentId),
          ),
        ],
      ),
    );
  }

  Widget _content(int studentId) {
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    final held = d.lectures.where((l) => l.isCompleted).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            d.lectures.isEmpty
                ? 'No lectures on this day'
                : '${d.lectures.where((l) => !l.isCancelled).length} lecture${d.lectures.where((l) => !l.isCancelled).length == 1 ? '' : 's'} • $held held',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        if (d.lectures.isEmpty)
          const EmptyState(message: 'No lectures scheduled for your child on this day.', icon: Icons.event_busy_outlined)
        else
          for (final l in d.lectures) Padding(padding: const EdgeInsets.only(bottom: 10), child: LectureCard(lecture: l, showGroup: false)),
      ],
    );
  }
}
