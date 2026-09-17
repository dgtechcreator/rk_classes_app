import '../core/api_client.dart';
import '../models/dashboard.dart';

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
}
