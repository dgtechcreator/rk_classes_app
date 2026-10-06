import 'package:intl/intl.dart';

int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? _asDoubleN(dynamic v) => v == null ? null : _asDouble(v);
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();

/// Mirrors SchoolMS.Domain.TeacherPayment — PaymentType is one of Hourly / Topic / Fixed.
class TeacherPayment {
  TeacherPayment({
    required this.teacherPaymentId,
    required this.facultyId,
    required this.facultyName,
    required this.paymentType,
    required this.rate,
    this.quantity,
    required this.totalAmount,
    required this.paymentMonth,
    required this.paymentYear,
    required this.isPaid,
    this.paymentDate,
    this.paymentMode,
    this.transactionRef,
    this.receiptNo,
    this.remarks,
  });

  final int teacherPaymentId;
  final int facultyId;
  final String facultyName;
  final String paymentType;
  final double rate;
  final double? quantity;
  final double totalAmount;
  final int paymentMonth;
  final int paymentYear;
  final bool isPaid;
  final DateTime? paymentDate;
  final String? paymentMode;
  final String? transactionRef;
  final String? receiptNo;
  final String? remarks;

  factory TeacherPayment.fromJson(Map<String, dynamic> j) => TeacherPayment(
        teacherPaymentId: _asInt(j['teacherPaymentId']),
        facultyId: _asInt(j['facultyId']),
        facultyName: _asString(j['facultyName']),
        paymentType: _asString(j['paymentType']),
        rate: _asDouble(j['rate']),
        quantity: _asDoubleN(j['quantity']),
        totalAmount: _asDouble(j['totalAmount']),
        paymentMonth: _asInt(j['paymentMonth']),
        paymentYear: _asInt(j['paymentYear']),
        isPaid: j['isPaid'] == true,
        paymentDate: j['paymentDate'] == null ? null : DateTime.tryParse(_asString(j['paymentDate'])),
        paymentMode: _asStringN(j['paymentMode']),
        transactionRef: _asStringN(j['transactionRef']),
        receiptNo: _asStringN(j['receiptNo']),
        remarks: _asStringN(j['remarks']),
      );

  String get statusLabel => isPaid ? 'Paid' : 'Pending';
  String get typeLabel => paymentType == 'Fixed' ? 'Fixed Salary' : paymentType;
  String get monthLabel => paymentMonth >= 1 && paymentMonth <= 12 ? DateFormat('MMMM').format(DateTime(2000, paymentMonth)) : '';
  String get monthYearLabel => '$monthLabel $paymentYear';
}

/// Per-teacher roll-up inside a payment summary.
class TeacherPaymentTeacherRow {
  TeacherPaymentTeacherRow({required this.facultyId, required this.facultyName, required this.count, required this.paidAmount, required this.pendingAmount, this.lastPaidOn});
  final int facultyId;
  final String facultyName;
  final int count;
  final double paidAmount;
  final double pendingAmount;
  final DateTime? lastPaidOn;

  factory TeacherPaymentTeacherRow.fromJson(Map<String, dynamic> j) => TeacherPaymentTeacherRow(
        facultyId: _asInt(j['facultyId']),
        facultyName: _asString(j['facultyName']),
        count: _asInt(j['count']),
        paidAmount: _asDouble(j['paidAmount']),
        pendingAmount: _asDouble(j['pendingAmount']),
        lastPaidOn: j['lastPaidOn'] == null ? null : DateTime.tryParse(_asString(j['lastPaidOn'])),
      );
}

class TeacherPaymentSummary {
  TeacherPaymentSummary({this.count = 0, this.paidCount = 0, this.pendingCount = 0, this.totalAmount = 0, this.paidAmount = 0, this.pendingAmount = 0, this.teachers = const []});
  final int count;
  final int paidCount;
  final int pendingCount;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final List<TeacherPaymentTeacherRow> teachers;

  factory TeacherPaymentSummary.fromJson(Map<String, dynamic> j) => TeacherPaymentSummary(
        count: _asInt(j['count']),
        paidCount: _asInt(j['paidCount']),
        pendingCount: _asInt(j['pendingCount']),
        totalAmount: _asDouble(j['totalAmount']),
        paidAmount: _asDouble(j['paidAmount']),
        pendingAmount: _asDouble(j['pendingAmount']),
        teachers: (j['teachers'] as List? ?? []).map((e) => TeacherPaymentTeacherRow.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Response of GET /api/teacher-payment/summary (admin) and /api/teacher-payment/mine (a teacher's own).
class TeacherPaymentReport {
  TeacherPaymentReport({
    required this.linked,
    this.message,
    this.facultyName,
    this.year = 0,
    this.years = const [],
    required this.summary,
    this.payments = const [],
    this.faculty = const [],
    this.hasPayments = true,
  });
  final bool linked;

  /// False when an older server answered without a `payments` list (it can't do filtered summaries).
  final bool hasPayments;
  final String? message;
  final String? facultyName;
  final int year;
  final List<int> years;
  final TeacherPaymentSummary summary;
  final List<TeacherPayment> payments;
  final List<({int id, String name})> faculty;

  factory TeacherPaymentReport.fromJson(Map<String, dynamic> j) => TeacherPaymentReport(
        linked: j['linked'] != false,
        hasPayments: j['linked'] == false || j.containsKey('payments'),
        message: _asStringN(j['message']),
        facultyName: _asStringN(j['facultyName']),
        year: _asInt(j['year']),
        years: (j['years'] as List? ?? []).map((e) => _asInt(e)).toList(),
        summary: j['summary'] == null ? TeacherPaymentSummary() : TeacherPaymentSummary.fromJson(j['summary'] as Map<String, dynamic>),
        payments: (j['payments'] as List? ?? []).map((e) => TeacherPayment.fromJson(e as Map<String, dynamic>)).toList(),
        faculty: (j['allFaculty'] as List? ?? []).map((e) {
          final m = e as Map<String, dynamic>;
          return (id: _asInt(m['facultyId']), name: _asString(m['fullName']).trim());
        }).toList(),
      );
}
