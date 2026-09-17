int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _asIntN(dynamic v) => v == null ? null : _asInt(v);
double? _asDoubleN(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();
bool _asBool(dynamic v, {bool fallback = true}) => v is bool ? v : fallback;

/// Mirrors SchoolMS.Domain.Designation.
class Designation {
  Designation({required this.designationId, required this.designationName, this.isActive = true});

  final int designationId;
  final String designationName;
  final bool isActive;

  factory Designation.fromJson(Map<String, dynamic> j) => Designation(
        designationId: _asInt(j['designationId']),
        designationName: _asString(j['designationName']),
        isActive: _asBool(j['isActive']),
      );
}

/// Mirrors SchoolMS.Domain.FacultySubject — a class/subject (optionally section) assigned to a faculty.
class FacultySubject {
  FacultySubject({
    required this.facultySubjectId,
    required this.facultyId,
    this.classId,
    this.className,
    this.subjectId,
    this.subjectName,
    this.sectionId,
    this.sectionName,
  });

  final int facultySubjectId;
  final int facultyId;
  final int? classId;
  final String? className;
  final int? subjectId;
  final String? subjectName;
  final int? sectionId;
  final String? sectionName;

  factory FacultySubject.fromJson(Map<String, dynamic> j) => FacultySubject(
        facultySubjectId: _asInt(j['facultySubjectId']),
        facultyId: _asInt(j['facultyId']),
        classId: _asIntN(j['classId']),
        className: _asStringN(j['className']),
        subjectId: _asIntN(j['subjectId']),
        subjectName: _asStringN(j['subjectName']),
        sectionId: _asIntN(j['sectionId']),
        sectionName: _asStringN(j['sectionName']),
      );
}

/// Mirrors SchoolMS.Domain.Faculty. Note: profile picture upload is deferred server-side (Save is
/// JSON-only, no IFormFile) — there's deliberately no field here for picking/uploading a new photo,
/// only for displaying `profilePicPath` if one already exists from the web app.
class Faculty {
  Faculty({
    required this.facultyId,
    required this.employeeCode,
    required this.fullName,
    this.designationId,
    this.designationName,
    this.qualification,
    this.specialization,
    this.gender,
    this.dateOfBirth,
    this.dateOfJoining,
    this.phone,
    this.alternatePhone,
    this.email,
    this.address,
    this.profilePicPath,
    this.salary,
    this.bloodGroup,
    this.aadharNo,
    this.status = 'Active',
    this.remarks,
    this.createdAt,
    this.createdByName,
  });

  final int facultyId;
  final String employeeCode;
  final String fullName;
  final int? designationId;
  final String? designationName;
  final String? qualification;
  final String? specialization;
  final String? gender;
  final DateTime? dateOfBirth;
  final DateTime? dateOfJoining;
  final String? phone;
  final String? alternatePhone;
  final String? email;
  final String? address;
  final String? profilePicPath;
  final double? salary;
  final String? bloodGroup;
  final String? aadharNo;
  final String status;
  final String? remarks;
  final DateTime? createdAt;
  final String? createdByName;

  /// "Firstname ma'am" for Female, "Firstname sir" for Male/other — mirrors Faculty.DisplayName server-side.
  String get displayName => fullName.trim().isEmpty ? fullName : '${fullName.trim()} ${gender == 'Female' ? "MA'AM" : 'SIR'}';

  factory Faculty.fromJson(Map<String, dynamic> j) => Faculty(
        facultyId: _asInt(j['facultyId']),
        employeeCode: _asString(j['employeeCode']),
        fullName: _asString(j['fullName']),
        designationId: _asIntN(j['designationId']),
        designationName: _asStringN(j['designationName']),
        qualification: _asStringN(j['qualification']),
        specialization: _asStringN(j['specialization']),
        gender: _asStringN(j['gender']),
        dateOfBirth: j['dateOfBirth'] == null ? null : DateTime.tryParse(j['dateOfBirth'].toString()),
        dateOfJoining: j['dateOfJoining'] == null ? null : DateTime.tryParse(j['dateOfJoining'].toString()),
        phone: _asStringN(j['phone']),
        alternatePhone: _asStringN(j['alternatePhone']),
        email: _asStringN(j['email']),
        address: _asStringN(j['address']),
        profilePicPath: _asStringN(j['profilePicPath']),
        salary: _asDoubleN(j['salary']),
        bloodGroup: _asStringN(j['bloodGroup']),
        aadharNo: _asStringN(j['aadharNo']),
        status: j['status'] == null ? 'Active' : _asString(j['status']),
        remarks: _asStringN(j['remarks']),
        createdAt: j['createdAt'] == null ? null : DateTime.tryParse(j['createdAt'].toString()),
        createdByName: _asStringN(j['createdByName']),
      );

  Map<String, dynamic> toSaveJson() => {
        'facultyId': facultyId,
        'employeeCode': employeeCode,
        'fullName': fullName,
        'designationId': designationId,
        'qualification': qualification,
        'specialization': specialization,
        'gender': gender,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'dateOfJoining': dateOfJoining?.toIso8601String(),
        'phone': phone,
        'alternatePhone': alternatePhone,
        'email': email,
        'address': address,
        'salary': salary,
        'bloodGroup': bloodGroup,
        'aadharNo': aadharNo,
        'status': status,
        'remarks': remarks,
      };
}
