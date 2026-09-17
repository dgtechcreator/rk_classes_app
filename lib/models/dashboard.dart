double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';

class ClassStrength {
  ClassStrength({required this.className, required this.studentCount, required this.color});
  final String className;
  final int studentCount;
  final String color;

  factory ClassStrength.fromJson(Map<String, dynamic> j) => ClassStrength(
        className: _asString(j['className']),
        studentCount: _asInt(j['studentCount']),
        color: _asString(j['color']).isEmpty ? '#6d28d9' : _asString(j['color']),
      );
}

class DashboardStats {
  DashboardStats({
    required this.totalStudents,
    required this.presentToday,
    required this.absentToday,
    required this.feesThisMonth,
    required this.expensesThisMonth,
    required this.totalStaff,
    required this.totalFeesOverall,
    required this.totalCollectedOverall,
    required this.totalDiscountOverall,
    required this.balanceOverall,
    required this.classStrengths,
  });

  final int totalStudents;
  final int presentToday;
  final int absentToday;
  final double feesThisMonth;
  final double expensesThisMonth;
  final int totalStaff;
  final double totalFeesOverall;
  final double totalCollectedOverall;
  final double totalDiscountOverall;
  final double balanceOverall;
  final List<ClassStrength> classStrengths;

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalStudents: _asInt(j['totalStudents']),
        presentToday: _asInt(j['presentToday']),
        absentToday: _asInt(j['absentToday']),
        feesThisMonth: _asDouble(j['feesThisMonth']),
        expensesThisMonth: _asDouble(j['expensesThisMonth']),
        totalStaff: _asInt(j['totalStaff']),
        totalFeesOverall: _asDouble(j['totalFeesOverall']),
        totalCollectedOverall: _asDouble(j['totalCollectedOverall']),
        totalDiscountOverall: _asDouble(j['totalDiscountOverall']),
        balanceOverall: _asDouble(j['balanceOverall']),
        classStrengths: (j['classStrengths'] as List? ?? []).map((e) => ClassStrength.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class AbsentStudent {
  AbsentStudent({required this.studentId, required this.fullName, required this.admissionNo, required this.className, required this.sectionName});
  final int studentId;
  final String fullName;
  final String admissionNo;
  final String className;
  final String sectionName;

  factory AbsentStudent.fromJson(Map<String, dynamic> j) => AbsentStudent(
        studentId: _asInt(j['studentId']),
        fullName: _asString(j['fullName']),
        admissionNo: _asString(j['admissionNo']),
        className: _asString(j['className']),
        sectionName: _asString(j['sectionName']),
      );
}

class StaffDashboardData {
  StaffDashboardData({required this.stats, required this.currentYearName});
  final DashboardStats stats;
  final String currentYearName;

  factory StaffDashboardData.fromJson(Map<String, dynamic> j) => StaffDashboardData(
        stats: DashboardStats.fromJson(j['stats'] as Map<String, dynamic>),
        currentYearName: _asString(j['currentYearName']),
      );
}
