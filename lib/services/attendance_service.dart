import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/attendance.dart';

String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class AttendanceIndexResult {
  AttendanceIndexResult({
    required this.date,
    required this.records,
    this.subject,
    this.sirName,
    this.startTime,
    this.endTime,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalMarked,
  });

  final DateTime date;
  final List<AttendanceRecord> records;
  final String? subject;
  final String? sirName;
  final String? startTime;
  final String? endTime;
  final int totalPresent;
  final int totalAbsent;
  final int totalMarked;
}

class AttendanceReportResult {
  AttendanceReportResult({required this.report, required this.studentPhones});
  final List<AttendanceReportRow> report;
  final Map<int, ({String father, String mother})> studentPhones;
}

class AttendanceDateGridResult {
  AttendanceDateGridResult({required this.students, required this.attData, required this.dates});
  final List<AttendanceRecord> students;
  final List<DateAttendanceEntry> attData;
  final List<DateTime> dates;

  List<DateAttendanceEntry> forStudent(int studentId) =>
      attData.where((e) => e.studentId == studentId).toList()..sort((a, b) => b.attendanceDate.compareTo(a.attendanceDate));
}

/// Wraps AttendanceApiController (api/attendance) — daily entry, monthly report, and the date-wise grid
/// used to build a student's day-by-day detail.
class AttendanceService {
  final _client = ApiClient.instance;

  Future<AttendanceIndexResult> getForDate({DateTime? date, int? classId, int? sectionId, int? batchId}) async {
    final d = date ?? DateTime.now();
    final res = await _client.get('/api/attendance', query: {
      'date': _fmtDate(d),
      if (classId != null) 'classId': classId,
      if (sectionId != null) 'sectionId': sectionId,
      if (batchId != null) 'batchId': batchId,
    });
    final data = res.data as Map<String, dynamic>;
    final records = (data['records'] as List? ?? []).map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList();
    return AttendanceIndexResult(
      date: DateTime.tryParse(data['date']?.toString() ?? '') ?? d,
      records: records,
      subject: data['subject']?.toString(),
      sirName: data['sirName']?.toString(),
      startTime: data['startTime']?.toString(),
      endTime: data['endTime']?.toString(),
      totalPresent: data['totalPresent'] as int? ?? 0,
      totalAbsent: data['totalAbsent'] as int? ?? 0,
      totalMarked: data['totalMarked'] as int? ?? 0,
    );
  }

  Future<String> save({
    required DateTime date,
    int? classId,
    int? sectionId,
    int? batchId,
    String? subject,
    String? sirName,
    String? startTime,
    String? endTime,
    required List<Map<String, dynamic>> entries,
  }) async {
    final res = await _client.post('/api/attendance/save', data: {
      'date': _fmtDate(date),
      'classId': classId,
      'sectionId': sectionId,
      'batchId': batchId,
      'subject': subject,
      'sirName': sirName,
      'startTime': startTime,
      'endTime': endTime,
      'entries': entries,
    });
    final data = res.data as Map<String, dynamic>;
    return data['message']?.toString() ?? 'Attendance saved.';
  }

  Future<AttendanceReportResult> getReport({int? classId, int? sectionId, int? batchId, int? month, int? year}) async {
    final res = await _client.get('/api/attendance/report', query: {
      if (classId != null) 'classId': classId,
      if (sectionId != null) 'sectionId': sectionId,
      if (batchId != null) 'batchId': batchId,
      'month': month ?? DateTime.now().month,
      'year': year ?? DateTime.now().year,
    });
    final data = res.data as Map<String, dynamic>;
    final report = (data['report'] as List? ?? []).map((e) => AttendanceReportRow.fromJson(e as Map<String, dynamic>)).toList();
    final phonesRaw = data['studentPhones'] as Map<String, dynamic>? ?? {};
    final phones = <int, ({String father, String mother})>{};
    phonesRaw.forEach((k, v) {
      final id = int.tryParse(k);
      if (id == null) return;
      final m = v as Map<String, dynamic>;
      phones[id] = (father: m['father']?.toString() ?? '', mother: m['mother']?.toString() ?? '');
    });
    return AttendanceReportResult(report: report, studentPhones: phones);
  }

  Future<AttendanceDateGridResult> getDateGrid({int? classId, int? sectionId, int? batchId, DateTime? fromDate, DateTime? toDate}) async {
    final res = await _client.get('/api/attendance/date-grid', query: {
      if (classId != null) 'classId': classId,
      if (sectionId != null) 'sectionId': sectionId,
      if (batchId != null) 'batchId': batchId,
      if (fromDate != null) 'fromDate': _fmtDate(fromDate),
      if (toDate != null) 'toDate': _fmtDate(toDate),
    });
    final data = res.data as Map<String, dynamic>;
    return AttendanceDateGridResult(
      students: (data['students'] as List? ?? []).map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList(),
      attData: (data['attData'] as List? ?? []).map((e) => DateAttendanceEntry.fromJson(e as Map<String, dynamic>)).toList(),
      dates: (data['dates'] as List? ?? []).map((e) => DateTime.tryParse(e.toString()) ?? DateTime.now()).toList(),
    );
  }
}
