int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _asIntN(dynamic v) => v == null ? null : _asInt(v);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? _asDoubleN(dynamic v) => v == null ? null : _asDouble(v);
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();
bool _asBool(dynamic v) => v == true || v?.toString().toLowerCase() == 'true';

/// Mirrors SchoolMS.Domain.Subject — a class's subject with its own MaxMarks/PassMarks, from
/// GET /api/lookup/subjects?classId= or the `subjects` field of GET /api/marks.
class Subject {
  Subject({
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    this.classId,
    this.className,
    this.maxMarks = 100,
    this.passMarks = 35,
    this.isActive = true,
  });

  final int subjectId;
  final String subjectName;
  final String? subjectCode;
  final int? classId;
  final String? className;
  final int maxMarks;
  final int passMarks;
  final bool isActive;

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        subjectId: _asInt(j['subjectId']),
        subjectName: _asString(j['subjectName']),
        subjectCode: _asStringN(j['subjectCode']),
        classId: _asIntN(j['classId']),
        className: _asStringN(j['className']),
        maxMarks: j['maxMarks'] == null ? 100 : _asInt(j['maxMarks']),
        passMarks: j['passMarks'] == null ? 35 : _asInt(j['passMarks']),
        isActive: j['isActive'] != false,
      );
}

/// Mirrors SchoolMS.Domain.Exam — from GET /api/lookup/exams or the `examList` field of GET /api/marks.
class ExamOption {
  ExamOption({
    required this.examId,
    required this.examName,
    this.classId,
    this.className,
    this.academicYearId,
    this.yearName,
    this.testDate,
    this.entryCount = 0,
    this.subjectId,
    this.maxMarks,
  });

  final int examId;
  final String examName;
  final int? classId;
  final String? className;
  final int? academicYearId;
  final String? yearName;
  final DateTime? testDate;
  final int entryCount;
  final int? subjectId;
  final int? maxMarks;

  factory ExamOption.fromJson(Map<String, dynamic> j) => ExamOption(
        examId: _asInt(j['examId']),
        examName: _asString(j['examName']),
        classId: _asIntN(j['classId']),
        className: _asStringN(j['className']),
        academicYearId: _asIntN(j['academicYearId']),
        yearName: _asStringN(j['yearName']),
        testDate: j['testDate'] == null ? null : DateTime.tryParse(j['testDate'].toString()),
        entryCount: _asInt(j['entryCount']),
        subjectId: _asIntN(j['subjectId']),
        maxMarks: _asIntN(j['maxMarks']),
      );
}

/// One student's row in the marks-entry list — mirrors SchoolMS.Domain.StudentMarkRow. Blank
/// (marksObtained null) until an exam+subject with existing marks is selected.
class StudentMarkRow {
  StudentMarkRow({
    required this.studentId,
    required this.fullName,
    required this.admissionNo,
    this.rollNo,
    this.className,
    this.sectionName,
    this.batchName,
    this.marksObtained,
    this.maxMarks = 30,
    this.grade,
    this.isAbsent = false,
    this.testDate,
  });

  final int studentId;
  final String fullName;
  final String admissionNo;
  final String? rollNo;
  final String? className;
  final String? sectionName;
  final String? batchName;
  final double? marksObtained;
  final int maxMarks;
  final String? grade;
  final bool isAbsent;
  final DateTime? testDate;

  factory StudentMarkRow.fromJson(Map<String, dynamic> j) => StudentMarkRow(
        studentId: _asInt(j['studentId']),
        fullName: _asString(j['fullName']),
        admissionNo: _asString(j['admissionNo']),
        rollNo: _asStringN(j['rollNo']),
        className: _asStringN(j['className']),
        sectionName: _asStringN(j['sectionName']),
        batchName: _asStringN(j['batchName']),
        marksObtained: _asDoubleN(j['marksObtained']),
        maxMarks: j['maxMarks'] == null ? 30 : _asInt(j['maxMarks']),
        grade: _asStringN(j['grade']),
        isAbsent: _asBool(j['isAbsent']),
        testDate: j['testDate'] == null ? null : DateTime.tryParse(j['testDate'].toString()),
      );

  String get classLabel => [className, sectionName, batchName].where((e) => e != null && e.isNotEmpty).join(' / ');
}

