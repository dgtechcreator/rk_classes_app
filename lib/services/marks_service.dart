import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/lookup.dart';
import '../models/marks.dart';

String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class MarksEntryData {
  MarksEntryData({
    required this.students,
    required this.subjects,
    required this.examList,
    this.yearId,
    this.subjectId,
    required this.examName,
    required this.testDate,
    required this.maxMarks,
  });

  final List<StudentMarkRow> students;
  final List<Subject> subjects;
  final List<ExamOption> examList;
  final int? yearId;
  final int? subjectId;
  final String examName;
  final String testDate;
  final int maxMarks;
}

class TopStudentsResult {
  TopStudentsResult({
    this.yearId,
    this.classId,
    this.sectionId,
    required this.overallTop5,
    required this.classwiseTop5,
    required this.testwiseTop5,
    required this.subjectwiseTop5,
  });

  final int? yearId;
  final int? classId;
  final int? sectionId;
  final List<TopStudentRow> overallTop5;
  final Map<String, List<TopStudentRow>> classwiseTop5;
  final Map<String, List<TopStudentRow>> testwiseTop5;
  final Map<String, List<TopStudentRow>> subjectwiseTop5;
}

class TestMarksDetailedResult {
  TestMarksDetailedResult({required this.marks, this.testInfo});
  final List<DetailedMarkRow> marks;
  final TestInfo? testInfo;
}

/// Wraps MarksApiController (api/marks) — entry (with prefill for an existing exam), the cascading
/// report lookups (subjects-with-tests -> tests-for-subject -> test-marks-detailed), and top students.
class MarksService {
  final _client = ApiClient.instance;

  Future<MarksEntryData> getEntryData({
    int? yearId,
    int? classId,
    int? sectionId,
    int? batchId,
    int? subjectId,
    String? examName,
    DateTime? testDate,
    int maxMarks = 30,
  }) async {
    final res = await _client.get('/api/marks', query: {
      if (yearId != null) 'yearId': yearId,
      if (classId != null) 'classId': classId,
      if (sectionId != null) 'sectionId': sectionId,
      if (batchId != null) 'batchId': batchId,
      if (subjectId != null) 'subjectId': subjectId,
      if (examName != null && examName.isNotEmpty) 'examName': examName,
      if (testDate != null) 'testDate': _fmtDate(testDate),
      'maxMarks': maxMarks,
    });
    final data = res.data as Map<String, dynamic>;
    return MarksEntryData(
      students: (data['students'] as List? ?? []).map((e) => StudentMarkRow.fromJson(e as Map<String, dynamic>)).toList(),
      subjects: (data['subjects'] as List? ?? []).map((e) => Subject.fromJson(e as Map<String, dynamic>)).toList(),
      examList: (data['examList'] as List? ?? []).map((e) => ExamOption.fromJson(e as Map<String, dynamic>)).toList(),
      yearId: data['yearId'] as int?,
      subjectId: data['subjectId'] as int?,
      examName: data['examName']?.toString() ?? '',
      testDate: data['testDate']?.toString() ?? '',
      maxMarks: data['maxMarks'] as int? ?? 30,
    );
  }

  Future<String> save({
    required String examName,
    required int classId,
    required int yearId,
    required int maxMarks,
    DateTime? testDate,
    required List<Map<String, dynamic>> entries,
  }) async {
    final res = await _client.post('/api/marks/save', data: {
      'examName': examName,
      'classId': classId,
      'yearId': yearId,
      'maxMarks': maxMarks,
      'testDate': testDate?.toIso8601String(),
      'entries': entries,
    });
    final data = res.data as Map<String, dynamic>;
    return data['message']?.toString() ?? 'Marks saved.';
  }

  Future<List<LookupItem>> getReportYears({int? yearId}) async {
    final res = await _client.get('/api/marks/report', query: {if (yearId != null) 'yearId': yearId});
    final data = res.data as Map<String, dynamic>;
    return (data['years'] as List? ?? []).map((e) => LookupItem.fromYear(e as Map<String, dynamic>)).toList();
  }

  Future<List<SubjectWithTestCount>> getSubjectsWithTests(int yearId) async {
    final res = await _client.get('/api/marks/subjects-with-tests', query: {'yearId': yearId});
    return (res.data as List? ?? []).map((e) => SubjectWithTestCount.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TestForSubject>> getTestsForSubject({required int subjectId, required int yearId}) async {
    final res = await _client.get('/api/marks/tests-for-subject', query: {'subjectId': subjectId, 'yearId': yearId});
    return (res.data as List? ?? []).map((e) => TestForSubject.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TestMarksDetailedResult> getTestMarksDetailed({
    required String examName,
    required int classId,
    required int subjectId,
    required int yearId,
  }) async {
    final res = await _client.get('/api/marks/test-marks-detailed', query: {
      'examName': examName,
      'classId': classId,
      'subjectId': subjectId,
      'yearId': yearId,
    });
    final data = res.data as Map<String, dynamic>;
    return TestMarksDetailedResult(
      marks: (data['marks'] as List? ?? []).map((e) => DetailedMarkRow.fromJson(e as Map<String, dynamic>)).toList(),
      testInfo: data['testInfo'] == null ? null : TestInfo.fromJson(data['testInfo'] as Map<String, dynamic>),
    );
  }

  Future<TopStudentsResult> getTopStudents({int? yearId, int? classId, int? sectionId}) async {
    final res = await _client.get('/api/marks/top-students', query: {
      if (yearId != null) 'yearId': yearId,
      if (classId != null) 'classId': classId,
      if (sectionId != null) 'sectionId': sectionId,
    });
    final data = res.data as Map<String, dynamic>;
    List<TopStudentRow> list(dynamic v) => (v as List? ?? []).map((e) => TopStudentRow.fromJson(e as Map<String, dynamic>)).toList();
    Map<String, List<TopStudentRow>> dict(dynamic v) {
      final m = v as Map<String, dynamic>? ?? {};
      return m.map((k, val) => MapEntry(k, list(val)));
    }

    return TopStudentsResult(
      yearId: data['yearId'] as int?,
      classId: data['classId'] as int?,
      sectionId: data['sectionId'] as int?,
      overallTop5: list(data['overallTop5']),
      classwiseTop5: dict(data['classwiseTop5']),
      testwiseTop5: dict(data['testwiseTop5']),
      subjectwiseTop5: dict(data['subjectwiseTop5']),
    );
  }
}
