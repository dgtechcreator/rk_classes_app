int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _asIntN(dynamic v) => v == null ? null : _asInt(v);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();

/// One student's attendance status for a given date — mirrors AttendanceApiController's `records`
/// (AttendanceRecord in SchoolMS.Domain). When fetched without a class filter, only already-marked
/// rows come back; with a class/section/batch filter, every student in that combo comes back, each
/// defaulting to attendanceStatus "Present" until saved (attendanceId is null until then).
class AttendanceRecord {
  AttendanceRecord({
    required this.studentId,
    required this.fullName,
    required this.admissionNo,
    this.rollNo,
    this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
    this.batchId,
    this.batchName,
    this.profilePicPath,
    this.attendanceStatus = 'Present',
    this.attendanceId,
    this.remarks,
    this.subject,
    this.sirName,
    this.phone,
    this.fatherPhone,
    this.motherPhone,
  });

  final int studentId;
  final String fullName;
  final String admissionNo;
  final String? rollNo;
  final int? classId;
  final String? className;
  final int? sectionId;
  final String? sectionName;
  final int? batchId;
  final String? batchName;
  final String? profilePicPath;
  final String attendanceStatus;
  final int? attendanceId;
  final String? remarks;
  final String? subject;
  final String? sirName;
  final String? phone;
  final String? fatherPhone;
  final String? motherPhone;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        studentId: _asInt(j['studentId']),
        fullName: _asString(j['fullName']),
        admissionNo: _asString(j['admissionNo']),
        rollNo: _asStringN(j['rollNo']),
        classId: _asIntN(j['classId']),
        className: _asStringN(j['className']),
        sectionId: _asIntN(j['sectionId']),
        sectionName: _asStringN(j['sectionName']),
        batchId: _asIntN(j['batchId']),
        batchName: _asStringN(j['batchName']),
        profilePicPath: _asStringN(j['profilePicPath']),
        attendanceStatus: j['attendanceStatus'] == null ? 'Present' : _asString(j['attendanceStatus']),
        attendanceId: _asIntN(j['attendanceId']),
        remarks: _asStringN(j['remarks']),
        subject: _asStringN(j['subject']),
        sirName: _asStringN(j['sirName']),
        phone: _asStringN(j['phone']),
        fatherPhone: _asStringN(j['fatherPhone']),
        motherPhone: _asStringN(j['motherPhone']),
      );

  String get classLabel => [className, sectionName, batchName].where((e) => e != null && e.isNotEmpty).join(' / ');
}

/// One student's monthly attendance summary — mirrors AttendanceApiController's `report` (list of
/// AttendanceReport in SchoolMS.Domain). Named *Row (not AttendanceReport) to avoid colliding with the
/// unrelated single-student summary class of the same name already in models/student.dart.
class AttendanceReportRow {
  AttendanceReportRow({
    required this.studentId,
    required this.fullName,
    required this.admissionNo,
    this.className,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.totalDays,
    required this.attendancePct,
    this.createdByName,
  });

  final int studentId;
  final String fullName;
  final String admissionNo;
  final String? className;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int totalDays;
  final double attendancePct;
  final String? createdByName;

  factory AttendanceReportRow.fromJson(Map<String, dynamic> j) => AttendanceReportRow(
        studentId: _asInt(j['studentId']),
        fullName: _asString(j['fullName']),
        admissionNo: _asString(j['admissionNo']),
        className: _asStringN(j['className']),
        presentDays: _asInt(j['presentDays']),
        absentDays: _asInt(j['absentDays']),
        lateDays: _asInt(j['lateDays']),
        totalDays: _asInt(j['totalDays']),
        attendancePct: _asDouble(j['attendancePct']),
        createdByName: _asStringN(j['createdByName']),
      );
}

/// One day's status for one student — mirrors AttendanceApiController's `date-grid` `attData`
/// (DateAttendanceEntry in SchoolMS.Domain), used to build a student's day-by-day detail view.
class DateAttendanceEntry {
  DateAttendanceEntry({required this.studentId, required this.attendanceDate, required this.status});

  final int studentId;
  final DateTime attendanceDate;
  final String status;

  factory DateAttendanceEntry.fromJson(Map<String, dynamic> j) => DateAttendanceEntry(
        studentId: _asInt(j['studentId']),
        attendanceDate: DateTime.tryParse(_asString(j['attendanceDate'])) ?? DateTime.now(),
        status: j['status'] == null ? 'Present' : _asString(j['status']),
      );
}
