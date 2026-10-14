import '../core/api_client.dart';
import '../models/app_user.dart';
import '../models/faculty.dart';
import '../models/student.dart';

/// A soft-deleted expense / teacher payment / teacher attendance entry / lecture (one generic row).
class DeletedItem {
  DeletedItem({required this.kind, required this.kindLabel, required this.id, required this.title, required this.subtitle, this.deletedAt, this.deletedBy});
  final String kind; // expense | teacherpayment | teacherattendance | lecture
  final String kindLabel;
  final int id;
  final String title;
  final String subtitle;
  final DateTime? deletedAt;
  final String? deletedBy;

  factory DeletedItem.fromJson(Map<String, dynamic> j) => DeletedItem(
        kind: (j['kind'] ?? '').toString(),
        kindLabel: (j['kindLabel'] ?? '').toString(),
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        deletedAt: DateTime.tryParse((j['deletedAt'] ?? '').toString()),
        deletedBy: j['deletedByName'] as String?,
      );
}

class DeletedRecordsData {
  DeletedRecordsData({required this.students, required this.faculty, required this.receipts, required this.users, required this.others});
  final List<Student> students;
  final List<Faculty> faculty;
  final List<FeePayment> receipts;
  final List<AppUser> users;
  final List<DeletedItem> others;
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
      users: (data['users'] as List? ?? []).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList(),
      others: (data['others'] as List? ?? []).map((e) => DeletedItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> restoreStudent(int id) async => _client.post('/api/deleted/students/$id/restore');
  Future<void> restoreFaculty(int id) async => _client.post('/api/deleted/faculty/$id/restore');
  Future<void> restoreOther(String kind, int id) async => _client.post('/api/deleted/others/$kind/$id/restore');
  Future<void> restoreUser(int id) async => _client.post('/api/deleted/users/$id/restore');
  Future<void> restoreReceipt(int id) async => _client.post('/api/deleted/receipts/$id/restore');
}
