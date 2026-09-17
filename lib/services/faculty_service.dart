import '../core/api_client.dart';
import '../models/faculty.dart';

class FacultyListResult {
  FacultyListResult({required this.data, required this.total, required this.page, required this.totalPages, required this.designations});
  final List<Faculty> data;
  final int total;
  final int page;
  final int totalPages;
  final List<Designation> designations;
}

class FacultyDetail {
  FacultyDetail({required this.faculty, required this.subjects});
  final Faculty faculty;
  final List<FacultySubject> subjects;
}

class FacultyService {
  final _client = ApiClient.instance;

  Future<FacultyListResult> getAll({int page = 1, String? search, String status = 'Active', int? designationId}) async {
    final res = await _client.get('/api/faculty', query: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      'status': status,
      if (designationId != null) 'designationId': designationId,
    });
    final data = res.data as Map<String, dynamic>;
    return FacultyListResult(
      data: (data['data'] as List? ?? []).map((e) => Faculty.fromJson(e as Map<String, dynamic>)).toList(),
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? 1,
      totalPages: data['totalPages'] as int? ?? 1,
      designations: (data['designations'] as List? ?? []).map((e) => Designation.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<FacultyDetail> getById(int id) async {
    final res = await _client.get('/api/faculty/$id');
    final data = res.data as Map<String, dynamic>;
    return FacultyDetail(
      faculty: Faculty.fromJson(data['faculty'] as Map<String, dynamic>),
      subjects: (data['subjects'] as List? ?? []).map((e) => FacultySubject.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<int> save(Map<String, dynamic> facultyJson) async {
    final res = await _client.post('/api/faculty/save', data: facultyJson);
    final data = res.data as Map<String, dynamic>;
    return data['facultyId'] as int? ?? 0;
  }

  Future<void> delete(int id) async => _client.post('/api/faculty/$id/delete');

  /// There's no standalone designations endpoint — Index bundles them in with the list, so the
  /// create form (which needs the dropdown before any faculty row has loaded) piggybacks on it.
  Future<List<Designation>> getDesignations() async {
    final res = await _client.get('/api/faculty', query: {'page': 1, 'status': 'Active'});
    final data = res.data as Map<String, dynamic>;
    return (data['designations'] as List? ?? []).map((e) => Designation.fromJson(e as Map<String, dynamic>)).toList();
  }
}
