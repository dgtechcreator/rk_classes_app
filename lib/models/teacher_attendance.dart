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
    this.sectionId,
    this.sectionName,
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
  /// Stream / Medium (Section master: Science, Commerce, Hindi, English ...); null on older entries.
  final int? sectionId;
  final String? sectionName;
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
        sectionId: _asIntN(j['sectionId']),
        sectionName: _asStringN(j['sectionName']),
        subjectName: _asStringN(j['subjectName']),
        topic: _asStringN(j['topic']),
        attendanceDate: DateTime.tryParse(_asString(j['attendanceDate'])) ?? DateTime.now(),
        inTime: _asStringN(j['inTime']),
        outTime: _asStringN(j['outTime']),
        totalHours: _asDoubleN(j['totalHours']),
      );

  String get classBatchLabel => [className, batchName].where((e) => e != null && e.isNotEmpty).join(' / ');

  /// "12th / Commerce / Evening" - class, then stream / medium, then batch.
  String get fullLabel => [className, sectionName, batchName].where((e) => e != null && e.trim().isNotEmpty).join(' / ');

  /// Shown the way it was entered: 4 PM - 6 PM stays "4:00 PM - 6:00 PM" (never 16:00 - 18:00).
  String? get inTimeDisplay => _to12h(inTime);
  String? get outTimeDisplay => _to12h(outTime);

  static String? _to12h(String? t) {
    if (t == null || t.length < 5) return t;
    final h = int.tryParse(t.substring(0, 2)), m = int.tryParse(t.substring(3, 5));
    if (h == null || m == null) return t.substring(0, 5);
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
  }

  bool isOnDate(DateTime date) =>
      attendanceDate.year == date.year && attendanceDate.month == date.month && attendanceDate.day == date.day;
}
