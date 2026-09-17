import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/expense.dart';
import '../../models/lookup.dart';
import '../../services/expense_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Expense list with filters + add/edit/delete — mirrors ExpensesController.Index.
class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _service = ExpenseService();
  bool _loading = true;
  String? _error;
  List<Expense> _expenses = [];
  List<LookupItem> _categories = [];
  int _total = 0, _page = 1, _totalPages = 1;
  int? _categoryId;

  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getAll(page: _page, categoryId: _categoryId);
      if (mounted) {
        setState(() {
          _expenses = result.expenses;
          _categories = result.categories;
          _total = result.total;
          _totalPages = result.totalPages;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _openForm({Expense? expense}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseFormSheet(service: _service, categories: _categories, expense: expense),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Expense e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Remove "${e.title}" (${_fmt.format(e.amount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(e.expenseId);
      if (mounted) { showSnack(context, 'Expense deleted.'); _load(); }
    } on ApiException catch (e2) {
      if (mounted) showSnack(context, e2.message, isError: true);
    } catch (e2) {
      if (mounted) showSnack(context, 'Could not delete expense. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasEditPerm('expenses');
    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses${_total > 0 ? ' ($_total)' : ''}'),
        actions: [
          PopupMenuButton<int?>(
            icon: Icon(Icons.filter_list, color: _categoryId != null ? AppColors.primary : null),
            onSelected: (v) { setState(() { _categoryId = v; _page = 1; }); _load(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All Categories')),
              ..._categories.map((c) => PopupMenuItem(value: c.id, child: Text(c.name))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(canEdit),
      floatingActionButton: canEdit ? FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)) : null,
    );
  }

  Widget _buildBody(bool canEdit) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_expenses.isEmpty)
            const EmptyState(message: 'No expenses found.', icon: Icons.request_quote_outlined)
          else
            ..._expenses.map((e) => Card(
                  child: ListTile(
                    onTap: canEdit ? () => _openForm(expense: e) : null,
                    title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if ((e.categoryName ?? '').isNotEmpty) e.categoryName!,
                      DateFormat.yMMMd().format(e.expenseDate),
                      e.paymentMode,
                    ].join(' • ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_fmt.format(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (canEdit) IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _delete(e)),
                      ],
                    ),
                  ),
                )),
          if (_totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null),
                Text('Page $_page of $_totalPages'),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: _page < _totalPages ? () { setState(() => _page++); _load(); } : null),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({required this.service, required this.categories, this.expense});
  final ExpenseService service;
  final List<LookupItem> categories;
  final Expense? expense;

  bool get isEdit => expense != null;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _titleCtrl = TextEditingController(text: widget.expense?.title ?? '');
  late final _descCtrl = TextEditingController(text: widget.expense?.description ?? '');
  late final _amountCtrl = TextEditingController(text: widget.expense == null ? '' : widget.expense!.amount.toStringAsFixed(0));
  late final _billCtrl = TextEditingController(text: widget.expense?.billNo ?? '');
  late final _vendorCtrl = TextEditingController(text: widget.expense?.vendorName ?? '');
  int? _categoryId;
  String _mode = 'Cash';
  late DateTime _date = widget.expense?.expenseDate ?? DateTime.now();
  bool _saving = false;

  static const _modes = ['Cash', 'Online Transfer', 'Cheque', 'Card'];

  @override
  void initState() {
    super.initState();
    _categoryId = widget.expense?.categoryId;
    _mode = widget.expense?.paymentMode ?? 'Cash';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _billCtrl.dispose();
    _vendorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final e = Expense(
        expenseId: widget.expense?.expenseId ?? 0,
        categoryId: _categoryId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text.trim()),
        expenseDate: _date,
        paymentMode: _mode,
        billNo: _billCtrl.text.trim(),
        vendorName: _vendorCtrl.text.trim(),
      );
      await widget.service.save(e.toSaveJson());
      if (mounted) { showSnack(context, widget.isEdit ? 'Expense updated.' : 'Expense added.'); Navigator.of(context).pop(true); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save expense. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.isEdit ? 'Edit Expense' : 'Add Expense', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: widget.categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: widget.categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0 ? 'Enter a valid amount' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _mode = v ?? _mode),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${DateFormat.yMMMd().format(_date)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _vendorCtrl, decoration: const InputDecoration(labelText: 'Vendor Name')),
                const SizedBox(height: 12),
                TextFormField(controller: _billCtrl, decoration: const InputDecoration(labelText: 'Bill No.')),
                const SizedBox(height: 12),
                TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
