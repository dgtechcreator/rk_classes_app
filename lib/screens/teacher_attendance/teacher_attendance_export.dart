import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/teacher_attendance.dart';
import '../../widgets/common.dart';

/// One teacher's lectures of one class + stream / medium (the rates differ per class and medium, so the hours are kept apart).
class TeacherClassMediumGroup {
  TeacherClassMediumGroup(this.className, this.sectionName);
  final String className;
  final String sectionName; // '' = no stream / medium was chosen for these entries
  final List<TeacherAttendance> entries = [];

  double get hours => entries.fold(0.0, (s, a) => s + (a.totalHours ?? 0));
  int get days => entries.map((a) => DateFormat('yyyy-MM-dd').format(a.attendanceDate)).toSet().length;
  String get mediumLabel => sectionName.isEmpty ? 'Medium not set' : sectionName;
  String get title => [className.isEmpty ? 'No class' : className, mediumLabel].join('  •  ');
}

/// Class (5th, 6th ... 12th in school order) -> stream / medium. Entries without a class / medium go last.
List<TeacherClassMediumGroup> groupByClassAndMedium(Iterable<TeacherAttendance> entries) {
  final map = <String, TeacherClassMediumGroup>{};
  for (final a in entries) {
    final c = (a.className ?? '').trim(), s = (a.sectionName ?? '').trim();
    map.putIfAbsent('$c|$s', () => TeacherClassMediumGroup(c, s)).entries.add(a);
  }
  int classRank(String c) => int.tryParse(RegExp(r'\d+').firstMatch(c)?.group(0) ?? '') ?? 999;
  final list = map.values.toList()
    ..sort((x, y) {
      final r = classRank(x.className).compareTo(classRank(y.className));
      if (r != 0) return r;
      final n = x.className.compareTo(y.className);
      if (n != 0) return n;
      if (x.sectionName.isEmpty != y.sectionName.isEmpty) return x.sectionName.isEmpty ? 1 : -1;
      return x.sectionName.compareTo(y.sectionName);
    });
  for (final g in list) {
    g.entries.sort((a, b) => b.attendanceDate.compareTo(a.attendanceDate));
  }
  return list;
}

String teacherHoursText(double h) => h % 1 == 0 ? h.toStringAsFixed(0) : h.toStringAsFixed(2);

/// The entries as a CSV file Excel opens (UTF-8 with BOM): one row per lecture, then a class + medium wise total per teacher.
/// Shared to Excel / WhatsApp / Drive ...
Future<void> exportTeacherAttendance(BuildContext context, List<TeacherAttendance> list, {required String title, required String fileLabel}) async {
  if (list.isEmpty) {
    showSnack(context, 'Nothing to export for this selection.', isError: true);
    return;
  }
  String q(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
  String n(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final byTeacher = <int, List<TeacherAttendance>>{};
  for (final a in list) {
    byTeacher.putIfAbsent(a.facultyId, () => []).add(a);
  }
  final teachers = byTeacher.values.toList()
    ..sort((a, b) => a.first.facultyName.trim().toLowerCase().compareTo(b.first.facultyName.trim().toLowerCase()));

  final sb = StringBuffer('${q(title)}\r\n\r\n');
  sb.write('Teacher,Date,Class,Stream / Medium,Batch,Subject,Topic,In Time,Out Time,Hours\r\n');
  for (final t in teachers) {
    final rows = [...t]..sort((a, b) => a.attendanceDate.compareTo(b.attendanceDate));
    for (final a in rows) {
      sb.write([
        q(a.facultyName.trim()), DateFormat('dd-MM-yyyy').format(a.attendanceDate), q(a.className), q(a.sectionName), q(a.batchName),
        q(a.subjectName), q(a.topic), a.inTimeDisplay ?? '', a.outTimeDisplay ?? '', a.totalHours == null ? '' : n(a.totalHours!),
      ].join(','));
      sb.write('\r\n');
    }
  }
  sb.write('\r\nClass and medium wise total\r\nTeacher,Class,Stream / Medium,Lectures,Days,Hours\r\n');
  var grand = 0.0;
  for (final t in teachers) {
    var teacherHours = 0.0;
    for (final g in groupByClassAndMedium(t)) {
      sb.write('${[q(t.first.facultyName.trim()), q(g.className), q(g.sectionName), g.entries.length, g.days, n(g.hours)].join(',')}\r\n');
      teacherHours += g.hours;
    }
    if (teachers.length > 1) sb.write('${q('${t.first.facultyName.trim()} - total')},,,${t.length},,${n(teacherHours)}\r\n');
    grand += teacherHours;
  }
  sb.write('Total,,,${list.length},,${n(grand)}\r\n');
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/TeacherAttendance_$fileLabel.csv');
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(sb.toString())]); // UTF-8 with BOM so Excel shows Hindi text correctly
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], text: title));
  } catch (_) {
    if (context.mounted) showSnack(context, 'Could not create the file. Please try again.', isError: true);
  }
}
