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
import 'lecture_list_screen.dart';

/// How many lectures each teacher / class group / subject has actually held in a month (this month, last month or
/// any other), with the same class / medium / batch / subject / teacher filters as the schedule. Tapping a row opens
/// the matching lectures. Mirrors the web Lecture Summary page.
class LectureSummaryScreen extends StatefulWidget {
  const LectureSummaryScreen({super.key});

  @override
  State<LectureSummaryScreen> createState() => _LectureSummaryScreenState();
}

class _LectureSummaryScreenState extends State<LectureSummaryScreen> {
  final _service = LectureService();

  late DateTime _month; // first day of the shown month
  String _groupBy = 'teacher';
  final LectureFilters _f = LectureFilters();
  LectureOptions? _options;
  LectureSummaryResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = DateTime.now();
    _month = DateTime(t.year, t.month, 1);
    _service.getOptions().then((o) { if (mounted) setState(() => _options = o); }).catchError((_) {});
    _load();
  }

  bool get _isThisMonth => _month.year == DateTime.now().year && _month.month == DateTime.now().month;

  Future<void> _load() async {
    _f.from = _month;
    _f.to = DateTime(_month.year, _month.month + 1, 0);
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _service.summary(_f, _groupBy);
      if (mounted) setState(() { _result = r; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months, 1));
    _load();
  }

  Future<void> _pickMonth() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'Pick any day of the month',
    );
    if (d == null) return;
    setState(() => _month = DateTime(d.year, d.month, 1));
    _load();
  }

  Future<void> _filters() async {
    final o = _options ?? await _service.getOptions();
    if (!mounted) return;
    final nf = await showLectureFilterSheet(context, o, _f, showStatus: false);
    if (nf == null) return;
    setState(() {
      _f.classId = nf.classId;
      _f.sectionId = nf.sectionId;
      _f.batchId = nf.batchId;
      _f.subject = nf.subject;
      _f.facultyId = nf.facultyId;
    });
    _load();
  }

  void _drill(LectureSummaryRow r) {
    if (!context.read<Session>().hasPerm('lecture_schedule')) return;
    final f = _f.copy()..status = null;
    switch (_groupBy) {
      case 'teacher':
        f.facultyId = r.facultyId;
      case 'subject':
        f.subject = r.label;
      default:
        final p = r.key.split('|');
        f.classId = int.tryParse(p[0]);
        f.sectionId = p.length > 1 ? int.tryParse(p[1]) : null;
        f.batchId = p.length > 2 ? int.tryParse(p[2]) : null;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LectureListScreen(initialFilters: f)));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.hasPerm('lecture_summary')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lecture Summary')),
        body: const EmptyState(message: 'You do not have permission to view the lecture summary.', icon: Icons.lock_outline),
      );
    }
    final n = _f.activeCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture Summary'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.filter_alt_outlined)),
            onPressed: _filters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                IconButton.filledTonal(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        Text(DateFormat('MMMM yyyy').format(_month), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        Text(_isThisMonth ? 'This month' : 'Tap to pick a month', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
                IconButton.filledTonal(onPressed: _isThisMonth ? null : () => _shift(1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(label: const Text('This month'), selected: _isThisMonth, onSelected: (_) {
                  final t = DateTime.now();
                  setState(() => _month = DateTime(t.year, t.month, 1));
                  _load();
                }),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Last month'),
                  selected: _month.year * 12 + _month.month == DateTime.now().year * 12 + DateTime.now().month - 1,
                  onSelected: (_) {
                    final t = DateTime.now();
                    setState(() => _month = DateTime(t.year, t.month - 1, 1));
                    _load();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'teacher', icon: Icon(Icons.person_outline, size: 18), label: Text('Teacher')),
                  ButtonSegment(value: 'class', icon: Icon(Icons.groups_outlined, size: 18), label: Text('Class')),
                  ButtonSegment(value: 'subject', icon: Icon(Icons.menu_book_outlined, size: 18), label: Text('Subject')),
                ],
                selected: {_groupBy},
                onSelectionChanged: (s) { setState(() => _groupBy = s.first); _load(); },
              ),
            ),
          ),
          if (_result != null) Padding(padding: const EdgeInsets.fromLTRB(9, 0, 9, 4), child: LectureTotalsRow(_result!.totals, showNotUpdated: true)),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final rows = _result?.rows ?? [];
    if (rows.isEmpty) return const EmptyState(message: 'No lectures in this month.', icon: Icons.pie_chart_outline);
    final max = rows.map((r) => r.total).fold<int>(1, (a, b) => b > a ? b : a);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: rows.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i == rows.length) {
            return const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Held = lectures marked completed. "Not updated" = scheduled lectures whose time has passed but were never marked done or cancelled.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
            );
          }
          final r = rows[i];
          return Card(
            child: InkWell(
              onTap: () => _drill(r),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                      Text('${r.completed}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 24)),
                      const SizedBox(width: 4),
                      const Text('held', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: r.completed / max, minHeight: 6, color: AppColors.success, backgroundColor: AppColors.borderNeutral),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 14, runSpacing: 4, children: [
                      _stat('Scheduled', r.scheduled, AppColors.info),
                      _stat('Cancelled', r.cancelled, AppColors.danger),
                      if (r.notUpdated > 0) _stat('Not updated', r.notUpdated, AppColors.warning),
                      _stat('Hours', r.hoursHeld, AppColors.violet),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String label, num v, Color c) {
    final text = v is double ? formatHours(v) : v.toStringAsFixed(0);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ]);
  }
}
