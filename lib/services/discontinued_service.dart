import '../core/api_client.dart';

int _i(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String _s(dynamic v) => v?.toString() ?? '';

/// One student who left the classes or was removed - with the reason and the fee snapshot of that day.
class DiscontinuedEntry {
  DiscontinuedEntry({
    required this.id, required this.studentId, required this.studentName, required this.admissionNo, required this.className,
    required this.sectionName, required this.batchName, required this.fatherPhone, required this.kind, required this.reason,
    required this.leftOn, required this.totalFees, required this.paid, required this.pending, required this.recordedByName,
    required this.recordedAt, required this.returned, required this.canRevert, this.revertedAt, this.revertedByName = '', this.revertNote = '',
  });
  final int id, studentId;
  final String studentName, admissionNo, className, sectionName, batchName, fatherPhone, kind, reason, recordedByName;
  final DateTime? leftOn, recordedAt;
  final double totalFees, paid, pending;
  final bool returned;
  /// Only the newest entry of a student that is still discontinued can be reverted.
  final bool canRevert;
  final DateTime? revertedAt;
  final String revertedByName, revertNote;

  bool get removed => kind == 'Removed';

  factory DiscontinuedEntry.fromJson(Map<String, dynamic> j) => DiscontinuedEntry(
        id: _i(j['id']), studentId: _i(j['studentId']), studentName: _s(j['studentName']), admissionNo: _s(j['admissionNo']),
        className: _s(j['className']).trim(), sectionName: _s(j['sectionName']).trim(), batchName: _s(j['batchName']).trim(),
        fatherPhone: _s(j['fatherPhone']), kind: _s(j['kind']), reason: _s(j['reason']),
        leftOn: DateTime.tryParse(_s(j['leftOn'])), totalFees: _d(j['totalFees']), paid: _d(j['paid']), pending: _d(j['pending']),
        recordedByName: _s(j['recordedByName']), recordedAt: DateTime.tryParse(_s(j['recordedAt'])), returned: j['returned'] == true,
        canRevert: j['canRevert'] == true, revertedAt: DateTime.tryParse(_s(j['revertedAt'])),
        revertedByName: _s(j['revertedByName']), revertNote: _s(j['revertNote']),
      );
}

class DiscontinuePick {
  DiscontinuePick({required this.studentId, required this.name, required this.admissionNo, required this.medium, required this.batch});
  final int studentId;
  final String name, admissionNo, medium, batch;

  factory DiscontinuePick.fromJson(Map<String, dynamic> j) => DiscontinuePick(
        studentId: _i(j['studentId']), name: _s(j['name']), admissionNo: _s(j['admissionNo']), medium: _s(j['medium']), batch: _s(j['batch']));
}

/// Everything about one student shown before they are taken off the roll (like the 360 view).
class DiscontinueOverview {
  DiscontinueOverview(this.j);
  final Map<String, dynamic> j;

  String get name => _s(j['name']);
  String get admissionNo => _s(j['admissionNo']);
  String get classLine => [_s(j['className']), _s(j['sectionName']), _s(j['batchName'])].where((e) => e.trim().isNotEmpty).join(' · ');
  String get fatherName => _s(j['fatherName']);
  String get fatherPhone => _s(j['fatherPhone']);
  String get motherName => _s(j['motherName']);
  String get motherPhone => _s(j['motherPhone']);
  Map<String, dynamic>? get attendance => j['attendance'] as Map<String, dynamic>?;
  double get marksPct => _d(j['marksPct']);
  int get testsCount => _i(j['testsCount']);
  Map<String, dynamic> get fee => (j['fee'] as Map<String, dynamic>?) ?? {};
  List<Map<String, dynamic>> get payments => ((j['payments'] as List?) ?? []).map((e) => e as Map<String, dynamic>).toList();
  double get balance => _d(fee['balance']);
}

class DiscontinuedService {
  final _client = ApiClient.instance;

  Future<List<DiscontinuedEntry>> getAll() async {
    final res = await _client.get('/api/discontinued');
    return (res.data as List).map((e) => DiscontinuedEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DiscontinuePick>> getStudents({required int classId, int? sectionId, int? batchId}) async {
    final res = await _client.get('/api/discontinued/students', query: {'classId': classId, 'sectionId': ?sectionId, 'batchId': ?batchId});
    return (res.data as List).map((e) => DiscontinuePick.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DiscontinueOverview> getOverview(int studentId) async {
    final res = await _client.get('/api/discontinued/overview/$studentId');
    return DiscontinueOverview(res.data as Map<String, dynamic>);
  }

  /// Takes the student back: Active again, the entry stays as history.
  Future<void> revert(int entryId, {String? note}) async => _client.post('/api/discontinued/$entryId/revert', data: {'note': note});

  Future<void> save({required int studentId, required String kind, required String reason, required DateTime leftOn}) async {
    await _client.post('/api/discontinued/save', data: {
      'studentId': studentId, 'kind': kind, 'reason': reason,
      'leftOn': '${leftOn.year}-${leftOn.month.toString().padLeft(2, '0')}-${leftOn.day.toString().padLeft(2, '0')}',
    });
  }
}
