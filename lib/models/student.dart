int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _asIntN(dynamic v) => v == null ? null : _asInt(v);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();

class Student {
  Student({
    required this.studentId,
    required this.admissionNo,
    required this.fullName,
    this.gender,
    this.dateOfBirth,
    this.fatherName,
    this.motherName,
    this.phone,
    this.fatherPhone,
    this.motherPhone,
    this.email,
    this.address,
    this.profilePicPath,
    this.academicYearId,
    this.yearName,
    this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
    this.batchId,
    this.batchName,
    this.rollNo,
    this.bloodGroup,
    this.admissionDate,
    this.status = 'Active',
  });

  final int studentId;
  final String admissionNo;
  final String fullName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? fatherName;
  final String? motherName;
  final String? phone;
  final String? fatherPhone;
  final String? motherPhone;
  final String? email;
  final String? address;
  final String? profilePicPath;
  final int? academicYearId;
  final String? yearName;
  final int? classId;
  final String? className;
  final int? sectionId;
  final String? sectionName;
  final int? batchId;
  final String? batchName;
  final String? rollNo;
  final String? bloodGroup;
  final DateTime? admissionDate;
  final String status;

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        studentId: _asInt(j['studentId']),
        admissionNo: _asString(j['admissionNo']),
        fullName: _asString(j['fullName']),
        gender: _asStringN(j['gender']),
        dateOfBirth: j['dateOfBirth'] == null ? null : DateTime.tryParse(j['dateOfBirth'].toString()),
        fatherName: _asStringN(j['fatherName']),
        motherName: _asStringN(j['motherName']),
        phone: _asStringN(j['phone']),
        fatherPhone: _asStringN(j['fatherPhone']),
        motherPhone: _asStringN(j['motherPhone']),
        email: _asStringN(j['email']),
        address: _asStringN(j['address']),
        profilePicPath: _asStringN(j['profilePicPath']),
        academicYearId: _asIntN(j['academicYearId']),
        yearName: _asStringN(j['yearName']),
        classId: _asIntN(j['classId']),
        className: _asStringN(j['className']),
        sectionId: _asIntN(j['sectionId']),
        sectionName: _asStringN(j['sectionName']),
        batchId: _asIntN(j['batchId']),
        batchName: _asStringN(j['batchName']),
        rollNo: _asStringN(j['rollNo']),
        bloodGroup: _asStringN(j['bloodGroup']),
        admissionDate: j['admissionDate'] == null ? null : DateTime.tryParse(j['admissionDate'].toString()),
        status: j['status'] == null ? 'Active' : _asString(j['status']),
      );

  Map<String, dynamic> toSaveJson() => {
        'studentId': studentId,
        'admissionNo': admissionNo,
        'fullName': fullName,
        'gender': gender,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'fatherName': fatherName,
        'motherName': motherName,
        'phone': phone,
        'fatherPhone': fatherPhone,
        'motherPhone': motherPhone,
        'email': email,
        'address': address,
        'academicYearId': academicYearId,
        'classId': classId,
        'sectionId': sectionId,
        'batchId': batchId,
        'rollNo': rollNo,
        'bloodGroup': bloodGroup,
        'admissionDate': admissionDate?.toIso8601String(),
        'status': status,
      };

  String get classLabel => [className, sectionName, batchName].where((e) => e != null && e.isNotEmpty).join(' / ');
}

class AttendanceReport {
  AttendanceReport({
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.totalDays,
    required this.attendancePct,
  });

  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int totalDays;
  final double attendancePct;

  factory AttendanceReport.fromJson(Map<String, dynamic> j) => AttendanceReport(
        presentDays: _asInt(j['presentDays']),
        absentDays: _asInt(j['absentDays']),
        lateDays: _asInt(j['lateDays']),
        totalDays: _asInt(j['totalDays']),
        attendancePct: _asDouble(j['attendancePct']),
      );
}

class StudentAttendanceDetail {
  StudentAttendanceDetail({required this.attendanceDate, required this.status, this.subject, this.sirName, this.remarks});

  final DateTime attendanceDate;
  final String status;
  final String? subject;
  final String? sirName;
  final String? remarks;

  factory StudentAttendanceDetail.fromJson(Map<String, dynamic> j) => StudentAttendanceDetail(
        attendanceDate: DateTime.tryParse(_asString(j['attendanceDate'])) ?? DateTime.now(),
        status: j['status'] == null ? 'Present' : _asString(j['status']),
        subject: _asStringN(j['subject']),
        sirName: _asStringN(j['sirName']),
        remarks: _asStringN(j['remarks']),
      );
}

class TestMark {
  TestMark({
    required this.markId,
    required this.examId,
    this.examName,
    this.subjectName,
    this.marksObtained,
    required this.maxMarks,
    this.grade,
    this.testDate,
  });

