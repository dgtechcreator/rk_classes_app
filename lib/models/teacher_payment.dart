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
