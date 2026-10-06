import 'contact_number.dart';

double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';

class ClassSectionStrength {
  ClassSectionStrength({required this.sectionName, required this.studentCount});
  final String sectionName; // Medium, e.g. "English Medium"
  final int studentCount;

  factory ClassSectionStrength.fromJson(Map<String, dynamic> j) => ClassSectionStrength(
        sectionName: _asString(j['sectionName']).trim(),
        studentCount: _asInt(j['studentCount']),
      );
}

class ClassStrength {
  ClassStrength({required this.className, required this.studentCount, required this.color, this.sections = const []});
  final String className;
  final int studentCount;
  final String color;
  final List<ClassSectionStrength> sections;

  factory ClassStrength.fromJson(Map<String, dynamic> j) => ClassStrength(
        className: _asString(j['className']),
        studentCount: _asInt(j['studentCount']),
        color: _asString(j['color']).isEmpty ? '#6d28d9' : _asString(j['color']),
        sections: (j['sections'] as List? ?? []).map((e) => ClassSectionStrength.fromJson(e as Map<String, dynamic>)).toList(),
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
  AbsentStudent({
    required this.studentId,
    required this.fullName,
    required this.admissionNo,
    required this.className,
    required this.sectionName,
    this.phone = '',
    this.fatherPhone = '',
    this.motherPhone = '',
  });
  final int studentId;
  final String fullName;
  final String admissionNo;
  final String className;
  final String sectionName;
  final String phone;
  final String fatherPhone;
  final String motherPhone;

  List<ContactNumber> get contacts => buildContacts(father: fatherPhone, mother: motherPhone, student: phone);

  factory AbsentStudent.fromJson(Map<String, dynamic> j) => AbsentStudent(
        studentId: _asInt(j['studentId']),
        fullName: _asString(j['fullName']),
        admissionNo: _asString(j['admissionNo']),
        className: _asString(j['className']),
        sectionName: _asString(j['sectionName']),
        phone: _asString(j['phone']),
        fatherPhone: _asString(j['fatherPhone']),
        motherPhone: _asString(j['motherPhone']),
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
