import '../core/api_client.dart';
import '../models/lookup.dart';
import '../models/marks.dart';

/// Dropdown data every module screen needs — cached in memory for the session since these lists
/// (academic years, classes, sections, batches, fee types) change rarely.
class LookupService {
  final _client = ApiClient.instance;

  List<LookupItem>? _years, _classes, _sections, _batches, _feeTypes, _expenseCats;
  final Map<int, List<Subject>> _subjectsByClass = {};
  List<ExamOption>? _exams;

  Future<List<LookupItem>> getYears({bool refresh = false}) async {
    if (_years != null && !refresh) return _years!;
    final res = await _client.get('/api/lookup/years');
    return _years = (res.data as List).map((e) => LookupItem.fromYear(e as Map<String, dynamic>)).toList();
  }

  Future<List<LookupItem>> getClasses({bool refresh = false}) async {
    if (_classes != null && !refresh) return _classes!;
    final res = await _client.get('/api/lookup/classes');
    return _classes = (res.data as List).map((e) => LookupItem.fromClass(e as Map<String, dynamic>)).toList();
  }

  Future<List<LookupItem>> getSections({bool refresh = false}) async {
    if (_sections != null && !refresh) return _sections!;
    final res = await _client.get('/api/lookup/sections');
    return _sections = (res.data as List).map((e) => LookupItem.fromSection(e as Map<String, dynamic>)).toList();
  }

  Future<List<LookupItem>> getBatches({bool refresh = false}) async {
    if (_batches != null && !refresh) return _batches!;
    final res = await _client.get('/api/lookup/batches');
    return _batches = (res.data as List).map((e) => LookupItem.fromBatch(e as Map<String, dynamic>)).toList();
  }

  Future<List<LookupItem>> getFeeTypes({bool refresh = false}) async {
    if (_feeTypes != null && !refresh) return _feeTypes!;
    final res = await _client.get('/api/lookup/fee-types');
    return _feeTypes = (res.data as List).map((e) => LookupItem.fromFeeType(e as Map<String, dynamic>)).toList();
  }

  Future<List<LookupItem>> getExpenseCats({bool refresh = false}) async {
    if (_expenseCats != null && !refresh) return _expenseCats!;
    final res = await _client.get('/api/lookup/exp-cats');
    return _expenseCats = (res.data as List).map((e) => LookupItem.fromExpenseCat(e as Map<String, dynamic>)).toList();
  }

  /// Subjects for one class (each carries its own MaxMarks/PassMarks) — used by the Marks module once
  /// a class is picked.
  Future<List<Subject>> getSubjects(int classId, {bool refresh = false}) async {
    if (!refresh && _subjectsByClass.containsKey(classId)) return _subjectsByClass[classId]!;
    final res = await _client.get('/api/lookup/subjects', query: {'classId': classId});
    final list = (res.data as List).map((e) => Subject.fromJson(e as Map<String, dynamic>)).toList();
    _subjectsByClass[classId] = list;
    return list;
  }

  /// All exams across classes/years — used by the Marks entry screen to suggest exam names.
  Future<List<ExamOption>> getExams({bool refresh = false}) async {
    if (_exams != null && !refresh) return _exams!;
    final res = await _client.get('/api/lookup/exams');
    return _exams = (res.data as List).map((e) => ExamOption.fromJson(e as Map<String, dynamic>)).toList();
  }
}
