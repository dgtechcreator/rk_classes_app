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

/// Who deleted a record and when (null parts = it was deleted before this was recorded).
class ActionStamp {
  const ActionStamp(this.by, this.at);
  final String? by;
  final DateTime? at;

  static ActionStamp from(Map<String, dynamic> j) => ActionStamp(
        (j['deletedByName'] as String?)?.trim().isEmpty == true ? null : j['deletedByName'] as String?,
        DateTime.tryParse((j['deletedAt'] ?? '').toString()),
      );

  /// "Deleted by Kapil Sir  •  27 Oct 2026, 3:10 PM"
  String get label {
    final when = at == null ? null : '${at!.day.toString().padLeft(2, '0')} ${_months[at!.month - 1]} ${at!.year}, ${_time(at!)}';
    if (by == null && when == null) return 'Deleted (who / when was not recorded)';
    return 'Deleted by ${by ?? '—'}${when == null ? '' : '  •  $when'}';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class DeletedRecordsData {
  DeletedRecordsData({
    required this.students, required this.faculty, required this.receipts, required this.users, required this.others,
    this.studentStamps = const {}, this.facultyStamps = const {}, this.userStamps = const {}, this.receiptStamps = const {},
  });
  final Map<int, ActionStamp> studentStamps, facultyStamps, userStamps, receiptStamps;
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
      studentStamps: _stamps(data['students'], 'studentId'),
      facultyStamps: _stamps(data['faculty'], 'facultyId'),
      userStamps: _stamps(data['users'], 'userId'),
      receiptStamps: _stamps(data['receipts'], 'paymentId'),
    );
  }

  static Map<int, ActionStamp> _stamps(dynamic list, String idKey) => {
        for (final e in (list as List? ?? []))
          if (e is Map<String, dynamic>) ((e[idKey] as num?)?.toInt() ?? 0): ActionStamp.from(e),
      };

  Future<void> restoreStudent(int id) async => _client.post('/api/deleted/students/$id/restore');
  Future<void> restoreFaculty(int id) async => _client.post('/api/deleted/faculty/$id/restore');
  Future<void> restoreOther(String kind, int id) async => _client.post('/api/deleted/others/$kind/$id/restore');
  Future<void> restoreUser(int id) async => _client.post('/api/deleted/users/$id/restore');
  Future<void> restoreReceipt(int id) async => _client.post('/api/deleted/receipts/$id/restore');
}
