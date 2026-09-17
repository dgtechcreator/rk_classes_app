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
