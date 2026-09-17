import '../core/api_client.dart';
import '../models/fee_structure.dart';
import '../models/student.dart';

/// Lightweight row from GET /api/students/quick-search — used to search/pick a student before
/// collecting a fee payment, distinct from the full [Student] model returned by the Students module.
class StudentQuickResult {
  StudentQuickResult({
    required this.studentId,
    required this.fullName,
    required this.admissionNo,
    this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
  });

  final int studentId;
  final String fullName;
  final String admissionNo;
  final int? classId;
  final String? className;
  final int? sectionId;
  final String? sectionName;

  factory StudentQuickResult.fromJson(Map<String, dynamic> j) => StudentQuickResult(
        studentId: j['studentId'] is int ? j['studentId'] as int : int.tryParse(j['studentId'].toString()) ?? 0,
        fullName: j['fullName']?.toString() ?? '',
        admissionNo: j['admissionNo']?.toString() ?? '',
        classId: j['classId'] == null ? null : (j['classId'] is int ? j['classId'] as int : int.tryParse(j['classId'].toString())),
        className: j['className']?.toString(),
        sectionId: j['sectionId'] == null ? null : (j['sectionId'] is int ? j['sectionId'] as int : int.tryParse(j['sectionId'].toString())),
        sectionName: j['sectionName']?.toString(),
      );

  String get classLabel => [className, sectionName].where((e) => e != null && e.isNotEmpty).join(' / ');
}

/// Response of GET /api/fees/pay/{id} — a student's current fee status: what they owe, what's been
/// paid, their fee structure breakdown and payment history so far.
class FeePayInfo {
  FeePayInfo({
    required this.student,
    required this.actualFee,
    required this.totalPaid,
    required this.balance,
    this.dueDate,
    required this.feeStructures,
    required this.paymentHistory,
    required this.existingDiscount,
  });

  final Student student;
  final double actualFee;
  final double totalPaid;
  final double balance;
  final DateTime? dueDate;
  final List<FeeStructure> feeStructures;
  final List<FeePayment> paymentHistory;
  final double existingDiscount;
}

double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class FeeSummaryResult {
  FeeSummaryResult({required this.payments, required this.total, required this.grandTotalAmount});
  final List<FeePayment> payments;
  final int total;
  final double grandTotalAmount;
}

class FeesService {
  final _client = ApiClient.instance;

  Future<List<StudentQuickResult>> quickSearchStudents(String q) async {
    if (q.trim().length < 2) return [];
    final res = await _client.get('/api/students/quick-search', query: {'q': q.trim()});
    return (res.data as List).map((e) => StudentQuickResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FeePayInfo> getPayInfo(int studentId) async {
    final res = await _client.get('/api/fees/pay/$studentId');
    final data = res.data as Map<String, dynamic>;
    return FeePayInfo(
      student: Student.fromJson(data['student'] as Map<String, dynamic>),
      actualFee: _asDouble(data['actualFee']),
      totalPaid: _asDouble(data['totalPaid']),
      balance: _asDouble(data['balance']),
      dueDate: data['dueDate'] == null ? null : DateTime.tryParse(data['dueDate'].toString()),
      feeStructures: (data['feeStructures'] as List? ?? []).map((e) => FeeStructure.fromJson(e as Map<String, dynamic>)).toList(),
      paymentHistory: (data['paymentHistory'] as List? ?? []).map((e) => FeePayment.fromJson(e as Map<String, dynamic>)).toList(),
      existingDiscount: _asDouble(data['existingDiscount']),
    );
  }

  Future<int> savePay({
    required int studentId,
    required double payingNow,
    required double additionalDiscount,
    required double additionalCharges,
    DateTime? paymentDate,
    DateTime? dueDate,
    required String paymentMode,
    String? transactionRef,
    String? remarks,
  }) async {
    final res = await _client.post('/api/fees/save-pay', data: {
      'studentId': studentId,
      'payingNow': payingNow,
      'additionalDiscount': additionalDiscount,
      'additionalCharges': additionalCharges,
      'paymentDate': (paymentDate ?? DateTime.now()).toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'paymentMode': paymentMode,
      'transactionRef': transactionRef,
      'remarks': remarks,
    });
    final data = res.data as Map<String, dynamic>;
    return data['paymentId'] as int? ?? 0;
  }

  Future<FeeSummaryResult> getSummary({int page = 1, String? search, String? month, int? feeType}) async {
    final res = await _client.get('/api/fees/summary', query: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      if (month != null && month.isNotEmpty) 'month': month,
      if (feeType != null) 'feeType': feeType,
    });
    final data = res.data as Map<String, dynamic>;
    return FeeSummaryResult(
      payments: (data['payments'] as List? ?? []).map((e) => FeePayment.fromJson(e as Map<String, dynamic>)).toList(),
      total: data['total'] as int? ?? 0,
      grandTotalAmount: _asDouble(data['grandTotalAmount']),
    );
  }

  Future<void> deletePayment(int id) async => _client.post('/api/fees/$id/delete');
}
