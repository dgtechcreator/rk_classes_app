import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/lecture.dart';
import '../../services/lecture_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/lecture_widgets.dart';
import 'lecture_form_screen.dart';
import 'lecture_summary_screen.dart';

/// Admin lecture schedule (mirrors the web Lecture Schedule page): lectures grouped by day with period chips and
/// class / medium / batch / subject / teacher / status filters. Staff with Edit permission can add, edit,
/// cancel, mark done and delete; View-only staff just read it.
class LectureListScreen extends StatefulWidget {
  const LectureListScreen({super.key, this.initialFilters});
  final LectureFilters? initialFilters;

  @override
  State<LectureListScreen> createState() => _LectureListScreenState();
}

class _LectureListScreenState extends State<LectureListScreen> {
  final _service = LectureService();

  late LectureFilters _f;
  LectureOptions? _options;
  LectureListResult? _result;
  bool _loading = true;
  String? _error;
  String _period = 'week';

  @override
  void initState() {
    super.initState();
    if (widget.initialFilters != null) {
      _f = widget.initialFilters!;
      _period = 'custom';
    } else {
      _f = LectureFilters();
      _applyPeriod('week', load: false);
    }
    _loadOptions();
    _load();
  }

  Future<void> _loadOptions() async {
    try {
      final o = await _service.getOptions();
      if (mounted) setState(() => _options = o);
    } on ApiException {
      // the filter / add buttons will retry when used
    }
  }

