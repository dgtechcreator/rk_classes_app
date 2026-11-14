import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/teacher_attendance.dart';
import '../../services/teacher_attendance_service.dart';
import 'teacher_attendance_edit_sheet.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'teacher_attendance_export.dart';

/// One teacher's lectures, split class-wise and then stream / medium-wise (rates differ per class and medium),
/// with every lecture's date, time, subject and topic, and an Excel export.
class TeacherAttendanceDetailScreen extends StatelessWidget {
  const TeacherAttendanceDetailScreen({super.key, required this.facultyName, required this.entries, required this.periodLabel});
  final String facultyName;
  final List<TeacherAttendance> entries;
  final String periodLabel; // "All time", "November 2026" ...

  @override
  Widget build(BuildContext context) {
    final groups = groupByClassAndMedium(entries);
    final totalHours = entries.fold(0.0, (s, a) => s + (a.totalHours ?? 0));
    final days = entries.map((a) => DateFormat('yyyy-MM-dd').format(a.attendanceDate)).toSet().length;
    final safe = RegExp(r'[^A-Za-z0-9]+');
    final session = context.read<Session>();
    final canEdit = session.isAdmin || session.hasEditPerm('teacher_attendance');

    Future<void> edit(TeacherAttendance a) async {
      if (await showTeacherAttendanceEditSheet(context, a) && context.mounted) {
        showSnack(context, 'Entry updated. The teacher has been notified.');
        Navigator.of(context).pop(true);
      }
    }

    Future<void> remove(TeacherAttendance a) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this entry?'),
          content: Text('${DateFormat('d MMM yyyy').format(a.attendanceDate)} - ${a.fullLabel}\nThe teacher will be told who deleted it and when.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      try {
        await TeacherAttendanceService().delete(a.attendanceId);
        if (context.mounted) {
          showSnack(context, 'Entry deleted. The teacher has been notified.');
          Navigator.of(context).pop(true);
        }
      } on ApiException catch (e) {
        if (context.mounted) showSnack(context, e.message, isError: true);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(facultyName.trim(), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export to Excel',
            onPressed: () => exportTeacherAttendance(
              context,
              entries,
              title: '${facultyName.trim()} - Attendance ($periodLabel)',
              fileLabel: '${facultyName.trim().replaceAll(safe, '_')}_${periodLabel.replaceAll(safe, '_')}',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(periodLabel, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: StatCard(label: 'Total Hours', value: totalHours.toStringAsFixed(1), color: AppColors.info, icon: Icons.timer_outlined)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(label: 'Days', value: '$days', color: AppColors.success, icon: Icons.event_available_outlined)),
          ]),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Class & Medium wise'),
          if (groups.isEmpty)
            const EmptyState(message: 'No lectures for this selection.', icon: Icons.event_busy_outlined)
          else
            ...groups.map((g) => _GroupCard(group: g, canEdit: canEdit, onEdit: edit, onDelete: remove)),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.canEdit, required this.onEdit, required this.onDelete});
  final TeacherClassMediumGroup group;
  final bool canEdit;
  final void Function(TeacherAttendance) onEdit;
  final void Function(TeacherAttendance) onDelete;

  @override
  Widget build(BuildContext context) {
    final n = group.entries.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          title: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('$n ${n == 1 ? 'lecture' : 'lectures'} • ${group.days} ${group.days == 1 ? 'day' : 'days'}'),
          trailing: Text('${teacherHoursText(group.hours)} hrs', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
          children: [
            for (final a in group.entries)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderNeutral))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('d MMM yyyy, EEE').format(a.attendanceDate), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (a.inTimeDisplay != null || a.outTimeDisplay != null) '${a.inTimeDisplay ?? '--'} - ${a.outTimeDisplay ?? '--'}',
                              if ((a.batchName ?? '').isNotEmpty) a.batchName!,
                              if ((a.subjectName ?? '').isNotEmpty) a.subjectName!,
                              if ((a.topic ?? '').isNotEmpty) a.topic!,
                            ].join(' • '),
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                          if (a.isAuto)
                            const Padding(padding: EdgeInsets.only(top: 2), child: Text('Auto - made from the student attendance', style: TextStyle(fontSize: 11.5, color: AppColors.info, fontWeight: FontWeight.w600))),
                          if (a.updatedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Edited by ${(a.updatedByName ?? '').isEmpty ? 'admin' : a.updatedByName} on ${DateFormat('d MMM, h:mm a').format(a.updatedAt!)}', style: const TextStyle(fontSize: 11.5, color: AppColors.warning, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(a.totalHours == null ? '-' : '${teacherHoursText(a.totalHours!)} hrs', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    if (canEdit)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        onSelected: (v) => v == 'edit' ? onEdit(a) : onDelete(a),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
