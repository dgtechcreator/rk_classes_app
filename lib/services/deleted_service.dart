import '../core/api_client.dart';
import '../models/faculty.dart';
import '../models/student.dart';

class DeletedRecordsData {
  DeletedRecordsData({required this.students, required this.faculty, required this.receipts});
  final List<Student> students;
  final List<Faculty> faculty;
  final List<FeePayment> receipts;
}

/// Wraps GET/POST api/deleted/* (DeletedApiController) — admin-only soft-delete trash/restore, matching
/// the backend's [ApiRequireAdmin] gate exactly (deliberately tighter than the MVC page's own
/// per-action checks, since a JSON endpoint is easier to script against — see the controller's own
/// comment for the reasoning).
class DeletedService {
  final _client = ApiClient.instance;

  Future<DeletedRecordsData> getAll() async {
    final res = await _client.get('/api/deleted');
    final data = res.data as Map<String, dynamic>;
    return DeletedRecordsData(
      students: (data['students'] as List? ?? []).map((e) => Student.fromJson(e as Map<String, dynamic>)).toList(),
      faculty: (data['faculty'] as List? ?? []).map((e) => Faculty.fromJson(e as Map<String, dynamic>)).toList(),
      receipts: (data['receipts'] as List? ?? []).map((e) => FeePayment.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> restoreStudent(int id) async => _client.post('/api/deleted/students/$id/restore');
  Future<void> restoreFaculty(int id) async => _client.post('/api/deleted/faculty/$id/restore');
  Future<void> restoreReceipt(int id) async => _client.post('/api/deleted/receipts/$id/restore');
}
