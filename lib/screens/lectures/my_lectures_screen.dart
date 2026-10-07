import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/lecture.dart';
import '../../services/lecture_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/lecture_widgets.dart';

/// A teacher's own lectures: what is coming up, which classes they are in, how many they have taken this month and
/// last month, and a one-tap "Mark done" for lectures that have happened. Only ever loads the caller's own
/// faculty profile's lectures (no id is sent).
class MyLecturesScreen extends StatefulWidget {
  const MyLecturesScreen({super.key});

  @override
  State<MyLecturesScreen> createState() => _MyLecturesScreenState();
}

class _MyLecturesScreenState extends State<MyLecturesScreen> {
  final _service = LectureService();
  MyLectures? _data;
  bool _loading = true;
  String? _error;
  String _range = 'upcoming';

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) get _dates {
    final t = DateUtils.dateOnly(DateTime.now());
    return switch (_range) {
      'month' => (DateTime(t.year, t.month, 1), DateTime(t.year, t.month + 1, 0)),
      'last' => (DateTime(t.year, t.month - 1, 1), DateTime(t.year, t.month, 0)),
      'week' => (t.subtract(Duration(days: t.weekday - 1)), t.subtract(Duration(days: t.weekday - 1)).add(const Duration(days: 6))),
      _ => (t, t.add(const Duration(days: 30))),
    };
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final (from, to) = _dates;
      final d = await _service.mine(from: from, to: to);
      if (mounted) setState(() { _data = d; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _mark(Lecture l, String status) async {
    try {
      await _service.setStatus(l.lectureId, status);
      if (mounted) { showSnack(context, status == 'Completed' ? 'Marked as completed.' : 'Back to scheduled.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Lectures')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _data!.linked
                  ? _content(_data!)
                  : EmptyState(message: _data!.message ?? 'Your login is not linked to a faculty profile yet.', icon: Icons.link_off),
    );
  }

  Widget _content(MyLectures d) {
    final today = DateUtils.dateOnly(DateTime.now());
    final children = <Widget>[
      if (d.thisMonth != null) MonthCountsCard(month: d.thisMonth!, showClasses: true),
      const SizedBox(height: 10),
      if (d.lastMonth != null) MonthCountsCard(month: d.lastMonth!, showClasses: true),
      const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final r in const [('upcoming', 'Upcoming'), ('week', 'This week'), ('month', 'This month'), ('last', 'Last month')])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(r.$2), selected: _range == r.$1, onSelected: (_) { setState(() => _range = r.$1); _load(); }),
            ),
        ]),
      ),
    ];

    if (d.lectures.isEmpty) {
      children.add(const EmptyState(message: 'No lectures in this period.', icon: Icons.event_busy_outlined));
    }
    DateTime? cur;
    for (final l in d.lectures) {
      if (cur == null || !DateUtils.isSameDay(cur, l.date)) {
        cur = l.date;
        children.add(LectureDayHeader(l.date));
      }
      final canMark = l.status == 'Scheduled' && !DateUtils.dateOnly(l.date).isAfter(today);
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: LectureCard(
          lecture: l,
          showTeacher: false,
          footer: canMark
              ? Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _mark(l, 'Completed'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Mark done'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                  ),
                )
              : l.isCompleted
                  ? Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _mark(l, 'Scheduled'), child: const Text('Undo')))
                  : null,
        ),
      ));
    }

    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 32), children: children));
  }
}
