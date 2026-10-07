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
    this.totalLate = 0,
    required this.totalMarked,
    this.batchId,
    this.batchName,
  });

  final DateTime date;
  final List<AttendanceRecord> records;
  final String? subject;
  final String? sirName;
  final String? startTime;
  final String? endTime;
  final int totalPresent;
  final int totalAbsent;
  final int totalLate;
  /// Students that already have a saved row for the date (the rest default to Present until saved).
  final int totalMarked;
  final int? batchId;
  final String? batchName;
}

class AttendanceOptions {
  AttendanceOptions({required this.subjects, required this.teachers});
  final List<String> subjects;
  final List<AttendanceTeacher> teachers;
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

  AttendanceIndexResult _parseDay(Map<String, dynamic> data, DateTime fallback) {
    final records = (data['records'] as List? ?? []).map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList();
    int n(String k) => (data[k] as num?)?.toInt() ?? 0;
    return AttendanceIndexResult(
      date: DateTime.tryParse(data['date']?.toString() ?? '') ?? fallback,
      records: records,
      subject: data['subject']?.toString(),
      sirName: data['sirName']?.toString(),
      startTime: data['startTime']?.toString(),
      endTime: data['endTime']?.toString(),
      totalPresent: n('totalPresent'),
      totalAbsent: n('totalAbsent'),
      totalLate: n('totalLate'),
      totalMarked: n('totalMarked'),
      batchId: (data['batchId'] as num?)?.toInt(),
      batchName: data['batchName']?.toString(),
    );
  }

  Future<AttendanceIndexResult> getForDate({DateTime? date, int? classId, int? sectionId, int? batchId}) async {
    final d = date ?? DateTime.now();
    final res = await _client.get('/api/attendance', query: {
      'date': _fmtDate(d),
      if (classId != null) 'classId': classId,
      if (sectionId != null) 'sectionId': sectionId,
      if (batchId != null) 'batchId': batchId,
    });
    return _parseDay(res.data as Map<String, dynamic>, d);
  }

  /// Every attendance batch with its present/total for [date] (green = marked, light red = pending).
  Future<List<AttendanceBatchSummary>> getBatches(DateTime date) async {
    final res = await _client.get('/api/attendance/batches', query: {'date': _fmtDate(date)});
    final data = res.data as Map<String, dynamic>;
    return (data['batches'] as List? ?? []).map((e) => AttendanceBatchSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// One batch's students for [date]; a day that was already marked comes back filled in.
  Future<AttendanceIndexResult> getBatchDetail(int attBatchId, DateTime date) async {
    final res = await _client.get('/api/attendance/batch/$attBatchId', query: {'date': _fmtDate(date)});
    return _parseDay(res.data as Map<String, dynamic>, date);
  }

  Future<AttendanceOptions> getOptions() async {
    final res = await _client.get('/api/attendance/options');
    final data = res.data as Map<String, dynamic>;
    return AttendanceOptions(
      subjects: (data['subjects'] as List? ?? []).map((e) => e.toString()).toList(),
      teachers: (data['teachers'] as List? ?? []).map((e) => AttendanceTeacher.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Father / mother / student numbers (the attendance list itself does not carry phones).
  Future<({String father, String mother, String student})> getStudentContact(int studentId) async {
    final res = await _client.get('/api/attendance/student-contact', query: {'studentId': studentId});
    final m = res.data as Map<String, dynamic>;
    return (
      father: m['fatherPhone']?.toString() ?? '',
      mother: m['motherPhone']?.toString() ?? '',
      student: m['studentPhone']?.toString() ?? '',
    );
  }

  Future<String> save({
    required DateTime date,
    int? classId,
    int? sectionId,
    int? batchId,
    int? attBatchId,
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
      'attBatchId': attBatchId,
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
