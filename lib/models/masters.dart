int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
bool _asBool(dynamic v) => v == true || v?.toString().toLowerCase() == 'true';
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();

class AcademicYear {
  AcademicYear({
    required this.yearId,
    required this.yearName,
    this.isCurrent = false,
    this.isActive = true,
    this.studentCount = 0,
  });

  final int yearId;
  final String yearName;
  final bool isCurrent;
  final bool isActive;
  final int studentCount;

  factory AcademicYear.fromJson(Map<String, dynamic> j) => AcademicYear(
        yearId: _asInt(j['yearId']),
        yearName: _asString(j['yearName']),
        isCurrent: _asBool(j['isCurrent']),
        isActive: j['isActive'] == null ? true : _asBool(j['isActive']),
        studentCount: _asInt(j['studentCount']),
      );
}

class SchoolClass {
  SchoolClass({
    required this.classId,
    required this.className,
    this.orderNo = 0,
    this.isActive = true,
    this.studentCount = 0,
  });

  final int classId;
  final String className;
  final int orderNo;
  final bool isActive;
  final int studentCount;

  factory SchoolClass.fromJson(Map<String, dynamic> j) => SchoolClass(
        classId: _asInt(j['classId']),
        className: _asString(j['className']),
        orderNo: _asInt(j['orderNo']),
        isActive: j['isActive'] == null ? true : _asBool(j['isActive']),
        studentCount: _asInt(j['studentCount']),
      );
}

class SchoolSection {
  SchoolSection({
    required this.sectionId,
    required this.sectionName,
    this.isActive = true,
    this.studentCount = 0,
  });

  final int sectionId;
  final String sectionName;
  final bool isActive;
  final int studentCount;

  factory SchoolSection.fromJson(Map<String, dynamic> j) => SchoolSection(
        sectionId: _asInt(j['sectionId']),
        sectionName: _asString(j['sectionName']),
        isActive: j['isActive'] == null ? true : _asBool(j['isActive']),
        studentCount: _asInt(j['studentCount']),
      );
}

class SchoolBatch {
  SchoolBatch({
    required this.batchId,
    required this.batchName,
    this.isActive = true,
    this.studentCount = 0,
  });

  final int batchId;
  final String batchName;
  final bool isActive;
  final int studentCount;

  factory SchoolBatch.fromJson(Map<String, dynamic> j) => SchoolBatch(
        batchId: _asInt(j['batchId']),
        batchName: _asString(j['batchName']),
        isActive: j['isActive'] == null ? true : _asBool(j['isActive']),
        studentCount: _asInt(j['studentCount']),
      );
}

class ExpenseCategory {
  ExpenseCategory({
    required this.categoryId,
    required this.categoryName,
    this.isActive = true,
    this.usageCount = 0,
  });

  final int categoryId;
  final String categoryName;
  final bool isActive;
  final int usageCount;

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) => ExpenseCategory(
        categoryId: _asInt(j['categoryId']),
        categoryName: _asString(j['categoryName']),
        isActive: j['isActive'] == null ? true : _asBool(j['isActive']),
        usageCount: _asInt(j['usageCount']),
      );
}

class MasterSubject {
  MasterSubject({
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    this.classId,
    this.className,
    this.maxMarks = 100,
    this.passMarks = 35,
    this.isActive = true,
  });

  final int subjectId;
  final String subjectName;
  final String? subjectCode;
  final int? classId;
  final String? className;
  final int maxMarks;
  final int passMarks;
  final bool isActive;

  factory MasterSubject.fromJson(Map<String, dynamic> j) => MasterSubject(
        subjectId: _asInt(j['subjectId']),
        subjectName: _asString(j['subjectName']),
        subjectCode: _asStringN(j['subjectCode']),
        classId: j['classId'] == null ? null : _asInt(j['classId']),
        className: _asStringN(j['className']),
        maxMarks: j['maxMarks'] == null ? 100 : _asInt(j['maxMarks']),
        passMarks: j['passMarks'] == null ? 35 : _asInt(j['passMarks']),
        isActive: j['isActive'] == null ? true : _asBool(j['isActive']),
      );
}
