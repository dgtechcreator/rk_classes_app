import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/expense.dart';
import '../../models/lookup.dart';
import '../../services/expense_service.dart';
import '../../services/lookup_service.dart';
import '../../services/teacher_payment_service.dart';
import '../teacher_payment/teacher_payment_form_sheet.dart';
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
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Expense> _expenses = [];
  List<LookupItem> _categories = [];
  List<ExpenseCategoryTotal> _byCategory = [];
  int _total = 0, _page = 1, _totalPages = 1;
  double _totalAmount = 0;
  int? _categoryId;

  // Period: a calendar month (default = this month), a custom range, or everything.
  String _mode = 'month';
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTimeRange? _range;

  final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  DateTime get _thisMonth => DateTime(DateTime.now().year, DateTime.now().month);
  bool get _isThisMonth => _mode == 'month' && _month == _thisMonth;
  bool get _isLastMonth => _mode == 'month' && _month == DateTime(_thisMonth.year, _thisMonth.month - 1);
  bool get _isThisYear => _mode == 'range' && _range != null && _range!.start == DateTime(DateTime.now().year, 1, 1);

  String get _label => switch (_mode) {
        'all' => 'All time',
        'range' => _range == null ? 'Custom range' : '${DateFormat('dd MMM yyyy').format(_range!.start)} – ${DateFormat('dd MMM yyyy').format(_range!.end)}',
        _ => DateFormat('MMMM yyyy').format(_month),
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getAll(
        page: _page,
        categoryId: _categoryId,
        search: _searchCtrl.text.trim(),
        all: _mode == 'all',
        from: _mode == 'range' ? _range?.start : null,
        to: _mode == 'range' ? _range?.end : null,
        month: _mode == 'month' ? _month : null,
      );
      if (mounted) {
        setState(() {
          _expenses = result.expenses;
          _categories = result.categories;
          _byCategory = result.byCategory;
          _totalAmount = result.totalAmount;
          _total = result.total;
          _totalPages = result.totalPages;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _setPeriod(String mode, {DateTime? month, DateTimeRange? range}) {
    setState(() {
      _mode = mode;
      if (month != null) _month = DateTime(month.year, month.month);
      if (range != null) _range = range;
      _page = 1;
    });
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range ?? DateTimeRange(start: _thisMonth, end: DateTime(now.year, now.month, now.day)),
      helpText: 'Expenses from – to',
    );
    if (picked != null) _setPeriod('range', range: picked);
  }

  Future<void> _openForm({Expense? expense}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseFormSheet(service: _service, categories: _categories.where((c) => c.id > 0).toList(), expense: expense),
    );
    if (saved == true) _load();
  }

  final _salarySvc = TeacherPaymentService();

  /// A salary row of the list is a teacher payment: edit / delete it in the Teacher Payment form.
  Future<void> _editSalary(Expense e) async {
    try {
      final p = await withLoader(context, () => _salarySvc.getOne(e.expenseId));
      if (!mounted) return;
      if (await editTeacherPayment(context, _salarySvc, p) && mounted) _load();
    } on ApiException catch (err) {
      if (mounted) showSnack(context, err.message, isError: true);
    }
  }

  Future<void> _deleteSalary(Expense e) async {
    try {
      final p = await withLoader(context, () => _salarySvc.getOne(e.expenseId));
      if (!mounted) return;
      if (await deleteTeacherPayment(context, _salarySvc, p) && mounted) _load();
    } on ApiException catch (err) {
      if (mounted) showSnack(context, err.message, isError: true);
    }
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
      if (!mounted) return;
      await withLoader(context, () => _service.delete(e.expenseId));
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
    final canSalary = session.isAdmin || session.hasPerm('teacher_payment');
    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses${_total > 0 ? ' ($_total)' : ''}'),
        actions: [
          IconButton(icon: Icon(Icons.date_range_outlined, color: _mode == 'range' ? AppColors.primary : null), tooltip: 'Custom date range', onPressed: _pickRange),
          PopupMenuButton<int>(
            icon: Icon(Icons.filter_list, color: _categoryId != null ? AppColors.primary : null),
            tooltip: 'Category',
            onSelected: (v) { setState(() { _categoryId = v == 0 ? null : v; _page = 1; }); _load(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 0, child: Text('All Categories')),
              ..._categories.map((c) => PopupMenuItem(value: c.id, child: Text(c.name))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _periodBar(),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _buildBody(canEdit, canSalary),
          ),
        ],
      ),
      floatingActionButton: canEdit ? FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)) : null,
    );
  }

  /// Month navigation (previous / next month), quick ranges and search.
  Widget _periodBar() {
    Widget chip(String text, bool on, VoidCallback tap) =>
        Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(text), selected: on, onSelected: (_) => tap()));
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous month',
                onPressed: () => _setPeriod('month', month: DateTime((_mode == 'month' ? _month : _thisMonth).year, (_mode == 'month' ? _month : _thisMonth).month - 1)),
              ),
              Expanded(child: Center(child: Text(_label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), textAlign: TextAlign.center))),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next month',
                onPressed: _mode == 'month' && _month.isBefore(_thisMonth) ? () => _setPeriod('month', month: DateTime(_month.year, _month.month + 1)) : null,
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              chip('This month', _isThisMonth, () => _setPeriod('month', month: _thisMonth)),
              chip('Last month', _isLastMonth, () => _setPeriod('month', month: DateTime(_thisMonth.year, _thisMonth.month - 1))),
              chip('This year', _isThisYear, () => _setPeriod('range', range: DateTimeRange(start: DateTime(DateTime.now().year, 1, 1), end: DateTime.now()))),
              chip('All time', _mode == 'all', () => _setPeriod('all')),
            ]),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) { _page = 1; _load(); },
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search title, vendor…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _searchCtrl.clear(); _page = 1; _load(); }),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final catName = _categoryId == null ? null : _categories.where((c) => c.id == _categoryId).map((c) => c.name).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total · $_label${catName == null ? '' : ' · $catName'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(_fmt.format(_totalAmount), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.danger)),
        Text('$_total record${_total == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (_byCategory.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in _byCategory)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: (c.category == 'Teacher Salary' ? AppColors.infoSoft : AppColors.violetSoft),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text('${c.category}: ${_fmt.format(c.amount)} (${c.count})',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.category == 'Teacher Salary' ? AppColors.info : AppColors.violet)),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildBody(bool canEdit, bool canSalary) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _summary(),
          const SizedBox(height: 10),
          if (_expenses.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 30), child: EmptyState(message: 'No expenses found for this period.', icon: Icons.request_quote_outlined))
          else
            ..._expenses.map((e) => Card(
                  child: ListTile(
                    onTap: e.isSalary ? (canSalary ? () => _editSalary(e) : null) : (canEdit ? () => _openForm(expense: e) : null),
                    leading: e.isSalary ? const CircleAvatar(radius: 18, backgroundColor: AppColors.infoSoft, child: Icon(Icons.badge_outlined, size: 18, color: AppColors.info)) : null,
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
                        if (e.isSalary ? canSalary : canEdit) IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), tooltip: 'Delete', onPressed: () => e.isSalary ? _deleteSalary(e) : _delete(e)),
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

  List<String> _modes = defaultPaymentModes;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.expense?.categoryId;
    _mode = widget.expense?.paymentMode ?? 'Cash';
    // the modes come from Masters -> Payment Modes (an old / switched-off mode of this record stays selectable)
    loadPaymentModes().then((m) {
      if (mounted) setState(() => _modes = m.contains(_mode) ? m : [...m, _mode]);
    });
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
      padding: EdgeInsets.only(bottom: sheetBottomInset(context)),
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
      isExpanded: true,
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
      isExpanded: true,
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
