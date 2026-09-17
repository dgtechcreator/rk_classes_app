import '../core/api_client.dart';
import '../models/fee_structure.dart';

class FeeStructureListResult {
  FeeStructureListResult({required this.list, required this.summary});
  final List<FeeStructure> list;
  final List<FeeStructureSummary> summary;
}

class FeesDueResult {
  FeesDueResult({required this.data, required this.total, required this.page, required this.totalPages});
  final List<StudentFee> data;
  final int total;
  final int page;
  final int totalPages;
}

class FeeStructureService {
  final _client = ApiClient.instance;

  Future<FeeStructureListResult> getAll({int? yearId, int? classId, int? sectionId}) async {
    final res = await _client.get('/api/fee-structure', query: {
      if (yearId != null) 'yearId': yearId,
      if (classId != null) 'classId': classId,
      if (sectionId != null) 'sectionId': sectionId,
    });
    final data = res.data as Map<String, dynamic>;
    return FeeStructureListResult(
      list: (data['list'] as List? ?? []).map((e) => FeeStructure.fromJson(e as Map<String, dynamic>)).toList(),
      summary: (data['summary'] as List? ?? []).map((e) => FeeStructureSummary.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<int> save(Map<String, dynamic> json) async {
    final res = await _client.post('/api/fee-structure/save', data: json);
    final data = res.data as Map<String, dynamic>;
    return data['structureId'] as int? ?? 0;
  }

  Future<void> delete(int id) async => _client.post('/api/fee-structure/$id/delete');

  Future<FeesDueResult> getFeesDue({
    int? yearId,
    int? classId,
    int? sectionId,
    int? feeTypeId,
    String? status,
    int page = 1,
  }) async {
    final res = await _client.get('/api/fee-structure/fees-due', query: {
      if (yearId != null) 'yearId': yearId,
      if (classId != null) 'classId': classId,
      if (sectionId != null) 'sectionId': sectionId,
      if (feeTypeId != null) 'feeTypeId': feeTypeId,
      if (status != null && status.isNotEmpty) 'status': status,
      'page': page,
    });
    final data = res.data as Map<String, dynamic>;
    return FeesDueResult(
      data: (data['data'] as List? ?? []).map((e) => StudentFee.fromJson(e as Map<String, dynamic>)).toList(),
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? 1,
      totalPages: data['totalPages'] as int? ?? 1,
    );
  }

  Future<void> collectFee({
    required int studentFeeId,
    required double paidAmount,
    required double discount,
    required double lateFine,
    required String paymentMode,
    String? transactionRef,
    String? remarks,
  }) async {
    await _client.post('/api/fee-structure/collect-fee', data: {
      'studentFeeId': studentFeeId,
      'paidAmount': paidAmount,
      'discount': discount,
      'lateFine': lateFine,
      'paymentMode': paymentMode,
      'transactionRef': transactionRef,
      'remarks': remarks,
    });
  }
}