  void _applyPeriod(String p, {bool load = true}) {
    final t = DateUtils.dateOnly(DateTime.now());
    switch (p) {
      case 'today':
        _f.from = t;
        _f.to = t;
      case 'week':
        final start = t.subtract(Duration(days: t.weekday - 1));
        _f.from = start;
        _f.to = start.add(const Duration(days: 6));
      case 'last':
        _f.from = DateTime(t.year, t.month - 1, 1);
        _f.to = DateTime(t.year, t.month, 0);
      default:
        _f.from = DateTime(t.year, t.month, 1);
        _f.to = DateTime(t.year, t.month + 1, 0);
    }
    _period = p;
    if (load) {
      setState(() {});
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _service.list(_f);
      if (mounted) setState(() { _result = r; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _f.from ?? DateTime.now(), end: _f.to ?? DateTime.now()),
    );
    if (picked == null) return;
    setState(() { _f.from = picked.start; _f.to = picked.end; _period = 'custom'; });
    _load();
  }

  Future<void> _openFilters() async {
    final o = _options ?? await _service.getOptions().catchError((_) => LectureOptions(classes: [], sections: [], batches: [], subjects: [], teachers: []));
    if (!mounted) return;
    final f = await showLectureFilterSheet(context, o, _f);
    if (f == null) return;
    setState(() => _f = f);
    _load();
  }

  Future<void> _add() async {
    final o = _options ?? await _service.getOptions();
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => LectureFormScreen(options: o, initialDate: _f.from != null && !_f.from!.isBefore(DateUtils.dateOnly(DateTime.now())) ? _f.from : null),
    ));
    if (saved == true) _load();
  }

  Future<void> _edit(Lecture l) async {
    final o = _options ?? await _service.getOptions();
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LectureFormScreen(options: o, lecture: l)));
    if (saved == true) _load();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) { showSnack(context, done); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _cancel(Lecture l) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this lecture?'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Reason (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel lecture', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) _run(() => _service.setStatus(l.lectureId, 'Cancelled', note: c.text), 'Lecture cancelled.');
  }

  Future<void> _delete(Lecture l) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete lecture?'),
        content: Text(l.isRepeating
            ? 'This lecture is part of a repeating schedule.'
            : 'It will disappear for parents and teachers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'one'), child: Text(l.isRepeating ? 'Only this one' : 'Delete', style: const TextStyle(color: AppColors.danger))),
          if (l.isRepeating)
            TextButton(onPressed: () => Navigator.pop(ctx, 'series'), child: const Text('This & all later', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (choice == 'one') _run(() => _service.delete(l.lectureId), 'Lecture deleted.');
    if (choice == 'series') _run(() => _service.deleteSeries(l.lectureId), 'Lectures deleted.');
  }

  void _actions(Lecture l, bool canEdit) {
    if (!canEdit) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final canComplete = !l.isCompleted && !DateUtils.dateOnly(l.date).isAfter(today);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text('${l.subject.trim()} • ${l.timeRange}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (canComplete)
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                title: const Text('Mark as completed'),
                onTap: () { Navigator.pop(ctx); _run(() => _service.setStatus(l.lectureId, 'Completed'), 'Marked as completed.'); },
              ),
            if (l.status == 'Scheduled')
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                title: const Text('Cancel lecture'),
                onTap: () { Navigator.pop(ctx); _cancel(l); },
              ),
            if (l.status != 'Scheduled')
              ListTile(
                leading: const Icon(Icons.replay, color: AppColors.info),
                title: const Text('Re-open (back to scheduled)'),
                onTap: () { Navigator.pop(ctx); _run(() => _service.setStatus(l.lectureId, 'Scheduled'), 'Lecture re-opened.'); },
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () { Navigator.pop(ctx); _edit(l); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Delete', style: TextStyle(color: AppColors.danger)),
              onTap: () { Navigator.pop(ctx); _delete(l); },
            ),
          ],
        ),
      ),
    );
  }

  String get _rangeLabel {
    if (_f.from == null) return '';
    final a = DateFormat('d MMM').format(_f.from!);
    final b = DateFormat('d MMM yyyy').format(_f.to ?? _f.from!);
    return DateUtils.isSameDay(_f.from, _f.to) ? DateFormat('d MMM yyyy').format(_f.from!) : '$a – $b';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.hasPerm('lecture_schedule')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lecture Schedule')),
        body: const EmptyState(message: 'You do not have permission to view the lecture schedule.', icon: Icons.lock_outline),
      );
    }
    final canEdit = session.hasEditPerm('lecture_schedule');
    final n = _f.activeCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture Schedule'),
        actions: [
          if (session.hasPerm('lecture_summary'))
            IconButton(
              tooltip: 'Summary',
              icon: const Icon(Icons.pie_chart_outline),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LectureSummaryScreen())),
            ),
          IconButton(
            tooltip: 'Filters',
            icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.filter_alt_outlined)),
            onPressed: _openFilters,
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add Lecture'))
          : null,
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              children: [
                for (final p in const [('today', 'Today'), ('week', 'This week'), ('month', 'This month'), ('last', 'Last month')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(p.$2), selected: _period == p.$1, onSelected: (_) => _applyPeriod(p.$1)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(_period == 'custom' ? _rangeLabel : 'Custom'),
                  onPressed: _pickRange,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Align(alignment: Alignment.centerLeft, child: Text(_rangeLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          ),
          if (_result != null) Padding(padding: const EdgeInsets.fromLTRB(9, 4, 9, 0), child: LectureTotalsRow(_result!.totals, showNotUpdated: true)),
          Expanded(child: _body(canEdit)),
        ],
      ),
    );
  }

  Widget _body(bool canEdit) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final list = _result?.lectures ?? [];
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const SizedBox(height: 40),
          EmptyState(message: canEdit ? 'No lectures in this period.\nTap "Add Lecture" to schedule one.' : 'No lectures in this period.', icon: Icons.event_busy_outlined),
        ]),
      );
    }
    final children = <Widget>[];
    DateTime? cur;
    for (final l in list) {
      if (cur == null || !DateUtils.isSameDay(cur, l.date)) {
        cur = l.date;
        children.add(LectureDayHeader(l.date));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: LectureCard(lecture: l, onTap: canEdit ? () => _actions(l, canEdit) : null),
      ));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 96), children: children),
    );
  }
}
