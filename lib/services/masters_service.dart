import '../core/api_client.dart';
import '../models/masters.dart';

/// Wraps the read-only `/api/lookup/*` endpoints (the only GET list endpoints the API exposes for
/// these entities — MastersApiController itself is save/delete only) and the `/api/masters/*`
/// save/delete endpoints. Because `/api/lookup/*` filters to IsActive=1 only (see LookupRepo), this
/// screen can only ever list currently-active rows — there is no API endpoint that also returns
/// inactive ones, so "delete" (soft, server-side) simply removes a row from view here.
class MastersService {
  final _client = ApiClient.instance;

  Future<List<AcademicYear>> getYears() async {
    final res = await _client.get('/api/lookup/years');
    return (res.data as List).map((e) => AcademicYear.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveYear({required int yearId, required String yearName, required bool isCurrent, bool isActive = true}) =>
      _client.post('/api/masters/years/save', data: {
        'yearId': yearId, 'yearName': yearName, 'isCurrent': isCurrent, 'isActive': isActive,
      });

  Future<void> deleteYear(int id) => _client.post('/api/masters/years/$id/delete');

  Future<List<SchoolClass>> getClasses() async {
    final res = await _client.get('/api/lookup/classes');
    return (res.data as List).map((e) => SchoolClass.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveClass({required int classId, required String className, required int orderNo, bool isActive = true}) =>
      _client.post('/api/masters/classes/save', data: {
        'classId': classId, 'className': className, 'orderNo': orderNo, 'isActive': isActive,
      });

  Future<void> deleteClass(int id) => _client.post('/api/masters/classes/$id/delete');

  Future<List<SchoolSection>> getSections() async {
    final res = await _client.get('/api/lookup/sections');
    return (res.data as List).map((e) => SchoolSection.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveSection({required int sectionId, required String sectionName, bool isActive = true}) =>
      _client.post('/api/masters/sections/save', data: {
        'sectionId': sectionId, 'sectionName': sectionName, 'isActive': isActive,
      });

  Future<void> deleteSection(int id) => _client.post('/api/masters/sections/$id/delete');

  Future<List<SchoolBatch>> getBatches() async {
    final res = await _client.get('/api/lookup/batches');
    return (res.data as List).map((e) => SchoolBatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveBatch({required int batchId, required String batchName, bool isActive = true}) =>
      _client.post('/api/masters/batches/save', data: {
        'batchId': batchId, 'batchName': batchName, 'isActive': isActive,
      });

  Future<void> deleteBatch(int id) => _client.post('/api/masters/batches/$id/delete');

  Future<List<ExpenseCategory>> getExpenseCats() async {
    final res = await _client.get('/api/lookup/exp-cats');
    return (res.data as List).map((e) => ExpenseCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveExpenseCat({required int categoryId, required String categoryName, bool isActive = true}) =>
      _client.post('/api/masters/expcats/save', data: {
        'categoryId': categoryId, 'categoryName': categoryName, 'isActive': isActive,
      });

  Future<void> deleteExpenseCat(int id) => _client.post('/api/masters/expcats/$id/delete');

  /// Subjects are always fetched scoped to one class — `/api/lookup/subjects` has no "all classes"
  /// mode (it filters `WHERE ClassId={classId}`), matching how Subjects are used everywhere else
  /// in the app (marks entry, exams).
  Future<List<MasterSubject>> getSubjectsForClass(int classId) async {
    final res = await _client.get('/api/lookup/subjects', query: {'classId': classId});
    return (res.data as List).map((e) => MasterSubject.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveSubject({
    required int subjectId,
    required String subjectName,
    String? subjectCode,
    required int classId,
    int maxMarks = 100,
    int passMarks = 35,
    bool isActive = true,
  }) =>
      _client.post('/api/masters/subjects/save', data: {
        'subjectId': subjectId,
        'subjectName': subjectName,
        'subjectCode': subjectCode,
        'classId': classId,
        'maxMarks': maxMarks,
        'passMarks': passMarks,
        'isActive': isActive,
      });

  Future<void> deleteSubject(int id) => _client.post('/api/masters/subjects/$id/delete');

  // ── Attendance batches (groups of students for the green/red attendance cards) ──────────────

  Future<List<AttendanceBatchInfo>> getAttendanceBatches() async {
    final res = await _client.get('/api/masters/attendance-batches');
    final data = res.data as Map<String, dynamic>;
    return (data['attendanceBatches'] as List? ?? []).map((e) => AttendanceBatchInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AttendanceBatchInfo> getAttendanceBatch(int batchId) async {
    final res = await _client.get('/api/masters/attendance-batches/$batchId/edit');
    final data = res.data as Map<String, dynamic>;
    return AttendanceBatchInfo.fromJson(data['batch'] as Map<String, dynamic>);
  }

  /// Active students for the picker; pass nothing to list everyone ([classId] 0 means "all classes").
  Future<List<BatchStudentOption>> getStudentsForAttendanceBatch({int? classId, int? sectionId, int? batchId}) async {
    final res = await _client.get('/api/masters/attendance-batches/students', query: {
      'classId': classId ?? 0,
      if (sectionId != null) 'sectionId': sectionId,
      if (batchId != null) 'batchId': batchId,
    });
    final data = res.data;
    if (data is Map<String, dynamic> && data['error'] != null) throw ApiException(data['error'].toString());
    return (data as List).map((e) => BatchStudentOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [batchId] 0 creates a new batch, anything else updates that batch (name + students).
  Future<void> saveAttendanceBatch({required int batchId, required String batchName, required List<int> studentIds}) async {
    final res = batchId == 0
        ? await _client.post('/api/masters/attendance-batches/create', data: {'batchName': batchName, 'studentIds': studentIds})
        : await _client.post('/api/masters/attendance-batches/save', data: {'batchId': batchId, 'batchName': batchName, 'studentIds': studentIds});
    final data = res.data;
    if (data is Map<String, dynamic> && data['success'] == false) {
      throw ApiException(data['message']?.toString() ?? 'Could not save the batch.');
    }
  }

  Future<void> deleteAttendanceBatch(int id) => _client.post('/api/masters/attendance-batches/$id/delete');
}
