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

  Future<FinanceClassDetail> getClassDetail(String className, String batchName) async {
    final res = await _client.get('/api/finance/class-detail', query: {'className': className, 'batchName': batchName});
    return FinanceClassDetail.fromJson(res.data as Map<String, dynamic>);
  }
}
