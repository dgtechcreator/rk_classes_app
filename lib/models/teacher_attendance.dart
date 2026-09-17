int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _asIntN(dynamic v) => v == null ? null : _asInt(v);
double? _asDoubleN(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();

/// Mirrors SchoolMS.Domain.TeacherAttendance — one In/Out time entry for a faculty member on a date.
class TeacherAttendance {
  TeacherAttendance({
    required this.attendanceId,
    required this.facultyId,
    required this.facultyName,
    this.classId,
    this.className,
    this.batchId,
    this.batchName,
    this.subjectName,
    this.topic,
    required this.attendanceDate,
    this.inTime,
    this.outTime,
    this.totalHours,
  });

  final int attendanceId;
  final int facultyId;
  final String facultyName;
  final int? classId;
  final String? className;
  final int? batchId;
  final String? batchName;
  final String? subjectName;
  final String? topic;
  final DateTime attendanceDate;
  final String? inTime; // "HH:mm:ss" (System.Text.Json TimeSpan constant format)
  final String? outTime;
  final double? totalHours;

  factory TeacherAttendance.fromJson(Map<String, dynamic> j) => TeacherAttendance(
        attendanceId: _asInt(j['attendanceId']),
        facultyId: _asInt(j['facultyId']),
        facultyName: _asString(j['facultyName']),
        classId: _asIntN(j['classId']),
        className: _asStringN(j['className']),
        batchId: _asIntN(j['batchId']),
        batchName: _asStringN(j['batchName']),
        subjectName: _asStringN(j['subjectName']),
        topic: _asStringN(j['topic']),
        attendanceDate: DateTime.tryParse(_asString(j['attendanceDate'])) ?? DateTime.now(),
        inTime: _asStringN(j['inTime']),
        outTime: _asStringN(j['outTime']),
        totalHours: _asDoubleN(j['totalHours']),
      );

  String get classBatchLabel => [className, batchName].where((e) => e != null && e.isNotEmpty).join(' / ');

  String? get inTimeDisplay => (inTime == null || inTime!.length < 5) ? inTime : inTime!.substring(0, 5);
  String? get outTimeDisplay => (outTime == null || outTime!.length < 5) ? outTime : outTime!.substring(0, 5);

  bool isOnDate(DateTime date) =>
      attendanceDate.year == date.year && attendanceDate.month == date.month && attendanceDate.day == date.day;
}
