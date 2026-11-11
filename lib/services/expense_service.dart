import '../core/api_client.dart';
import '../models/expense.dart';
import '../models/lookup.dart';

class ExpenseCategoryTotal {
  ExpenseCategoryTotal({required this.category, required this.count, required this.amount});
  final String category;
  final int count;
  final double amount;
}

class ExpenseListResult {
  ExpenseListResult({
    required this.expenses,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.categories,
    required this.years,
    this.totalAmount = 0,
    this.byCategory = const [],
  });
  final List<Expense> expenses;
  final int total;
  final int page;
  final int totalPages;
  final List<LookupItem> categories;
  final List<LookupItem> years;
  /// Total of EVERYTHING that matches the filter (not just this page).
  final double totalAmount;
  final List<ExpenseCategoryTotal> byCategory;
}

class ExpenseService {
  final _client = ApiClient.instance;

  String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Normal expenses + paid teacher salary. Give one of: [month] (that calendar month), [from]/[to] (custom range) or [all]; with none of them
  /// the server returns the current month.
  Future<ExpenseListResult> getAll({int page = 1, String? search, int? categoryId, DateTime? month, DateTime? from, DateTime? to, bool all = false}) async {
    final res = await _client.get('/api/expenses', query: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'category': categoryId,
      if (all) 'all': 'true'
      else if (from != null || to != null) ...{
        if (from != null) 'from': _d(from),
        if (to != null) 'to': _d(to),
      } else if (month != null) 'ym': '${month.year}-${month.month.toString().padLeft(2, '0')}',
    });
    final data = res.data as Map<String, dynamic>;
    return ExpenseListResult(
      expenses: (data['expenses'] as List? ?? []).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList(),
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? 1,
      totalPages: data['totalPages'] as int? ?? 1,
      categories: (data['categories'] as List? ?? []).map((e) => LookupItem.fromExpenseCat(e as Map<String, dynamic>)).toList(),
      years: (data['years'] as List? ?? []).map((e) => LookupItem.fromYear(e as Map<String, dynamic>)).toList(),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      byCategory: (data['byCategory'] as List? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return ExpenseCategoryTotal(category: '${m['category']}', count: (m['count'] as num?)?.toInt() ?? 0, amount: (m['amount'] as num?)?.toDouble() ?? 0);
      }).toList(),
    );
  }

  Future<void> save(Map<String, dynamic> expenseJson) async {
    await _client.post('/api/expenses/save', data: expenseJson);
  }

  Future<void> delete(int id) async => _client.post('/api/expenses/$id/delete');
}
