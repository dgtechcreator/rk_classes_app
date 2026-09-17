int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();
bool _asBool(dynamic v, {bool fallback = true}) => v is bool ? v : fallback;

/// Mirrors SchoolMS.Domain.FeeStructure — a fee head configured for a Year/Class/Section (e.g.
/// "Tuition Fee, Std 10, Marathi Medium, ₹2000/month, due on the 10th").
class FeeStructure {
  FeeStructure({
    required this.structureId,
    required this.academicYearId,
    this.yearName,
    required this.classId,
    this.className,
    required this.sectionId,
    this.sectionName,
    required this.feeTypeId,
    this.feeTypeName,
    required this.amount,
    this.dueDay = 10,
    this.isMonthly = true,
    this.remarks,
    this.isActive = true,
    this.createdByName,
    this.createdAt,
  });

  final int structureId;
  final int academicYearId;
  final String? yearName;
  final int classId;
  final String? className;
  final int sectionId;
  final String? sectionName;
  final int feeTypeId;
  final String? feeTypeName;
  final double amount;
  final int dueDay;
  final bool isMonthly;
  final String? remarks;
  final bool isActive;
  final String? createdByName;
  final DateTime? createdAt;

  factory FeeStructure.fromJson(Map<String, dynamic> j) => FeeStructure(
        structureId: _asInt(j['structureId']),
        academicYearId: _asInt(j['academicYearId']),
        yearName: _asStringN(j['yearName']),
        classId: _asInt(j['classId']),
        className: _asStringN(j['className']),
        sectionId: _asInt(j['sectionId']),
        sectionName: _asStringN(j['sectionName']),
        feeTypeId: _asInt(j['feeTypeId']),
        feeTypeName: _asStringN(j['feeTypeName']),
        amount: _asDouble(j['amount']),
        dueDay: j['dueDay'] == null ? 10 : _asInt(j['dueDay']),
        isMonthly: _asBool(j['isMonthly']),
        remarks: _asStringN(j['remarks']),
        isActive: _asBool(j['isActive']),
        createdByName: _asStringN(j['createdByName']),
        createdAt: j['createdAt'] == null ? null : DateTime.tryParse(j['createdAt'].toString()),
      );

  Map<String, dynamic> toSaveJson() => {
        'structureId': structureId,
        'academicYearId': academicYearId,
        'classId': classId,
        'sectionId': sectionId,
        'feeTypeId': feeTypeId,
        'amount': amount,
        'dueDay': dueDay,
        'isMonthly': isMonthly,
        'remarks': remarks,
      };

  String get classLabel => [className, sectionName].where((e) => e != null && e.isNotEmpty).join(' / ');
}

/// Mirrors SchoolMS.Domain.FeeStructureSummary — per class/section rollup shown above the structure list.
class FeeStructureSummary {
  FeeStructureSummary({
    this.className,
    this.sectionName,
    this.yearName,
    required this.studentCount,
    required this.totalMonthlyFee,
    required this.feeHeads,
    required this.collectedAmt,
    required this.pendingAmt,
  });

  final String? className;
  final String? sectionName;
  final String? yearName;
  final int studentCount;
  final double totalMonthlyFee;
  final int feeHeads;
  final double collectedAmt;
  final double pendingAmt;

  factory FeeStructureSummary.fromJson(Map<String, dynamic> j) => FeeStructureSummary(
        className: _asStringN(j['className']),
        sectionName: _asStringN(j['sectionName']),
        yearName: _asStringN(j['yearName']),
        studentCount: _asInt(j['studentCount']),
        totalMonthlyFee: _asDouble(j['totalMonthlyFee']),
        feeHeads: _asInt(j['feeHeads']),
        collectedAmt: _asDouble(j['collectedAmt']),
        pendingAmt: _asDouble(j['pendingAmt']),
      );
}

/// Mirrors SchoolMS.Domain.StudentFee — one student's billed fee line for a month/head, as returned
/// by the Fees Due ledger (GET /api/fee-structure/fees-due).
class StudentFee {
  StudentFee({
    required this.studentFeeId,
    required this.studentId,
    this.studentName,
    this.admissionNo,
    this.rollNo,
    this.className,
    this.sectionName,
    required this.structureId,
    required this.academicYearId,
    this.yearName,
    required this.feeTypeId,
    this.feeTypeName,
    this.month,
    this.dueDate,
    required this.amount,
    required this.paidAmount,
    required this.discount,
    required this.lateFine,
    required this.balanceAmount,
    this.status = 'Pending',
    this.createdAt,
  });

  final int studentFeeId;
  final int studentId;
  final String? studentName;
  final String? admissionNo;
  final String? rollNo;
  final String? className;
  final String? sectionName;
  final int structureId;
  final int academicYearId;
  final String? yearName;
  final int feeTypeId;
  final String? feeTypeName;
  final String? month;
  final DateTime? dueDate;
  final double amount;
  final double paidAmount;
  final double discount;
  final double lateFine;
  final double balanceAmount;
  final String status;
  final DateTime? createdAt;

  bool get isOverdue => status != 'Paid' && dueDate != null && dueDate!.isBefore(DateTime.now());

  factory StudentFee.fromJson(Map<String, dynamic> j) => StudentFee(
        studentFeeId: _asInt(j['studentFeeId']),
        studentId: _asInt(j['studentId']),
        studentName: _asStringN(j['studentName']),
        admissionNo: _asStringN(j['admissionNo']),
        rollNo: _asStringN(j['rollNo']),
        className: _asStringN(j['className']),
        sectionName: _asStringN(j['sectionName']),
        structureId: _asInt(j['structureId']),
        academicYearId: _asInt(j['academicYearId']),
        yearName: _asStringN(j['yearName']),
        feeTypeId: _asInt(j['feeTypeId']),
        feeTypeName: _asStringN(j['feeTypeName']),
        month: _asStringN(j['month']),
        dueDate: j['dueDate'] == null ? null : DateTime.tryParse(j['dueDate'].toString()),
        amount: _asDouble(j['amount']),
        paidAmount: _asDouble(j['paidAmount']),
        discount: _asDouble(j['discount']),
        lateFine: _asDouble(j['lateFine']),
        balanceAmount: _asDouble(j['balanceAmount']),
        status: j['status'] == null ? 'Pending' : _asString(j['status']),
        createdAt: j['createdAt'] == null ? null : DateTime.tryParse(j['createdAt'].toString()),
      );
}
