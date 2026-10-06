import '../core/api_client.dart';
import '../models/finance.dart';

/// Wraps GET api/finance/* (FinanceApiController) — collection-analytics dashboard, gated behind the
/// `finance_view` permission (see SQL/46_AddFinanceModule.sql).
class FinanceService {
  final _client = ApiClient.instance;

  Future<FinanceDashboardData> getDashboard() async {
    final res = await _client.get('/api/finance/dashboard');
    return FinanceDashboardData.fromJson(res.data as Map<String, dynamic>);
  }

  /// All active students with their fee position; pass [className] (+ [batchName], blank = no batch) to
  /// limit to one class/batch row of the dashboard.
  Future<FinanceStudentsResult> getStudents({String? className, String? batchName, String? sectionName, bool anyBatch = false}) async {
    final res = await _client.get('/api/finance/students', query: {
      if (className != null) 'className': className,
      if (className != null) 'batchName': batchName ?? '',
      if (sectionName != null) 'sectionName': sectionName,
      if (anyBatch) 'anyBatch': 'true',
    });
    return FinanceStudentsResult.fromJson(res.data as Map<String, dynamic>);
  }
}
