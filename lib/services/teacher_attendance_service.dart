import '../core/api_client.dart';
import '../models/lookup.dart';
import '../models/teacher_attendance.dart';

int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';

LookupItem _facultyLookup(Map<String, dynamic> j) => LookupItem(id: _asInt(j['facultyId']), name: _asString(j['fullName']));

class TeacherAttendanceIndexData {
  TeacherAttendanceIndexData({required this.teachers, required this.classes, required this.batches, required this.attendance});
  final List<LookupItem> teachers;
  final List<LookupItem> classes;
  final List<LookupItem> batches;
  final List<TeacherAttendance> attendance;
}

class TeacherAttendanceSummaryData {
  TeacherAttendanceSummaryData({required this.attendance, required this.totalHours, required this.totalDays});
  final List<TeacherAttendance> attendance;
  final double totalHours;
  final int totalDays;
}

/// Wraps GET/POST api/teacher-attendance/* (TeacherAttendanceApiController). Save/delete return 200 OK
/// even on business-rule failure (`{success:false, message}`), so this service checks `success` itself
/// and raises [ApiException] — ApiClient only auto-throws on HTTP-level (4xx/5xx) errors.
class TeacherAttendanceService {
  final _client = ApiClient.instance;

  Future<TeacherAttendanceIndexData> getIndex() async {
    final res = await _client.get('/api/teacher-attendance');
    final data = res.data as Map<String, dynamic>;
    return TeacherAttendanceIndexData(
      teachers: (data['teachers'] as List? ?? []).map((e) => _facultyLookup(e as Map<String, dynamic>)).toList(),
      classes: (data['classes'] as List? ?? []).map((e) => LookupItem.fromClass(e as Map<String, dynamic>)).toList(),
      batches: (data['batches'] as List? ?? []).map((e) => LookupItem.fromBatch(e as Map<String, dynamic>)).toList(),
      attendance: (data['attendance'] as List? ?? []).map((e) => TeacherAttendance.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<int> save({
    required int facultyId,
    int? classId,
    int? batchId,
    String? subject,
    String? topic,
    required String attendanceDate,
    String? inTime,
    String? outTime,
  }) async {
    final res = await _client.post('/api/teacher-attendance/save', data: {
      'facultyId': facultyId,
      'classId': classId,
      'batchId': batchId,
      'subject': subject,
      'topic': topic,
      'attendanceDate': attendanceDate,
      'inTime': inTime,
      'outTime': outTime,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) throw ApiException(_asString(data['message']).isEmpty ? 'Failed to save attendance.' : _asString(data['message']));
    return _asInt(data['attendanceId']);
  }

  Future<void> delete(int attendanceId) async {
    final res = await _client.post('/api/teacher-attendance/$attendanceId/delete');
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) throw ApiException(_asString(data['message']).isEmpty ? 'Failed to delete attendance.' : _asString(data['message']));
  }

  Future<TeacherAttendanceSummaryData> getSummary() async {
    final res = await _client.get('/api/teacher-attendance/summary');
    final data = res.data as Map<String, dynamic>;
    return TeacherAttendanceSummaryData(
      attendance: (data['attendance'] as List? ?? []).map((e) => TeacherAttendance.fromJson(e as Map<String, dynamic>)).toList(),
      totalHours: _asDouble(data['totalHours']),
      totalDays: _asInt(data['totalDays']),
    );
  }
}
