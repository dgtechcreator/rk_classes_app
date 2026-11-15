import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/parent_data_controller.dart';
import '../../models/papers.dart';
import '../../models/student.dart';
import '../../models/toppers.dart';
import '../../services/parent_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/subject_visuals.dart';
import '../../widgets/common.dart';
import '../../widgets/toppers_card.dart';
import 'paper_detail_screen.dart';

/// Grades = "All paper list": every paper of the child's class and medium, grouped by subject
/// (Subject → chapter / test → date). Tap a paper for its circle score and the Top 5 of that paper.
/// Subject chips and the date strip narrow the list; the class toppers card stays on top.
class ParentGradesScreen extends StatefulWidget {
  const ParentGradesScreen({super.key, this.initialSubject});
  final String? initialSubject;

  @override
  State<ParentGradesScreen> createState() => _ParentGradesScreenState();
}

class _ParentGradesScreenState extends State<ParentGradesScreen> {
  final _service = ParentService();
  String? _subject;
  DateTime? _date;

  int? _loadedFor;
  PapersData? _papers;
  bool _papersLoading = false;
  String? _papersError;

  @override
  void initState() {
    super.initState();
    _subject = widget.initialSubject;
  }

  Future<void> _loadPapers(int studentId) async {
    _loadedFor = studentId;
    setState(() { _papersLoading = true; _papersError = null; _papers = null; });
    try {
      final p = await _service.getPapers(studentId);
      if (!mounted || _loadedFor != studentId) return;
      setState(() { _papers = p; _papersLoading = false; });
    } catch (e) {
      if (!mounted || _loadedFor != studentId) return;
      setState(() {
        _papersError = e is ApiException ? e.message : 'Could not load the paper list.';
        _papersLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final ctrl = context.read<ParentDataController>();
    await ctrl.load();
    final id = ctrl.selected?.studentId;
    if (id != null) await _loadPapers(id);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ParentDataController>();
    final d = ctrl.data;

    // Load the paper list for the selected child (once per child; the callback runs after this build).
    final id = ctrl.selected?.studentId;
    if (id != null && id != _loadedFor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && id != _loadedFor) _loadPapers(id);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TabHeader(title: 'Grades', subtitle: 'All paper list'),
            Expanded(
              child: ctrl.loading && d == null
                  ? const LoadingView()
                  : ctrl.error != null && d == null
                      ? ErrorView(message: ctrl.error!, onRetry: ctrl.load)
                      : d == null
                          ? const EmptyState(message: 'No children linked to this account yet.', icon: Icons.family_restroom)
                          : _buildBody(context, d),
            ),
          ],
        ),
      ),
    );
  }

  /// Top 5 of the child's own class: overall, or of the chosen subject when a subject chip is selected.
  Widget _toppersSection(ClassToppers? t) {
    if (t == null) return const SizedBox.shrink();
    final subjectKey = _subject?.trim();
    final bySubject = subjectKey != null ? t.subjects[subjectKey] : null;
    final card = bySubject != null
        ? ToppersCard(title: 'Top 5 in $subjectKey', subtitle: t.classLabel, section: bySubject)
        : subjectKey != null
            ? null
            : ToppersCard(title: 'Class Toppers', subtitle: '${t.classLabel}${t.yearName != null ? ' • ${t.yearName}' : ''} • all tests combined', section: t.overall);
    if (card == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: card);
  }

  Widget _buildBody(BuildContext context, ParentDashboardData d) {
    final papers = _papers;
    final allSubjects = papers?.subjects ?? const <PaperSubject>[];
    final dates = <DateTime>{
      for (final s in allSubjects)
        for (final p in s.papers)
          if (p.testDate != null) DateTime(p.testDate!.year, p.testDate!.month, p.testDate!.day),
    }.toList()
      ..sort();

    // Subject chip and date strip narrow the list; a subject with no papers left is dropped.
    final groups = <PaperSubject>[];
    for (final s in allSubjects) {
      if (_subject != null && s.name != _subject) continue;
      final list = s.papers.where((p) {
        if (_date == null) return true;
        final t = p.testDate;
        return t != null && t.year == _date!.year && t.month == _date!.month && t.day == _date!.day;
      }).toList();
      if (list.isNotEmpty) groups.add(PaperSubject(name: s.name, papers: list));
    }

    final toppers = context.watch<ParentDataController>().toppers;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (allSubjects.isNotEmpty) ...[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: const Text('All'), selected: _subject == null, onSelected: (_) => setState(() => _subject = null)),
                  ),
                  ...allSubjects.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(label: Text(s.name), selected: _subject == s.name, onSelected: (_) => setState(() => _subject = _subject == s.name ? null : s.name)),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (dates.isNotEmpty) ...[
            DateStrip(dates: dates, selected: _date, onSelected: (dt) => setState(() => _date = dt)),
            const SizedBox(height: 16),
          ],
          _toppersSection(toppers),
          if (_papersLoading && papers == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_papersError != null && papers == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                Text(_papersError!, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextButton(onPressed: _refresh, child: const Text('Try again')),
              ]),
            )
          else if (groups.isEmpty)
            const EmptyState(message: 'No papers match this filter.', icon: Icons.grade_outlined)
          else
            for (final g in groups) ...[
              _subjectHeader(g.name),
              for (final p in g.papers) _paperCard(p),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _subjectHeader(String name) {
    final v = subjectVisual(name);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(children: [
        Icon(v.icon, size: 20, color: v.color),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
      ]),
    );
  }

  Widget _paperCard(ExamPaper p) {
    final pct = p.myPercentage ?? 0;
    final (String badge, Color color) = p.myAbsent
        ? ('Absent', AppColors.danger)
        : !p.hasMarks
            ? ('—', AppColors.textMuted)
            : ('${_num(p.myMarks!)}/${p.maxMarks}', pct >= 35 ? AppColors.success : AppColors.danger);
    final date = p.testDate == null ? 'No date' : DateFormat('d MMM yyyy').format(p.testDate!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaperDetailScreen(paper: p))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.examName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(badge, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