  final int markId;
  final int examId;
  final String? examName;
  final String? subjectName;
  final double? marksObtained;
  final int maxMarks;
  final String? grade;
  final DateTime? testDate;

  factory TestMark.fromJson(Map<String, dynamic> j) => TestMark(
        markId: _asInt(j['markId']),
        examId: _asInt(j['examId']),
        examName: _asStringN(j['examName']),
        subjectName: _asStringN(j['subjectName']),
        marksObtained: j['marksObtained'] == null ? null : _asDouble(j['marksObtained']),
        maxMarks: j['maxMarks'] == null ? 100 : _asInt(j['maxMarks']),
        grade: _asStringN(j['grade']),
        testDate: j['testDate'] == null ? null : DateTime.tryParse(_asString(j['testDate'])),
      );
}

class FeePayment {
  FeePayment({
    required this.paymentId,
    required this.receiptNo,
    this.studentId,
    this.studentName,
    this.admissionNo,
    this.className,
    this.sectionName,
    this.batchName,
    this.feeTypeName,
    required this.amount,
    required this.discount,
    required this.lateFine,
    required this.netAmount,
    required this.paymentDate,
    this.dueDate,
    this.month,
    required this.paymentMode,
    this.transactionRef,
    this.remarks,
    this.collectorName,
  });

  final int paymentId;
  final String receiptNo;
  final int? studentId;
  final String? studentName;
  final String? admissionNo;
  final String? className;
  final String? sectionName;
  final String? batchName;
  final String? feeTypeName;
  final double amount;
  final double discount;
  final double lateFine;
  final double netAmount;
  final DateTime paymentDate;
  final DateTime? dueDate;
  final String? month;
  final String paymentMode;
  final String? transactionRef;
  final String? remarks;
  final String? collectorName;

  factory FeePayment.fromJson(Map<String, dynamic> j) => FeePayment(
        paymentId: _asInt(j['paymentId']),
        receiptNo: _asString(j['receiptNo']),
        studentId: _asIntN(j['studentId']),
        studentName: _asStringN(j['studentName']),
        admissionNo: _asStringN(j['admissionNo']),
        className: _asStringN(j['className']),
        sectionName: _asStringN(j['sectionName']),
        batchName: _asStringN(j['batchName']),
        feeTypeName: _asStringN(j['feeTypeName']),
        amount: _asDouble(j['amount']),
        discount: _asDouble(j['discount']),
        lateFine: _asDouble(j['lateFine']),
        netAmount: _asDouble(j['netAmount']),
        paymentDate: DateTime.tryParse(_asString(j['paymentDate'])) ?? DateTime.now(),
        dueDate: j['dueDate'] == null ? null : DateTime.tryParse(j['dueDate'].toString()),
        month: _asStringN(j['month']),
        paymentMode: j['paymentMode'] == null ? 'Cash' : _asString(j['paymentMode']),
        transactionRef: _asStringN(j['transactionRef']),
        remarks: _asStringN(j['remarks']),
        collectorName: _asStringN(j['collectorName']),
      );

  String get classLabel => [className, sectionName, batchName].where((e) => e != null && e.isNotEmpty).join(' / ');
}

/// Aggregate response from GET /api/parent/dashboard/{studentId} — mirrors ParentController.Dashboard's
/// ParentDashboardVM, just as one JSON payload instead of a Razor view model.
class ParentDashboardData {
  ParentDashboardData({
    required this.student,
    this.attendance,
    required this.attendanceDetail,
    required this.marks,
    required this.feeHistory,
    required this.totalPaid,
    required this.actualFee,
    required this.balance,
  });

  final Student student;
  final AttendanceReport? attendance;
  final List<StudentAttendanceDetail> attendanceDetail;
  final List<TestMark> marks;
  final List<FeePayment> feeHistory;
  final double totalPaid;
  final double actualFee;
  final double balance;

  factory ParentDashboardData.fromJson(Map<String, dynamic> j) => ParentDashboardData(
        student: Student.fromJson(j['student'] as Map<String, dynamic>),
        attendance: j['attendance'] == null ? null : AttendanceReport.fromJson(j['attendance'] as Map<String, dynamic>),
        attendanceDetail: (j['attendanceDetail'] as List? ?? [])
            .map((e) => StudentAttendanceDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
        marks: (j['marks'] as List? ?? []).map((e) => TestMark.fromJson(e as Map<String, dynamic>)).toList(),
        feeHistory: (j['feeHistory'] as List? ?? []).map((e) => FeePayment.fromJson(e as Map<String, dynamic>)).toList(),
        totalPaid: _asDouble(j['totalPaid']),
        actualFee: _asDouble(j['actualFee']),
        balance: _asDouble(j['balance']),
      );
}
