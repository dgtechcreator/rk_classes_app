import '../core/api_client.dart';

int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

/// One Class Representative (CR / Monitor) as listed on the admin screen.
class ClassRep {
  ClassRep({
    required this.crId,
    required this.username,
    required this.studentName,
    required this.admissionNo,
    required this.classLabel,
    required this.limitToBatch,
    required this.hasBatch,
    required this.isActive,
    required this.isWorking,
    required this.studentActive,
    this.batchName,
    this.rights = const [],
  });

  final int crId;
  final String username;
  final String studentName;
  final String admissionNo;
  final String classLabel; // "5th · English · Morning"
  final bool limitToBatch;
  final bool hasBatch;
  final bool isActive;
  final bool isWorking;
  final bool studentActive;
  final String? batchName;
  final List<String> rights; // attendance_entry / teacher_attendance / marks_entry

  factory ClassRep.fromJson(Map<String, dynamic> j) => ClassRep(
        crId: _i(j['crId']),
        username: _s(j['username']),
        studentName: _s(j['studentName']),
        admissionNo: _s(j['admissionNo']),
        classLabel: [j['className'], j['sectionName'], j['batchName']].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
        limitToBatch: j['limitToBatch'] == true,
        hasBatch: j['batchId'] != null,
        isActive: j['isActive'] == true,
        isWorking: j['isWorking'] == true,
        studentActive: _s(j['studentStatus']).toLowerCase() == 'active',
        batchName: j['batchName'] as String?,
        rights: (j['rights'] as List? ?? []).map((e) => e.toString()).toList(),
      );
}

/// The things a CR can be allowed to do (module key -> label).
const crRightLabels = <String, String>{
  'attendance_entry': 'Student attendance',
  'teacher_attendance': 'Teacher attendance',
  'marks_entry': 'Test marks',
};

/// A student who can still be made CR (picker row).
class CrCandidate {
  CrCandidate({required this.studentId, required this.name, required this.admissionNo, required this.hasBatch, this.batchName});
  final int studentId;
  final String name;
  final String admissionNo;
  final bool hasBatch;
  final String? batchName;

  factory CrCandidate.fromJson(Map<String, dynamic> j) => CrCandidate(
        studentId: _i(j['studentId']),
        name: _s(j['name']),
        admissionNo: _s(j['admissionNo']),
        hasBatch: j['hasBatch'] == true,
        batchName: j['batchName'] as String?,
      );
}

/// Wraps api/class-reps (ClassRepApiController) - admin only on the server as well.
class ClassRepService {
  final _client = ApiClient.instance;

  Future<List<ClassRep>> getAll() async {
    final res = await _client.get('/api/class-reps');
    return (res.data as List).map((e) => ClassRep.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CrCandidate>> getStudents({required int classId, int? sectionId}) async {
    final res = await _client.get('/api/class-reps/students', query: {'classId': classId, if (sectionId != null) 'sectionId': sectionId});
    return (res.data as List).map((e) => CrCandidate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> assign({required int studentId, required String username, required String password, required bool limitToBatch, required List<String> rights}) async {
    final res = await _client.post('/api/class-reps', data: {
      'studentId': studentId,
      'username': username,
      'password': password,
      'limitToBatch': limitToBatch,
      'rights': rights,
    });
    return _result(res.data, 'Could not save.');
  }

  Future<String> update(int crId, {required bool limitToBatch, required bool isActive, String? newPassword, required List<String> rights}) async {
    final res = await _client.post('/api/class-reps/$crId/update', data: {
      'limitToBatch': limitToBatch,
      'isActive': isActive,
      'newPassword': (newPassword ?? '').isEmpty ? null : newPassword,
      'rights': rights,
    });
    return _result(res.data, 'Could not save.');
  }

  /// The API answers 200 with {success:false, message} for business-rule refusals - surface those as errors.
  String _result(dynamic data, String fallback) {
    final m = data as Map<String, dynamic>;
    if (m['success'] != true) throw ApiException(_s(m['message']).isEmpty ? fallback : _s(m['message']));
    return _s(m['message']);
  }
}
