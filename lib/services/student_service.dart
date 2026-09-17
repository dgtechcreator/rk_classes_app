import '../core/api_client.dart';
import '../models/student.dart';

class StudentListResult {
  StudentListResult({required this.students, required this.total});
  final List<Student> students;
  final int total;
}

class StudentDetail {
  StudentDetail({required this.student, required this.fees});
  final Student student;
  final List<dynamic> fees;
}

class StudentService {
  final _client = ApiClient.instance;

  Future<StudentListResult> getAll({String? search, int? classId, int? sectionId, int? batchId, String status = 'Active'}) async {
    final res = await _client.get('/api/students', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (classId != null) 'classId': classId,
      if (sectionId != null) 'sectionId': sectionId,
      if (batchId != null) 'batchId': batchId,
      'status': status,
    });
    final data = res.data as Map<String, dynamic>;
    return StudentListResult(
      students: (data['students'] as List).map((e) => Student.fromJson(e as Map<String, dynamic>)).toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<StudentDetail> getById(int id) async {
    final res = await _client.get('/api/students/$id');
    final data = res.data as Map<String, dynamic>;
    return StudentDetail(student: Student.fromJson(data['student'] as Map<String, dynamic>), fees: data['fees'] as List? ?? []);
  }

  Future<int> save(Map<String, dynamic> studentJson) async {
    final res = await _client.post('/api/students/save', data: studentJson);
    final data = res.data as Map<String, dynamic>;
    return data['studentId'] as int? ?? 0;
  }

  Future<void> delete(int id) async => _client.post('/api/students/$id/delete');
}
