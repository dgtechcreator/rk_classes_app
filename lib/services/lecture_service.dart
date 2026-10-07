import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/lecture.dart';

String _d(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Wraps LecturesApiController (api/lectures) for staff, plus the parent's api/parent/lectures.
class LectureService {
  final _client = ApiClient.instance;

  Map<String, dynamic> _query(LectureFilters f) => {
        if (f.from != null) 'from': _d(f.from!),
        if (f.to != null) 'to': _d(f.to!),
        if (f.classId != null) 'classId': f.classId,
        if (f.sectionId != null) 'sectionId': f.sectionId,
        if (f.batchId != null) 'batchId': f.batchId,
        if (f.subject != null) 'subject': f.subject,
        if (f.facultyId != null) 'facultyId': f.facultyId,
      };

  LectureOptions? _options;
  Future<LectureOptions> getOptions({bool refresh = false}) async {
    if (_options != null && !refresh) return _options!;
    final res = await _client.get('/api/lectures/options');
    return _options = LectureOptions.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LectureListResult> list(LectureFilters f) async {
    final res = await _client.get('/api/lectures', query: {..._query(f), if (f.status != null) 'status': f.status});
    return LectureListResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LectureSummaryResult> summary(LectureFilters f, String groupBy) async {
    final res = await _client.get('/api/lectures/summary', query: {..._query(f), 'groupBy': groupBy});
    return LectureSummaryResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// Creates (lectureId 0) or updates one lecture; with [repeatDays] + [repeatUntil] a weekly series is created.
  Future<String> save({
    int lectureId = 0,
    required DateTime date,
    required String startTime,
    required String endTime,
    required int classId,
    int? sectionId,
    int? batchId,
    required String subject,
    required int facultyId,
    String? topic,
    String? remarks,
    List<int> repeatDays = const [],
    DateTime? repeatUntil,
  }) async {
    final repeat = lectureId == 0 && repeatDays.isNotEmpty;
    final res = await _client.post('/api/lectures/save', data: {
      'lectureId': lectureId,
      'date': _d(date),
      'startTime': startTime,
      'endTime': endTime,
      'classId': classId,
      'sectionId': sectionId,
      'batchId': batchId,
      'subjectName': subject,
      'facultyId': facultyId,
      'topic': topic,
      'remarks': remarks,
      'repeat': repeat,
      'repeatDays': repeat ? repeatDays : <int>[],
      'repeatUntil': repeat && repeatUntil != null ? _d(repeatUntil) : null,
    });
    return (res.data as Map<String, dynamic>)['message']?.toString() ?? 'Saved.';
  }

  Future<void> setStatus(int id, String status, {String? note}) =>
      _client.post('/api/lectures/$id/status', data: {'status': status, 'note': note});

  Future<void> delete(int id) => _client.post('/api/lectures/$id/delete');

  /// Deletes this lecture and all later, not-yet-completed ones of the same repeating schedule.
  Future<void> deleteSeries(int id) => _client.post('/api/lectures/$id/delete-series');

  Future<MyLectures> mine({DateTime? from, DateTime? to}) async {
    final res = await _client.get('/api/lectures/mine', query: {
      if (from != null) 'from': _d(from),
      if (to != null) 'to': _d(to),
    });
    return MyLectures.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ParentLectures> forParent(int studentId, DateTime date) async {
    final res = await _client.get('/api/parent/lectures', query: {'studentId': studentId, 'date': _d(date)});
    return ParentLectures.fromJson(res.data as Map<String, dynamic>);
  }
}
