import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/lecture.dart';
import '../theme/app_theme.dart';

/// 2.25 -> "2.25", 3.0 -> "3", 1.5 -> "1.5".
String formatHours(double h) {
  final t = h.toStringAsFixed(2);
  return t.contains('.') ? t.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : t;
}

Color lectureStatusColor(String status) => switch (status) {
      'Completed' => AppColors.success,
      'Cancelled' => AppColors.danger,
      _ => AppColors.info,
    };

/// One lecture: time, subject, class group, teacher and a status badge. [trailing] / [onTap] are optional so the
/// same card serves the admin schedule (tap = actions), the teacher view and the parent view.
class LectureCard extends StatelessWidget {
  const LectureCard({super.key, required this.lecture, this.showGroup = true, this.showTeacher = true, this.onTap, this.footer});
  final Lecture lecture;
  final bool showGroup;
  final bool showTeacher;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l = lecture;
    final color = lectureStatusColor(l.status);
    final badge = l.needsUpdate ? 'Not updated' : l.status;
    final badgeColor = l.needsUpdate ? AppColors.warning : color;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
        border: Border(left: BorderSide(color: badgeColor, width: 5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Opacity(
              opacity: l.isCancelled ? 0.7 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppColors.info),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(l.timeRange, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Text(badge, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w800, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l.subject.trim(),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, decoration: l.isCancelled ? TextDecoration.lineThrough : null)),
                  if (showGroup && l.groupLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(children: [
                        const Icon(Icons.groups_outlined, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Expanded(child: Text(l.groupLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                      ]),
                    ),
                  if (showTeacher && (l.teacher ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(children: [
                        const Icon(Icons.person_outline, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Expanded(child: Text(l.teacher!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                      ]),
                    ),
                  if ((l.topic ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Topic: ${l.topic}', style: const TextStyle(fontSize: 12.5)),
                    ),
                  if (l.isCancelled && (l.statusNote ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Cancelled: ${l.statusNote}', style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  if (l.isRepeating)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('🔁 Repeating schedule', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                    ),
                  if (footer != null) Padding(padding: const EdgeInsets.only(top: 8), child: footer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Date header used between days in a lecture list.
class LectureDayHeader extends StatelessWidget {
  const LectureDayHeader(this.date, {super.key});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Row(
        children: [
          Text(DateFormat('EEEE, d MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Held / Scheduled / Cancelled / Hours tiles.
class LectureTotalsRow extends StatelessWidget {
  const LectureTotalsRow(this.totals, {super.key, this.showNotUpdated = false});
  final LectureTotals totals;
  final bool showNotUpdated;

  Widget _tile(String label, String value, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.sm), boxShadow: AppShadows.soft),
          child: Column(children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 19)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final h = totals.hoursHeld;
    return Row(children: [
      _tile('HELD', '${totals.held}', AppColors.success),
      _tile('SCHEDULED', '${totals.scheduled}', AppColors.info),
      _tile('CANCELLED', '${totals.cancelled}', AppColors.danger),
      if (showNotUpdated) _tile('NOT UPDATED', '${totals.notUpdated}', AppColors.warning),
      _tile('HOURS', formatHours(h), AppColors.violet),
    ]);
  }
}

/// A month's counts with "held per subject" (and optionally per class) chips — used for the teacher's own
/// months and for a parent's child.
class MonthCountsCard extends StatelessWidget {
  const MonthCountsCard({super.key, required this.month, this.title, this.showClasses = false});
  final MonthLectures month;
  final String? title;
  final bool showClasses;

  Widget _chips(String heading, List<LabelCounts> items) {
    final shown = items.where((e) => e.held + e.scheduled + e.cancelled > 0).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in shown)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.violetSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text('${e.label.trim()}: ${e.held}', style: const TextStyle(color: AppColors.violet, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title ?? month.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          LectureTotalsRow(month.totals),
          _chips('Lectures held per subject', month.bySubject),
          if (showClasses) _chips('Lectures held per class', month.byGroup),
        ],
      ),
    );
  }
}

class _FilterResult {
  _FilterResult(this.filters);
  final LectureFilters filters;
}

/// Bottom sheet with every lecture filter (class, medium, batch, subject, teacher, status). Returns the new filters or null.
Future<LectureFilters?> showLectureFilterSheet(BuildContext context, LectureOptions options, LectureFilters current,
    {bool showStatus = true, bool showTeacher = true}) async {
  final f = current.copy();
  final result = await showModalBottomSheet<_FilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Widget idDrop(String label, int? value, List<IdName> items, ValueChanged<int?> onChanged) => DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: items.any((e) => e.id == value) ? value : null,
              decoration: InputDecoration(labelText: label),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All')),
                ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name.trim(), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => onChanged(v)),
            );
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Filter lectures', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                idDrop('Class', f.classId, options.classes, (v) => f.classId = v),
                const SizedBox(height: 12),
                idDrop('Medium', f.sectionId, options.sections, (v) => f.sectionId = v),
                const SizedBox(height: 12),
                idDrop('Batch', f.batchId, options.batches, (v) => f.batchId = v),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: options.subjects.contains(f.subject) ? f.subject : null,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                    ...options.subjects.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => f.subject = v),
                ),
                if (showTeacher) ...[
                  const SizedBox(height: 12),
                  idDrop('Teacher', f.facultyId, options.teachers, (v) => f.facultyId = v),
                ],
                if (showStatus) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: f.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All')),
                      ...lectureStatuses.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
                    ],
                    onChanged: (v) => setState(() => f.status = v),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, _FilterResult(LectureFilters(from: f.from, to: f.to))),
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, _FilterResult(f)), child: const Text('Apply'))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  return result?.filters;
}
