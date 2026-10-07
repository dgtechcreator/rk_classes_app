import '../core/api_client.dart';
import '../models/student.dart';
import '../models/toppers.dart';

class ParentService {
  final _client = ApiClient.instance;

  Future<List<Student>> getChildren() async {
    final res = await _client.get('/api/parent/children');
    return (res.data as List).map((e) => Student.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ParentDashboardData> getDashboard(int studentId) async {
    final res = await _client.get('/api/parent/dashboard/$studentId');
    return ParentDashboardData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<dynamic>> getTop5(int studentId, String subjectName) async {
    final res = await _client.get('/api/parent/top5', query: {'studentId': studentId, 'subjectName': subjectName});
    final data = res.data as Map<String, dynamic>;
    return data['top5'] as List? ?? [];
  }

  /// Top 5 (overall + per subject) of the child's own class and medium.
  Future<ClassToppers> getToppers(int studentId) async {
    final res = await _client.get('/api/parent/toppers', query: {'studentId': studentId});
    return ClassToppers.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> sendContactMessage({required String name, required String email, required String subject, required String message}) async {
    await _client.post('/api/parent/contact', data: {'name': name, 'email': email, 'subject': subject, 'message': message});
  }
}
