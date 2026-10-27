import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/fees_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'receipt_screen.dart';

/// A student's fee status + collect-payment flow — mirrors FeesController.Pay. Shows fee structure
/// breakdown, running balance and payment history, with a bottom-sheet form to record a new payment.
class FeePayScreen extends StatefulWidget {
  const FeePayScreen({super.key, required this.studentId, required this.studentName});
  final int studentId;
  final String studentName;

  @override
  State<FeePayScreen> createState() => _FeePayScreenState();
}

class _FeePayScreenState extends State<FeePayScreen> {
  final _service = FeesService();
  bool _loading = true;
  String? _error;
  FeePayInfo? _info;

  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final info = await _service.getPayInfo(widget.studentId);
      if (mounted) setState(() { _info = info; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  /// Dues of EARLIER years (9th / 10th / 11th...) that were never in the system: staff types the amount once.
  Future<void> _editPreviousDues() async {
    final info = _info;
    if (info == null) return;
    final amount = TextEditingController(text: info.previousDuesAmount > 0 ? info.previousDuesAmount.toStringAsFixed(0) : '');
    final note = TextEditingController(text: info.previousDuesNote ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Previous years' dues"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fees of earlier years that are still unpaid. Added to this student\'s fee, balance and all Finance totals (parents see it too). Enter 0 to clear.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ ')),
            const SizedBox(height: 10),
            TextField(controller: note, maxLength: 500, decoration: const InputDecoration(labelText: 'Note (which years / classes)', counterText: '', hintText: 'e.g. 9th 10000 + 10th 12000')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final value = double.tryParse(amount.text.trim().isEmpty ? '0' : amount.text.trim());
    amount.dispose();
    final text = note.text;
    note.dispose();
    if (saved != true) return;
    if (value == null || value < 0) return showSnack(context, 'Enter a valid amount.', isError: true);
    try {
      await _service.setPreviousDues(widget.studentId, value, text);
      if (mounted) showSnack(context, value > 0 ? 'Previous dues saved.' : 'Previous dues cleared.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _openCollectSheet() async {
    final info = _info;
    if (info == null) return;
    // The sheet returns the new payment's id (0 if the server didn't send one); null = cancelled.
    final savedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CollectPaymentSheet(service: _service, studentId: widget.studentId, balance: info.balance),
    );
    if (savedId == null) return;
    await _load();
    if (!mounted) return;
    final p = _info?.paymentHistory.where((x) => x.paymentId == savedId).firstOrNull ?? _info?.paymentHistory.firstOrNull;
    if (p == null) return;
    final view = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment recorded'),
        content: Text('${_fmt.format(p.netAmount)} received · ${p.receiptNo}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.receipt_long_outlined, size: 18), label: const Text('View Receipt')),
        ],
      ),
    );
    if (view == true && mounted) await ReceiptScreen.open(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canCollect = session.isAdmin || session.hasPerm('fee_collect');
    return Scaffold(
      appBar: AppBar(title: Text(widget.studentName)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
      floatingActionButton: (!_loading && _error == null && canCollect)
          ? FloatingActionButton.extended(onPressed: _openCollectSheet, icon: const Icon(Icons.payments_outlined), label: const Text('Collect'))
          : null,
    );
  }

  Widget _buildBody() {
    final info = _info!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            children: [
              Expanded(child: StatCard(label: 'Total Fee', value: _fmt.format(info.netTotal), color: AppColors.info, icon: Icons.receipt_long_outlined)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Paid', value: _fmt.format(info.totalPaid), color: AppColors.success, icon: Icons.check_circle_outline)),
            ],
          ),
          const SizedBox(height: 12),
          StatCard(
            label: 'Balance', value: _fmt.format(info.balance),
            color: info.balance > 0 ? AppColors.warning : AppColors.success,
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _editPreviousDues,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 20, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.previousDuesAmount > 0 ? "Previous years' dues: ${_fmt.format(info.previousDuesAmount)}" : "Previous years' dues: not entered",
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.danger),
                        ),
                        if ((info.previousDuesNote ?? '').isNotEmpty)
                          Text(info.previousDuesNote!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (info.previousDuesAt != null)
                          Text('Set by ${info.previousDuesBy ?? '—'} · ${DateFormat('d MMM yyyy, h:mm a').format(info.previousDuesAt!)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 18, color: AppColors.danger),
                ],
              ),
            ),
          ),
          if (info.previousDue > 0.5) ...[
            const SizedBox(height: 8),
            Text('Includes ${_fmt.format(info.previousDue)} still due from earlier years',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
          ],
          if (info.additionalCharges > 0 || info.existingDiscount > 0) ...[
            const SizedBox(height: 8),
            Text(
              [
                'Fee ${_fmt.format(info.actualFee)}',
                if (info.additionalCharges > 0) '+ charges ${_fmt.format(info.additionalCharges)}',
                if (info.existingDiscount > 0) '− discount ${_fmt.format(info.existingDiscount)}',
              ].join(' '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          if (info.agreedDiscount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Agreed discount ${_fmt.format(info.agreedDiscount)}${(info.agreedDiscountReason ?? '').trim().isEmpty ? '' : ' - ${info.agreedDiscountReason}'} (included above)',
              style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (info.dueDate != null) ...[
            const SizedBox(height: 8),
            Text('Due date: ${DateFormat.yMMMd().format(info.dueDate!)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          const SectionHeader(title: 'Fee Structure'),
          if (info.feeStructures.isEmpty)
            const EmptyState(message: 'Fee is not set for this student - add the fee head for this class / medium in Fee Setup (see Data Health on the web).', icon: Icons.receipt_long_outlined)
          else
            ...info.feeStructures.map((fs) => Card(
                  child: ListTile(
                    title: Text(fs.feeTypeName ?? 'Fee'),
                    subtitle: Text(fs.isMonthly ? 'Monthly • due day ${fs.dueDay}' : 'One-time'),
                    trailing: Text(_fmt.format(fs.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Payment History'),
          if (info.paymentHistory.isEmpty)
            const EmptyState(message: 'No payments recorded yet.', icon: Icons.history)
          else
            ...info.paymentHistory.map((p) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(Icons.check, color: AppColors.primary, size: 18)),
                    title: Text(_fmt.format(p.netAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${p.receiptNo} • ${DateFormat.yMMMd().format(p.paymentDate)} • ${p.paymentMode}'),
                    trailing: IconButton(
                      tooltip: 'Receipt',
                      icon: const Icon(Icons.receipt_long_outlined, color: AppColors.info),
                      onPressed: () => ReceiptScreen.open(context, p),
                    ),
                    onTap: () => ReceiptScreen.open(context, p),
                  ),
                )),
        ],
      ),
    );
  }
}

class _CollectPaymentSheet extends StatefulWidget {
  const _CollectPaymentSheet({required this.service, required this.studentId, required this.balance});
  final FeesService service;
  final int studentId;
  final double balance;

  @override
  State<_CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends State<_CollectPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountCtrl = TextEditingController(text: widget.balance > 0 ? widget.balance.toStringAsFixed(0) : '');
  final _discountCtrl = TextEditingController(text: '0');
  final _chargesCtrl = TextEditingController(text: '0');
  final _refCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _mode = 'Cash';
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _modes = ['Cash', 'Online Transfer', 'Cheque', 'Demand Draft'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _discountCtrl.dispose();
    _chargesCtrl.dispose();
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final newId = await widget.service.savePay(
        studentId: widget.studentId,
        payingNow: double.parse(_amountCtrl.text.trim()),
        additionalDiscount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
        additionalCharges: double.tryParse(_chargesCtrl.text.trim()) ?? 0,
        paymentDate: _date,
        paymentMode: _mode,
        transactionRef: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      );
      if (mounted) {
        showSnack(context, 'Payment recorded.');
        Navigator.of(context).pop(newId);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save payment. Please try again.', isError: true);
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
                const Text('Collect Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _discountCtrl, decoration: const InputDecoration(labelText: 'Discount', prefixText: '₹ '), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _chargesCtrl, decoration: const InputDecoration(labelText: 'Late Fine', prefixText: '₹ '), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
      isExpanded: true,
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _mode = v ?? _mode),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Transaction Ref (UTR / Cheque No.)')),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Payment Date: ${DateFormat.yMMMd().format(_date)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks'), maxLines: 2),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Payment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
