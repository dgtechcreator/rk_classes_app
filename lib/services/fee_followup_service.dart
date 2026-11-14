import '../core/api_client.dart';

int _i(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? _dN(dynamic v) => v == null ? null : _d(v);
String? _s(dynamic v) {
  final t = v?.toString();
  return t == null || t.isEmpty ? null : t;
}

/// One follow-up: who spoke to whom, when, what was said, the reason, and the next date.
class FollowupEntry {
  FollowupEntry.fromJson(Map<String, dynamic> j)
      : id = _i(j['followupId']),
        studentId = _i(j['studentId']),
        at = DateTime.tryParse((j['at'] ?? '').toString()) ?? DateTime.now(),
        followedByName = (j['followedByName'] ?? '').toString(),
        followedBy = j['followedBy'] == null ? null : _i(j['followedBy']),
        mode = (j['mode'] ?? '').toString(),
        spokeTo = _s(j['spokeTo']),
        outcome = (j['outcome'] ?? '').toString(),
        reason = _s(j['reason']),
        notes = _s(j['notes']),
        promisedAmount = _dN(j['promisedAmount']),
        nextDate = DateTime.tryParse((j['nextDate'] ?? '').toString()),
        nextDateBy = _s(j['nextDateBy']),
        balanceAtTime = _dN(j['balanceAtTime']);
  final int id, studentId;
  final DateTime at;
  final String followedByName;
  final int? followedBy;
  final String mode, outcome;
  final String? spokeTo, reason, notes, nextDateBy;
  final double? promisedAmount, balanceAtTime;
  final DateTime? nextDate;
}

/// A student in the follow-up summary. [status]: Overdue | Today | Upcoming | NoNextDate | NotFollowed | PaidUp.
class FollowupRow {
  FollowupRow.fromJson(Map<String, dynamic> j)
      : studentId = _i(j['studentId']),
        name = (j['studentName'] ?? '').toString(),
        admissionNo = (j['admissionNo'] ?? '').toString(),
        className = (j['className'] ?? '').toString(),
        sectionName = (j['sectionName'] ?? '').toString(),
        batchName = (j['batchName'] ?? '').toString(),
        phone = (j['phone'] ?? '').toString(),
        balance = _d(j['balance']),
        count = _i(j['count']),
        status = (j['status'] ?? '').toString(),
        last = j['last'] == null ? null : FollowupEntry.fromJson(j['last'] as Map<String, dynamic>);
  final int studentId, count;
  final String name, admissionNo, className, sectionName, batchName, phone, status;
  final double balance;
  final FollowupEntry? last;
  String get group => [className, sectionName, batchName].where((e) => e.trim().isNotEmpty).join(' · ');
}

class FollowupSummary {
  FollowupSummary.fromJson(Map<String, dynamic> j)
      : overdue = _i(j['overdue']),
        today = _i(j['today']),
        upcoming = _i(j['upcoming']),
        noNextDate = _i(j['noNextDate']),
        notFollowed = _i(j['notFollowed']),
        totalBalance = _d(j['totalBalance']),
        rows = ((j['rows'] as List?) ?? const []).map((e) => FollowupRow.fromJson(e as Map<String, dynamic>)).toList();
  final int overdue, today, upcoming, noNextDate, notFollowed;
  final double totalBalance;
  final List<FollowupRow> rows;
}

class FollowupStudent {
  FollowupStudent.fromJson(Map<String, dynamic> j)
      : id = _i((j['student'] as Map)['studentId']),
        name = ((j['student'] as Map)['name'] ?? '').toString(),
        admissionNo = ((j['student'] as Map)['admissionNo'] ?? '').toString(),
        group = [(j['student'] as Map)['className'], (j['student'] as Map)['sectionName'], (j['student'] as Map)['batchName']]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join(' · '),
        phones = [
          ('Student', (j['student'] as Map)['phone']),
          ('Father', (j['student'] as Map)['fatherPhone']),
          ('Mother', (j['student'] as Map)['motherPhone']),
        ].where((p) => p.$2 != null && p.$2.toString().trim().isNotEmpty).map((p) => (p.$1, p.$2.toString())).toList(),
        balance = _d((j['student'] as Map)['balance']),
        totalFees = _d((j['student'] as Map)['totalFees']),
        collected = _d((j['student'] as Map)['collected']),
        history = ((j['followups'] as List?) ?? const [])
            .map((e) => (FollowupEntry.fromJson((e as Map)['entry'] as Map<String, dynamic>), e['canDelete'] == true))
            .toList();
  final int id;
  final String name, admissionNo, group;
  final List<(String, String)> phones;
  final double balance, totalFees, collected;
  final List<(FollowupEntry, bool)> history;
}

class FeeFollowupService {
  final _client = ApiClient.instance;
  static String _d2(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const modes = ['Call', 'WhatsApp', 'Visit', 'SMS', 'Other'];
  static const spokeTo = ['Father', 'Mother', 'Student', 'Other'];
  static const outcomes = [
    'Promised to pay',
    'Will pay part now',
    'Asked for more time',
    'Already paid',
    'No answer',
    'Phone switched off',
    'Wrong number',
    'Refused to pay',
    'Other',
  ];

  Map<String, dynamic> _q({String? q, String? status, String? outcome, DateTime? from, DateTime? to}) => {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (status != null) 'status': status,
        if (outcome != null) 'outcome': outcome,
        if (from != null) 'from': _d2(from),
        if (to != null) 'to': _d2(to),
      };

  Future<FollowupSummary> summary({String? q, String? status, String? outcome, DateTime? from, DateTime? to}) async {
    final res = await _client.get('/api/fee-followups/summary', query: _q(q: q, status: status, outcome: outcome, from: from, to: to));
    return FollowupSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<FollowupStudent> student(int id) async => FollowupStudent.fromJson((await _client.get('/api/fee-followups/student/$id')).data as Map<String, dynamic>);

  Future<void> add({
    required int studentId,
    required String mode,
    String? spokeTo,
    required String outcome,
    String? reason,
    String? notes,
    double? promisedAmount,
    DateTime? nextDate,
    String? nextDateBy,
  }) async {
    await _client.post('/api/fee-followups/add', data: {
      'studentId': studentId,
      'mode': mode,
      'spokeTo': spokeTo,
      'outcome': outcome,
      'reason': reason,
      'notes': notes,
      'promisedAmount': promisedAmount,
      'nextDate': nextDate == null ? null : _d2(nextDate),
      'nextDateBy': nextDateBy,
    });
  }

  Future<void> delete(int id) async => _client.post('/api/fee-followups/$id/delete');

  /// A link that downloads the Excel file (CSV). It opens outside the app, so the token travels in the link (same as the PDFs).
  String exportUrl({String? q, String? status, String? outcome, DateTime? from, DateTime? to}) {
    final p = _q(q: q, status: status, outcome: outcome, from: from, to: to).map((k, v) => MapEntry(k, v.toString()));
    p['token'] = _client.token ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/api/fee-followups/export').replace(queryParameters: p).toString();
  }
}
