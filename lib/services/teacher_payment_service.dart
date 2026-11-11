import '../core/api_client.dart';
import '../models/lookup.dart';
import '../models/teacher_payment.dart';

int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';

LookupItem _facultyLookup(Map<String, dynamic> j) => LookupItem(id: _asInt(j['facultyId']), name: _asString(j['fullName']));

class TeacherPaymentIndexData {
  TeacherPaymentIndexData({
    required this.unpaidPayments,
    required this.monthlyPayments,
    required this.currentMonth,
    required this.currentYear,
    required this.allFaculty,
    this.facultyPay = const {},
  });
  final List<TeacherPayment> unpaidPayments;
  final List<TeacherPayment> monthlyPayments;
  final int currentMonth;
  final int currentYear;
  final List<LookupItem> allFaculty;
  /// facultyId -> (salary type, rate) set on the Faculty form; the payment entry starts from it.
  final Map<int, ({String type, double? rate})> facultyPay;
}

/// Wraps GET/POST api/teacher-payment/* (TeacherPaymentApiController). Note: the API has no endpoint
/// for an arbitrary past month/year — Index only returns all-time unpaid dues plus the CURRENT month's
/// payments (paid or not). Screens filtering by an older month can only work off that same combined set.
/// Save/mark-paid/delete return 200 OK with `{success:false, message}` on business-rule failure, so this
/// service checks `success` itself and raises [ApiException].
class TeacherPaymentService {
  final _client = ApiClient.instance;

  Future<TeacherPaymentIndexData> getIndex() async {
    final res = await _client.get('/api/teacher-payment');
    final data = res.data as Map<String, dynamic>;
    return TeacherPaymentIndexData(
      unpaidPayments: (data['unpaidPayments'] as List? ?? []).map((e) => TeacherPayment.fromJson(e as Map<String, dynamic>)).toList(),
      monthlyPayments: (data['monthlyPayments'] as List? ?? []).map((e) => TeacherPayment.fromJson(e as Map<String, dynamic>)).toList(),
      currentMonth: _asInt(data['currentMonth']),
      currentYear: _asInt(data['currentYear']),
      allFaculty: (data['allFaculty'] as List? ?? []).map((e) => _facultyLookup(e as Map<String, dynamic>)).toList(),
      facultyPay: {
        for (final e in (data['allFaculty'] as List? ?? []))
          _asInt((e as Map<String, dynamic>)['facultyId']): (
            type: (e['salaryType'] == 'Hourly' || e['salaryType'] == 'Topic') ? e['salaryType'].toString() : 'Fixed',
            rate: e['salary'] is num ? (e['salary'] as num).toDouble() : null,
          ),
      },
    );
  }

  /// Admin summary with filters. [month] 0 = whole year; [status] all | paid | pending.
  Future<TeacherPaymentReport> getSummary({int? year, int month = 0, int? facultyId, String status = 'all'}) async {
    final res = await _client.get('/api/teacher-payment/summary', query: {
      if (year != null) 'year': year,
      if (month > 0) 'month': month,
      if (facultyId != null) 'facultyId': facultyId,
      if (status != 'all') 'status': status,
    });
    return TeacherPaymentReport.fromJson(res.data as Map<String, dynamic>);
  }

  /// A teacher's own payments (when each one was paid). `linked == false` when the login has no faculty profile.
  Future<TeacherPaymentReport> getMine({int? year}) async {
    final res = await _client.get('/api/teacher-payment/mine', query: {if (year != null && year > 0) 'year': year});
    return TeacherPaymentReport.fromJson(res.data as Map<String, dynamic>);
  }

  Future<int> save({
    required int facultyId,
    required String paymentType,
    required double rate,
    double? quantity,
    required int paymentMonth,
    required int paymentYear,
    String? remarks,
  }) async {
    final res = await _client.post('/api/teacher-payment/save', data: {
      'facultyId': facultyId,
      'paymentType': paymentType,
      'rate': rate,
      'quantity': quantity,
      'paymentMonth': paymentMonth,
      'paymentYear': paymentYear,
      'remarks': remarks,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) throw ApiException(_asString(data['message']).isEmpty ? 'Failed to save payment.' : _asString(data['message']));
    return _asInt(data['paymentId']);
  }

  Future<TeacherPayment> getOne(int paymentId) async {
    final res = await _client.get('/api/teacher-payment/$paymentId');
    return TeacherPayment.fromJson(res.data as Map<String, dynamic>);
  }

  /// Edits an entry (pending or paid); the total is recalculated on the server. For a paid entry the mode / reference / paid date can be corrected too.
  Future<void> update({
    required int paymentId,
    required String paymentType,
    required double rate,
    double? quantity,
    required int paymentMonth,
    required int paymentYear,
    String? remarks,
    String? paymentMode,
    String? transactionRef,
    DateTime? paymentDate,
  }) async {
    final res = await _client.post('/api/teacher-payment/update', data: {
      'paymentId': paymentId,
      'paymentType': paymentType,
      'rate': rate,
      'quantity': quantity,
      'paymentMonth': paymentMonth,
      'paymentYear': paymentYear,
      'remarks': remarks,
      'paymentMode': paymentMode,
      'transactionRef': transactionRef,
      'paymentDate': paymentDate == null ? null : '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}',
    });
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) throw ApiException(_asString(data['message']).isEmpty ? 'Failed to update payment.' : _asString(data['message']));
  }

  Future<void> markAsPaid({required int paymentId, String? paymentMode, String? transactionRef}) async {
    final res = await _client.post('/api/teacher-payment/mark-paid', data: {
      'paymentId': paymentId,
      'paymentMode': paymentMode,
      'transactionRef': transactionRef,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) throw ApiException(_asString(data['message']).isEmpty ? 'Failed to mark as paid.' : _asString(data['message']));
  }

  Future<void> delete(int paymentId) async {
    final res = await _client.post('/api/teacher-payment/$paymentId/delete');
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) throw ApiException(_asString(data['message']).isEmpty ? 'Failed to delete payment.' : _asString(data['message']));
  }
}
