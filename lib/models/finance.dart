int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';

class FinanceAcademicRow {
  FinanceAcademicRow({
    required this.className,
    required this.batchName,
    required this.studentCount,
    required this.totalFees,
    required this.estimatedCollected,
    required this.estimatedDiscount,
  });

  final String className;
  final String batchName;
  final int studentCount;
  final double totalFees;
  final double estimatedCollected;
  final double estimatedDiscount;

  double get balance => totalFees - estimatedCollected - estimatedDiscount;

  factory FinanceAcademicRow.fromJson(Map<String, dynamic> j) => FinanceAcademicRow(
        className: _asString(j['className']),
        batchName: _asString(j['batchName']),
        studentCount: _asInt(j['studentCount']),
        totalFees: _asDouble(j['totalFees']),
        estimatedCollected: _asDouble(j['estimatedCollected']),
        estimatedDiscount: _asDouble(j['estimatedDiscount']),
      );
}

class FinanceDashboardData {
  FinanceDashboardData({
    required this.totalStudents,
    required this.totalFees,
    required this.totalCollected,
    required this.totalDiscount,
    required this.totalBalance,
    required this.collectionPercentage,
    required this.academicData,
  });

  final int totalStudents;
  final double totalFees;
  final double totalCollected;
  final double totalDiscount;
  final double totalBalance;
  final double collectionPercentage;
  final List<FinanceAcademicRow> academicData;

  factory FinanceDashboardData.fromJson(Map<String, dynamic> j) => FinanceDashboardData(
        totalStudents: _asInt(j['totalStudents']),
        totalFees: _asDouble(j['totalFees']),
        totalCollected: _asDouble(j['totalCollected']),
        totalDiscount: _asDouble(j['totalDiscount']),
        totalBalance: _asDouble(j['totalBalance']),
        collectionPercentage: _asDouble(j['collectionPercentage']),
        academicData: (j['academicData'] as List? ?? []).map((e) => FinanceAcademicRow.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class FinanceClassDetail {
  FinanceClassDetail({
    required this.className,
    required this.batchName,
    required this.totalStudents,
    required this.totalFees,
    required this.totalCollected,
    required this.totalDiscount,
    required this.totalBalance,
    required this.studentDetails,
  });

  final String className;
  final String batchName;
  final int totalStudents;
  final double totalFees;
  final double totalCollected;
  final double totalDiscount;
  final double totalBalance;
  final List<FinanceStudentDetail> studentDetails;

  factory FinanceClassDetail.fromJson(Map<String, dynamic> j) => FinanceClassDetail(
        className: _asString(j['className']),
        batchName: _asString(j['batchName']),
        totalStudents: _asInt(j['totalStudents']),
        totalFees: _asDouble(j['totalFees']),
        totalCollected: _asDouble(j['totalCollected']),
        totalDiscount: _asDouble(j['totalDiscount']),
        totalBalance: _asDouble(j['totalBalance']),
        studentDetails: (j['studentDetails'] as List? ?? []).map((e) => FinanceStudentDetail.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class FinanceStudentDetail {
  FinanceStudentDetail({required this.studentName, required this.totalFees, required this.collected, required this.discount, required this.balance});
  final String studentName;
  final double totalFees;
  final double collected;
  final double discount;
  final double balance;

  factory FinanceStudentDetail.fromJson(Map<String, dynamic> j) => FinanceStudentDetail(
        studentName: _asString(j['studentName']),
        totalFees: _asDouble(j['totalFees']),
        collected: _asDouble(j['collected']),
        discount: _asDouble(j['discount']),
        balance: _asDouble(j['balance']),
      );
}

/// One active student's fee position (GET /api/finance/students) — fees - collected - discount = balance,
/// the same rule the dashboard totals use, so any list of these adds up to the tile it came from.
class FinanceStudent {
  FinanceStudent({
    required this.studentId,
    required this.fullName,
    required this.admissionNo,
    required this.className,
    required this.sectionName,
    required this.batchName,
    required this.phone,
    required this.fatherPhone,
    required this.motherPhone,
    required this.totalFees,
    required this.collected,
    required this.discount,
    required this.balance,
  });

  final int studentId;
  final String fullName;
  final String admissionNo;
  final String className;
  final String sectionName;
  final String batchName;
  final String phone;
  final String fatherPhone;
  final String motherPhone;
  final double totalFees;
  final double collected;
  final double discount;
  final double balance;

  bool get hasDue => balance > 0.5;

  /// "10th · English · Morning" style label, skipping blanks.
  String get classLabel => [className, sectionName, batchName].where((e) => e.trim().isNotEmpty).join(' · ');

  factory FinanceStudent.fromJson(Map<String, dynamic> j) => FinanceStudent(
        studentId: _asInt(j['studentId']),
        fullName: _asString(j['fullName']),
        admissionNo: _asString(j['admissionNo']),
        className: _asString(j['className']),
        sectionName: _asString(j['sectionName']),
        batchName: _asString(j['batchName']),
        phone: _asString(j['phone']),
        fatherPhone: _asString(j['fatherPhone']),
        motherPhone: _asString(j['motherPhone']),
        totalFees: _asDouble(j['totalFees']),
        collected: _asDouble(j['collected']),
        discount: _asDouble(j['discount']),
        balance: _asDouble(j['balance']),
      );
}

class FinanceStudentsResult {
  FinanceStudentsResult({required this.students, required this.totalFees, required this.totalCollected, required this.totalDiscount, required this.totalBalance});
  final List<FinanceStudent> students;
  final double totalFees;
  final double totalCollected;
  final double totalDiscount;
  final double totalBalance;

  factory FinanceStudentsResult.fromJson(Map<String, dynamic> j) => FinanceStudentsResult(
        students: (j['students'] as List? ?? []).map((e) => FinanceStudent.fromJson(e as Map<String, dynamic>)).toList(),
        totalFees: _asDouble(j['totalFees']),
        totalCollected: _asDouble(j['totalCollected']),
        totalDiscount: _asDouble(j['totalDiscount']),
        totalBalance: _asDouble(j['totalBalance']),
      );
}
