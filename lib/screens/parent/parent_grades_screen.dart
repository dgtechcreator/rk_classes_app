import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/parent_data_controller.dart';
import '../../models/student.dart';
import '../../theme/app_theme.dart';
import '../../theme/subject_visuals.dart';
import '../../widgets/common.dart';

/// Mirrors the reference design's "Grades" screen: subject filter chips + a date strip that
/// narrow the same underlying [ParentDashboardData.marks] list down to one subject/day.
class ParentGradesScreen extends StatefulWidget {
  const ParentGradesScreen({super.key, this.initialSubject});
  final String? initialSubject;

  @override
  State<ParentGradesScreen> createState() => _ParentGradesScreenState();
}

class _ParentGradesScreenState extends State<ParentGradesScreen> {
  String? _subject;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _subject = widget.initialSubject;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ParentDataController>();
    final d = ctrl.data;

    return Scaffold(
      appBar: AppBar(title: const Text('Grades')),
      body: ctrl.loading && d == null
          ? const LoadingView()
          : ctrl.error != null && d == null
              ? ErrorView(message: ctrl.error!, onRetry: ctrl.load)
              : d == null
                  ? const EmptyState(message: 'No children linked to this account yet.', icon: Icons.family_restroom)
                  : _buildBody(context, d),
    );
  }

  Widget _buildBody(BuildContext context, ParentDashboardData d) {
    final subjects = <String>{for (final m in d.marks) if ((m.subjectName ?? '').isNotEmpty) m.subjectName!};
    final dates = <DateTime>{
      for (final m in d.marks) if (m.testDate != null) DateTime(m.testDate!.year, m.testDate!.month, m.testDate!.day),
    }.toList()
      ..sort();

    final filtered = d.marks.where((m) {
      if (_subject != null && m.subjectName != _subject) return false;
      if (_date != null) {
        final md = m.testDate;
        if (md == null || md.year != _date!.year || md.month != _date!.month || md.day != _date!.day) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: context.read<ParentDataController>().load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (subjects.isNotEmpty) ...[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: const Text('All'), selected: _subject == null, onSelected: (_) => setState(() => _subject = null)),
                  ),
                  ...subjects.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(label: Text(s), selected: _subject == s, onSelected: (_) => setState(() => _subject = _subject == s ? null : s)),
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
          if (filtered.isEmpty)
            const EmptyState(message: 'No test marks match this filter.', icon: Icons.grade_outlined)
          else
            ...filtered.map((m) {
              final pct = m.marksObtained == null ? null : (m.marksObtained! / m.maxMarks * 100);
              final v = subjectVisual(m.subjectName);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListInfoCard(
                  title: m.subjectName ?? 'Subject',
                  subtitle: m.examName,
                  icon: v.icon,
                  iconColor: v.color,
                  badgeText: m.marksObtained == null ? 'Absent' : 'Grade: ${m.marksObtained!.toStringAsFixed(0)}/${m.maxMarks}',
                  badgeColor: pct == null ? AppColors.danger : (pct >= 35 ? AppColors.success : AppColors.danger),
                ),
              );
            }),
        ],
      ),
    );
  }
}
