import '../core/api_client.dart';
import '../models/expense.dart';
import '../models/lookup.dart';

class ExpenseListResult {
  ExpenseListResult({
    required this.expenses,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.categories,
    required this.years,
  });
  final List<Expense> expenses;
  final int total;
  final int page;
  final int totalPages;
  final List<LookupItem> categories;
  final List<LookupItem> years;
}

class ExpenseService {
  final _client = ApiClient.instance;

  Future<ExpenseListResult> getAll({int page = 1, String? search, int? categoryId, int? month, int? year}) async {
    final res = await _client.get('/api/expenses', query: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'category': categoryId,
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    final data = res.data as Map<String, dynamic>;
    return ExpenseListResult(
      expenses: (data['expenses'] as List? ?? []).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList(),
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? 1,
      totalPages: data['totalPages'] as int? ?? 1,
      categories: (data['categories'] as List? ?? []).map((e) => LookupItem.fromExpenseCat(e as Map<String, dynamic>)).toList(),
      years: (data['years'] as List? ?? []).map((e) => LookupItem.fromYear(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> save(Map<String, dynamic> expenseJson) async {
    await _client.post('/api/expenses/save', data: expenseJson);
  }

  Future<void> delete(int id) async => _client.post('/api/expenses/$id/delete');
}
