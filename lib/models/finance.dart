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
    this.sectionName = '',
  });

  final String className;
  final String batchName;
  /// Medium (Hindi / English ...). Blank when the row is a plain class + batch total.
  final String sectionName;
  final int studentCount;
  final double totalFees;
  final double estimatedCollected;
  final double estimatedDiscount;

  double get balance => totalFees - estimatedCollected - estimatedDiscount;

  /// What the institute will actually receive: fee after discount. The discount is only information.
  double get netFees => totalFees - estimatedDiscount;

  /// Splits the student-wise fee list into one row per class + batch + medium (same figures as the student list,
  /// so a row always equals what opens when it is tapped). Ordered 5th..12th, Morning before Evening, then medium.
  static List<FinanceAcademicRow> groupStudents(List<FinanceStudent> students) {
    final map = <String, List<FinanceStudent>>{};
    for (final s in students) {
      map.putIfAbsent('${s.className.trim()}|${s.batchName.trim()}|${s.sectionName.trim()}', () => []).add(s);
    }
    int classNo(String c) => int.tryParse(RegExp(r'\d+').firstMatch(c)?.group(0) ?? '') ?? 99;
    int batchNo(String b) {
      final l = b.toLowerCase();
      return l.contains('morning') ? 0 : l.contains('evening') ? 1 : 2;
    }
    final rows = map.entries.map((e) {
      final p = e.key.split('|');
      final l = e.value;
      return FinanceAcademicRow(
        className: p[0],
        batchName: p[1],
        sectionName: p[2],
        studentCount: l.length,
        totalFees: l.fold(0.0, (a, s) => a + s.totalFees),
        estimatedCollected: l.fold(0.0, (a, s) => a + s.collected),
        estimatedDiscount: l.fold(0.0, (a, s) => a + s.discount),
      );
    }).toList()
      ..sort((a, b) {
        final c = classNo(a.className).compareTo(classNo(b.className));
        if (c != 0) return c;
        final n = a.className.compareTo(b.className);
        if (n != 0) return n;
        final bt = batchNo(a.batchName).compareTo(batchNo(b.batchName));
        if (bt != 0) return bt;
        final bn = a.batchName.compareTo(b.batchName);
        return bn != 0 ? bn : a.sectionName.compareTo(b.sectionName);
      });
    return rows;
  }

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

  /// Fee after discount = what will really come in. Collected / this = the true collection %.
  double get netFees => totalFees - totalDiscount;
  double get netPercentage => netFees <= 0 ? 0 : (totalCollected / netFees * 100).clamp(0, 100).toDouble();

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
    this.previousDue = 0,
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
  /// Part of the balance owed from earlier academic years.
  final double previousDue;

  bool get hasDue => balance > 0.5;
  /// No fee row exists for this student (fee head missing) - shown as "Fee not set", never as an amount.
  bool get feeNotSet => totalFees == 0;

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
        previousDue: _asDouble(j['previousDue']),
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
