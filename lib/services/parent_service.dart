import '../core/api_client.dart';
import '../models/student.dart';
import '../models/student_activity.dart';
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

  /// What happened to my children, newest first. [studentId] limits it to one child.
  Future<({List<StudentActivity> items, int unread})> getNotifications({int? studentId}) async {
    final res = await _client.get('/api/parent/notifications', query: {'studentId': ?studentId, 'take': 150});
    final data = res.data as Map<String, dynamic>;
    return (
      items: (data['items'] as List? ?? []).map((e) => StudentActivity.fromJson(e as Map<String, dynamic>)).toList(),
      unread: (data['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> getUnreadCount() async {
    final res = await _client.get('/api/parent/notifications/unread-count');
    return ((res.data as Map<String, dynamic>)['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> markNotificationsRead() async => _client.post('/api/parent/notifications/read');

  Future<void> sendContactMessage({required String name, required String email, required String subject, required String message}) async {
    await _client.post('/api/parent/contact', data: {'name': name, 'email': email, 'subject': subject, 'message': message});
  }
}
