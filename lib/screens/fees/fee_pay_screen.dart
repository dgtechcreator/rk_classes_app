import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/fees_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

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

  Future<void> _openCollectSheet() async {
    final info = _info;
    if (info == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CollectPaymentSheet(service: _service, studentId: widget.studentId, balance: info.balance),
    );
    if (saved == true) _load();
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
              Expanded(child: StatCard(label: 'Total Fee', value: _fmt.format(info.actualFee), color: AppColors.info, icon: Icons.receipt_long_outlined)),
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
          if (info.dueDate != null) ...[
            const SizedBox(height: 8),
            Text('Due date: ${DateFormat.yMMMd().format(info.dueDate!)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          const SectionHeader(title: 'Fee Structure'),
          if (info.feeStructures.isEmpty)
            const EmptyState(message: 'No fee structure configured for this student\'s class.', icon: Icons.receipt_long_outlined)
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
      await widget.service.savePay(
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
        Navigator.of(context).pop(true);
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
