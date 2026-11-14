import '../core/api_client.dart';

class NotifyPerson {
  NotifyPerson(this.id, this.label, [this.sub = '']);
  final int id;
  final String label;
  final String sub;
}

class NotifyResult {
  NotifyResult(this.students, this.staff, this.message);
  final int students;
  final int staff;
  final String message;
}

/// "Send notification" (admin): one message to everybody, a group, or chosen students / staff.
class NotifyService {
  final _client = ApiClient.instance;

  Future<List<NotifyPerson>> staff() async {
    final res = await _client.get('/api/notify/staff');
    final list = ((res.data as Map<String, dynamic>)['staff'] as List? ?? []);
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return NotifyPerson((m['id'] as num).toInt(), m['name']?.toString() ?? '', m['role']?.toString() ?? '');
    }).toList();
  }

  Future<List<NotifyPerson>> students(String q) async {
    final res = await _client.get('/api/notify/students', query: {'q': q});
    final list = ((res.data as Map<String, dynamic>)['students'] as List? ?? []);
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return NotifyPerson((m['id'] as num).toInt(), m['label']?.toString() ?? '');
    }).toList();
  }

  Future<NotifyResult> send({
    required String audience,
    required String title,
    required String message,
    int? classId,
    int? sectionId,
    int? batchId,
    List<int> studentIds = const [],
    List<int> userIds = const [],
  }) async {
    final res = await _client.post('/api/notify/send', data: {
      'audience': audience,
      'title': title,
      'message': message,
      'classId': classId,
      'sectionId': sectionId,
      'batchId': batchId,
      'studentIds': studentIds,
      'userIds': userIds,
    });
    final d = res.data as Map<String, dynamic>;
    return NotifyResult((d['students'] as num?)?.toInt() ?? 0, (d['staff'] as num?)?.toInt() ?? 0, d['message']?.toString() ?? 'Sent.');
  }
}
