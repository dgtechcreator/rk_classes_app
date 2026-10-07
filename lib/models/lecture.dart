int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _asIntN(dynamic v) => v == null ? null : _asInt(v);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();

const lectureStatuses = ['Scheduled', 'Completed', 'Cancelled'];

/// One scheduled lecture — mirrors LectureHelpers.Dto on the server.
class Lecture {
  Lecture({
    required this.lectureId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
    this.batchId,
    this.batchName,
    required this.groupLabel,
    required this.subject,
    required this.facultyId,
    this.teacher,
    this.topic,
    this.remarks,
    required this.status,
    this.statusNote,
    this.isRepeating = false,
    this.needsUpdate = false,
  });

  final int lectureId;
  final DateTime date;
  final String startTime; // HH:mm
  final String endTime;
  final int classId;
  final String? className;
  final int? sectionId;
  final String? sectionName;
  final int? batchId;
  final String? batchName;
  final String groupLabel;
  final String subject;
  final int facultyId;
  final String? teacher;
  final String? topic;
  final String? remarks;
  final String status;
  final String? statusNote;
  final bool isRepeating;

  /// Scheduled, but its time has passed without being marked done / cancelled.
  final bool needsUpdate;

  bool get isCompleted => status == 'Completed';
  bool get isCancelled => status == 'Cancelled';
  String get timeRange => '$startTime – $endTime';

  factory Lecture.fromJson(Map<String, dynamic> j) => Lecture(
        lectureId: _asInt(j['lectureId']),
        date: DateTime.tryParse(_asString(j['date'])) ?? DateTime.now(),
        startTime: _asString(j['startTime']),
        endTime: _asString(j['endTime']),
        classId: _asInt(j['classId']),
        className: _asStringN(j['className']),
        sectionId: _asIntN(j['sectionId']),
        sectionName: _asStringN(j['sectionName']),
        batchId: _asIntN(j['batchId']),
        batchName: _asStringN(j['batchName']),
        groupLabel: _asString(j['groupLabel']),
        subject: _asString(j['subject']),
        facultyId: _asInt(j['facultyId']),
        teacher: _asStringN(j['teacher']),
        topic: _asStringN(j['topic']),
        remarks: _asStringN(j['remarks']),
        status: _asString(j['status']),
        statusNote: _asStringN(j['statusNote']),
        isRepeating: j['isRepeating'] == true,
        needsUpdate: j['needsUpdate'] == true,
      );
}

class LectureTotals {
  LectureTotals({this.total = 0, this.held = 0, this.scheduled = 0, this.cancelled = 0, this.notUpdated = 0, this.hoursHeld = 0});
  final int total, held, scheduled, cancelled, notUpdated;
  final double hoursHeld;

  factory LectureTotals.fromJson(Map<String, dynamic>? j) => j == null
      ? LectureTotals()
      : LectureTotals(
          total: _asInt(j['total']),
          held: _asInt(j['held']),
          scheduled: _asInt(j['scheduled']),
          cancelled: _asInt(j['cancelled']),
          notUpdated: _asInt(j['notUpdated']),
          hoursHeld: _asDouble(j['hoursHeld']),
        );
}

class LectureListResult {
  LectureListResult({required this.totals, required this.lectures});
  final LectureTotals totals;
  final List<Lecture> lectures;

