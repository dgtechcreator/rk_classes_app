import '../core/api_client.dart';
import '../models/dashboard.dart';
import '../models/student.dart';

class StaffDashboardService {
  final _client = ApiClient.instance;

  Future<StaffDashboardData> getDashboard() async {
    final res = await _client.get('/api/dashboard');
    return StaffDashboardData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<AbsentStudent>> getAbsentToday() async {
    final res = await _client.get('/api/dashboard/absent-today');
    return (res.data as List).map((e) => AbsentStudent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AbsentStudent>> getPresentToday() async {
    final res = await _client.get('/api/dashboard/present-today');
    return (res.data as List).map((e) => AbsentStudent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<({List<FeePayment> payments, double total})> getFeesThisMonth() async {
    final res = await _client.get('/api/dashboard/fees-this-month');
    final data = res.data as Map<String, dynamic>;
    final payments = (data['payments'] as List? ?? []).map((e) => FeePayment.fromJson(e as Map<String, dynamic>)).toList();
    final total = data['total'] is num ? (data['total'] as num).toDouble() : payments.fold<double>(0, (a, p) => a + p.netAmount);
    return (payments: payments, total: total);
  }
}