/// Mirrors SchoolMS.Domain.TopStudent — a ranked row from GET /api/marks/top-students.
class TopStudentRow {
  TopStudentRow({
    required this.studentId,
    required this.fullName,
    required this.admissionNo,
    this.rollNo,
    this.className,
    this.sectionName,
    this.batchName,
    this.yearName,
    this.examName,
    this.subjectName,
    this.subjectCode,
    required this.totalObtained,
    required this.totalMax,
    required this.percentage,
    required this.rank,
  });

  final int studentId;
  final String fullName;
  final String admissionNo;
  final String? rollNo;
  final String? className;
  final String? sectionName;
  final String? batchName;
  final String? yearName;
  final String? examName;
  final String? subjectName;
  final String? subjectCode;
  final double totalObtained;
  final double totalMax;
  final double percentage;
  final int rank;

  factory TopStudentRow.fromJson(Map<String, dynamic> j) => TopStudentRow(
        studentId: _asInt(j['studentId']),
        fullName: _asString(j['fullName']),
        admissionNo: _asString(j['admissionNo']),
        rollNo: _asStringN(j['rollNo']),
        className: _asStringN(j['className']),
        sectionName: _asStringN(j['sectionName']),
        batchName: _asStringN(j['batchName']),
        yearName: _asStringN(j['yearName']),
        examName: _asStringN(j['examName']),
        subjectName: _asStringN(j['subjectName']),
        subjectCode: _asStringN(j['subjectCode']),
        totalObtained: _asDouble(j['totalObtained']),
        totalMax: _asDouble(j['totalMax']),
        percentage: _asDouble(j['percentage']),
        rank: _asInt(j['rank']),
      );

  String get classLabel => [className, sectionName, batchName].where((e) => e != null && e.isNotEmpty).join(' / ');
}

/// One subject that has at least one test recorded in a year — from GET /api/marks/subjects-with-tests.
class SubjectWithTestCount {
  SubjectWithTestCount({required this.subjectId, required this.subjectName, required this.testCount});
  final int subjectId;
  final String subjectName;
  final int testCount;

  factory SubjectWithTestCount.fromJson(Map<String, dynamic> j) => SubjectWithTestCount(
        subjectId: _asInt(j['subjectId']),
        subjectName: _asString(j['subjectName']),
        testCount: _asInt(j['testCount']),
      );
}

/// One test (exam) recorded for a subject — from GET /api/marks/tests-for-subject.
class TestForSubject {
  TestForSubject({
    required this.examId,
    required this.examName,
    this.testDate,
    this.classId,
    this.className,
    this.studentCount = 0,
  });

  final int examId;
  final String examName;
  final String? testDate;
  final int? classId;
  final String? className;
  final int studentCount;

  factory TestForSubject.fromJson(Map<String, dynamic> j) => TestForSubject(
        examId: _asInt(j['examId']),
        examName: _asString(j['examName']),
        testDate: _asStringN(j['testDate']),
        classId: _asIntN(j['classId']),
        className: _asStringN(j['className']),
        studentCount: _asInt(j['studentCount']),
      );
}

/// One row of GET /api/marks/test-marks-detailed's `marks` list.
class DetailedMarkRow {
  DetailedMarkRow({
    required this.studentId,
    required this.fullName,
    this.className,
    this.batchName,
    this.obtainedMarks,
    this.maxMarks = 100,
    this.grade,
  });

  final int studentId;
  final String fullName;
  final String? className;
  final String? batchName;
  final double? obtainedMarks;
  final int maxMarks;
  final String? grade;

  factory DetailedMarkRow.fromJson(Map<String, dynamic> j) => DetailedMarkRow(
        studentId: _asInt(j['studentId']),
        fullName: _asString(j['fullName']),
        className: _asStringN(j['className']),
        batchName: _asStringN(j['batchName']),
        obtainedMarks: _asDoubleN(j['obtainedMarks']),
        maxMarks: j['maxMarks'] == null ? 100 : _asInt(j['maxMarks']),
        grade: _asStringN(j['grade']),
      );

  double get percentage => maxMarks > 0 && obtainedMarks != null ? (obtainedMarks! * 100 / maxMarks) : 0;
}

/// The `testInfo` header of GET /api/marks/test-marks-detailed.
class TestInfo {
  TestInfo({this.examName, this.subjectName, this.className, this.testDate});
  final String? examName;
  final String? subjectName;
  final String? className;
  final String? testDate;

  factory TestInfo.fromJson(Map<String, dynamic> j) => TestInfo(
        examName: _asStringN(j['examName']),
        subjectName: _asStringN(j['subjectName']),
        className: _asStringN(j['className']),
        testDate: _asStringN(j['testDate']),
      );
}