  factory LectureListResult.fromJson(Map<String, dynamic> j) => LectureListResult(
        totals: LectureTotals.fromJson(j['totals'] as Map<String, dynamic>?),
        lectures: (j['lectures'] as List? ?? []).map((e) => Lecture.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class IdName {
  IdName(this.id, this.name);
  final int id;
  final String name;
}

/// Dropdown data for the schedule form and the filter bars.
class LectureOptions {
  LectureOptions({required this.classes, required this.sections, required this.batches, required this.subjects, required this.teachers});
  final List<IdName> classes, sections, batches, teachers;
  final List<String> subjects;

  factory LectureOptions.fromJson(Map<String, dynamic> j) {
    List<IdName> list(String k, [String nameKey = 'name']) =>
        (j[k] as List? ?? []).map((e) => IdName(_asInt((e as Map)['id']), _asString(e[nameKey]))).toList();
    return LectureOptions(
      classes: list('classes'),
      sections: list('sections'),
      batches: list('batches'),
      teachers: list('teachers', 'displayName'),
      subjects: (j['subjects'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

/// Active filters shared by the schedule and summary screens (null = no filter on that field).
class LectureFilters {
  LectureFilters({this.from, this.to, this.classId, this.sectionId, this.batchId, this.subject, this.facultyId, this.status});
  DateTime? from, to;
  int? classId, sectionId, batchId, facultyId;
  String? subject, status;

  LectureFilters copy() => LectureFilters(
      from: from, to: to, classId: classId, sectionId: sectionId, batchId: batchId, subject: subject, facultyId: facultyId, status: status);

  int get activeCount => [classId, sectionId, batchId, subject, facultyId, status].where((e) => e != null).length;
}

class LectureSummaryRow {
  LectureSummaryRow({
    required this.key,
    required this.label,
    this.facultyId,
    required this.scheduled,
    required this.completed,
    required this.cancelled,
    required this.total,
    required this.hoursHeld,
    required this.notUpdated,
  });
  final String key;
  final String label;
  final int? facultyId;
  final int scheduled, completed, cancelled, total, notUpdated;
  final double hoursHeld;

  factory LectureSummaryRow.fromJson(Map<String, dynamic> j) => LectureSummaryRow(
        key: _asString(j['key']),
        label: _asString(j['label']),
        facultyId: _asIntN(j['facultyId']),
        scheduled: _asInt(j['scheduled']),
        completed: _asInt(j['completed']),
        cancelled: _asInt(j['cancelled']),
        total: _asInt(j['total']),
        hoursHeld: _asDouble(j['hoursHeld']),
        notUpdated: _asInt(j['notUpdated']),
      );
}

class LectureSummaryResult {
  LectureSummaryResult({required this.totals, required this.rows});
  final LectureTotals totals;
  final List<LectureSummaryRow> rows;

  factory LectureSummaryResult.fromJson(Map<String, dynamic> j) => LectureSummaryResult(
        totals: LectureTotals.fromJson(j['totals'] as Map<String, dynamic>?),
        rows: (j['rows'] as List? ?? []).map((e) => LectureSummaryRow.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class LabelCounts {
  LabelCounts({required this.label, required this.held, required this.scheduled, required this.cancelled});
  final String label;
  final int held, scheduled, cancelled;

  factory LabelCounts.fromJson(Map<String, dynamic> j) => LabelCounts(
      label: _asString(j['label']), held: _asInt(j['held']), scheduled: _asInt(j['scheduled']), cancelled: _asInt(j['cancelled']));
}

/// One month's counts (a teacher's own, or a parent's child) with per-class and per-subject breakdowns.
class MonthLectures {
  MonthLectures({required this.label, required this.totals, required this.byGroup, required this.bySubject});
  final String label;
  final LectureTotals totals;
  final List<LabelCounts> byGroup, bySubject;

  factory MonthLectures.fromJson(Map<String, dynamic> j) {
    List<LabelCounts> list(String k) => (j[k] as List? ?? []).map((e) => LabelCounts.fromJson(e as Map<String, dynamic>)).toList();
    return MonthLectures(
      label: _asString(j['label']),
      totals: LectureTotals.fromJson(j['totals'] as Map<String, dynamic>?),
      byGroup: list('byGroup'),
      bySubject: list('bySubject'),
    );
  }
}

/// GET /api/lectures/mine
class MyLectures {
  MyLectures({required this.linked, this.message, this.facultyName, this.lectures = const [], this.thisMonth, this.lastMonth});
  final bool linked;
  final String? message;
  final String? facultyName;
  final List<Lecture> lectures;
  final MonthLectures? thisMonth, lastMonth;

  factory MyLectures.fromJson(Map<String, dynamic> j) => MyLectures(
        linked: j['linked'] != false,
        message: _asStringN(j['message']),
        facultyName: _asStringN(j['facultyName']),
        lectures: (j['lectures'] as List? ?? []).map((e) => Lecture.fromJson(e as Map<String, dynamic>)).toList(),
        thisMonth: j['thisMonth'] == null ? null : MonthLectures.fromJson(j['thisMonth'] as Map<String, dynamic>),
        lastMonth: j['lastMonth'] == null ? null : MonthLectures.fromJson(j['lastMonth'] as Map<String, dynamic>),
      );
}

/// GET /api/parent/lectures — one day's lectures + the counts for that day's month.
class ParentLectures {
  ParentLectures({required this.date, required this.lectures, this.month});
  final DateTime date;
  final List<Lecture> lectures;
  final MonthLectures? month;

  factory ParentLectures.fromJson(Map<String, dynamic> j) => ParentLectures(
        date: DateTime.tryParse(_asString(j['date'])) ?? DateTime.now(),
        lectures: (j['lectures'] as List? ?? []).map((e) => Lecture.fromJson(e as Map<String, dynamic>)).toList(),
        month: j['month'] == null ? null : MonthLectures.fromJson(j['month'] as Map<String, dynamic>),
      );
}
