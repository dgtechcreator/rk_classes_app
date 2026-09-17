int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _asIntN(dynamic v) => v == null ? null : _asInt(v);
double _asDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();

/// Mirrors SchoolMS.Domain.Expense.
class Expense {
  Expense({
    this.expenseId = 0,
    this.expenseNo = '',
    this.categoryId,
    this.categoryName,
    required this.title,
    this.description,
    required this.amount,
    required this.expenseDate,
    this.paymentMode = 'Cash',
    this.billNo,
    this.vendorName,
    this.enteredByName,
    this.createdAt,
  });

  final int expenseId;
  final String expenseNo;
  final int? categoryId;
  final String? categoryName;
  final String title;
  final String? description;
  final double amount;
  final DateTime expenseDate;
  final String paymentMode;
  final String? billNo;
  final String? vendorName;
  final String? enteredByName;
  final DateTime? createdAt;

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        expenseId: _asInt(j['expenseId']),
        expenseNo: _asString(j['expenseNo']),
        categoryId: _asIntN(j['categoryId']),
        categoryName: _asStringN(j['categoryName']),
        title: _asString(j['title']),
        description: _asStringN(j['description']),
        amount: _asDouble(j['amount']),
        expenseDate: DateTime.tryParse(_asString(j['expenseDate'])) ?? DateTime.now(),
        paymentMode: j['paymentMode'] == null ? 'Cash' : _asString(j['paymentMode']),
        billNo: _asStringN(j['billNo']),
        vendorName: _asStringN(j['vendorName']),
        enteredByName: _asStringN(j['enteredByName']),
        createdAt: j['createdAt'] == null ? null : DateTime.tryParse(_asString(j['createdAt'])),
      );

  Map<String, dynamic> toSaveJson() => {
        'expenseId': expenseId,
        'categoryId': categoryId,
        'title': title,
        'description': description,
        'amount': amount,
        'expenseDate': expenseDate.toIso8601String(),
        'paymentMode': paymentMode,
        'billNo': billNo,
        'vendorName': vendorName,
      };
}
