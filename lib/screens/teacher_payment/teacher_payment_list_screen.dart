import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/lookup.dart';
import '../../models/teacher_payment.dart';
import '../../services/teacher_payment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Teacher payment dues + this month's payments — mirrors TeacherPaymentController.Index. The API only
/// ever returns all-time unpaid dues plus the current month's payments (see service doc comment), so
/// this screen doesn't offer a month picker — it shows exactly what the backend gives it.
class TeacherPaymentListScreen extends StatefulWidget {
  const TeacherPaymentListScreen({super.key});

  @override
  State<TeacherPaymentListScreen> createState() => _TeacherPaymentListScreenState();
}

class _TeacherPaymentListScreenState extends State<TeacherPaymentListScreen> {
  final _service = TeacherPaymentService();
  bool _loading = true;
  String? _error;
  TeacherPaymentIndexData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getIndex();
      if (mounted) setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _openAddSheet() async {
    final data = _data;
    if (data == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPaymentSheet(service: _service, faculty: data.allFaculty, currentMonth: data.currentMonth, currentYear: data.currentYear),
    );
    if (saved == true) _load();
  }

  Future<void> _markPaid(TeacherPayment p) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _MarkPaidDialog(payment: p),
    );
    if (result == null) return;
    try {
      await _service.markAsPaid(paymentId: p.teacherPaymentId, paymentMode: result['mode'], transactionRef: result['ref']);
      if (mounted) { showSnack(context, 'Marked as paid.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not update payment. Please try again.', isError: true);
    }
  }

  Future<void> _deletePayment(TeacherPayment p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Remove this ${p.typeLabel} payment for ${p.facultyName} (${p.monthYearLabel})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(p.teacherPaymentId);
      if (mounted) { showSnack(context, 'Payment deleted.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not delete payment. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasPerm('teacher_payment');
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Payment')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(canEdit),
      floatingActionButton: (!_loading && _error == null && canEdit)
          ? FloatingActionButton(onPressed: _openAddSheet, child: const Icon(Icons.add))
          : null,
    );
  }

  Widget _buildBody(bool canEdit) {
    final data = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SectionHeader(title: 'Unpaid Dues (${data.unpaidPayments.length})'),
          if (data.unpaidPayments.isEmpty)
            const EmptyState(message: 'No unpaid dues.', icon: Icons.check_circle_outline)
          else
            ...data.unpaidPayments.map((p) => _PaymentTile(payment: p, canEdit: canEdit, onMarkPaid: () => _markPaid(p), onDelete: () => _deletePayment(p))),
          const SizedBox(height: 20),
          SectionHeader(title: 'This Month (${data.monthlyPayments.length})'),
          if (data.monthlyPayments.isEmpty)
            const EmptyState(message: 'No payments recorded this month.', icon: Icons.currency_rupee)
          else
            ...data.monthlyPayments.map((p) => _PaymentTile(payment: p, canEdit: canEdit, onMarkPaid: p.isPaid ? null : () => _markPaid(p), onDelete: () => _deletePayment(p))),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.canEdit, this.onMarkPaid, required this.onDelete});
  final TeacherPayment payment;
  final bool canEdit;
  final VoidCallback? onMarkPaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Text(payment.facultyName.isNotEmpty ? payment.facultyName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text(payment.facultyName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${payment.typeLabel} • ${payment.monthYearLabel}'),
        isThreeLine: false,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${payment.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                StatusBadge(status: payment.statusLabel),
              ],
            ),
            if (canEdit) ...[
              if (onMarkPaid != null)
                IconButton(icon: const Icon(Icons.check_circle_outline, color: AppColors.success), tooltip: 'Mark as paid', onPressed: onMarkPaid),
              IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: onDelete),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkPaidDialog extends StatefulWidget {
  const _MarkPaidDialog({required this.payment});
  final TeacherPayment payment;

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  String _mode = 'Cash';
  final _refCtrl = TextEditingController();
  static const _modes = ['Cash', 'Online Transfer', 'Cheque'];

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mark ${widget.payment.facultyName} as paid'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Payment Mode'),
            items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => _mode = v ?? _mode),
          ),
          const SizedBox(height: 12),
          TextField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Transaction Ref (optional)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {'mode': _mode, 'ref': _refCtrl.text.trim()}),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _AddPaymentSheet extends StatefulWidget {
  const _AddPaymentSheet({required this.service, required this.faculty, required this.currentMonth, required this.currentYear});
  final TeacherPaymentService service;
  final List<LookupItem> faculty;
  final int currentMonth;
  final int currentYear;

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  int? _facultyId;
  String _type = 'Fixed';
  final _rateCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  late int _month = widget.currentMonth;
  late int _year = widget.currentYear;
  bool _saving = false;

  static const _types = ['Fixed', 'Hourly', 'Topic'];
  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void dispose() {
    _rateCtrl.dispose();
    _quantityCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_facultyId == null) { showSnack(context, 'Select a faculty member.', isError: true); return; }
    setState(() => _saving = true);
    try {
      await widget.service.save(
        facultyId: _facultyId!,
        paymentType: _type,
        rate: double.parse(_rateCtrl.text.trim()),
        quantity: _type == 'Fixed' ? null : double.tryParse(_quantityCtrl.text.trim()),
        paymentMonth: _month,
        paymentYear: _year,
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      );
      if (mounted) { showSnack(context, 'Payment added.'); Navigator.of(context).pop(true); }
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
                const Text('Add Teacher Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _facultyId,
                  decoration: const InputDecoration(labelText: 'Faculty *'),
                  items: widget.faculty.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _facultyId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Payment Type'),
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rateCtrl,
                      decoration: InputDecoration(labelText: _type == 'Fixed' ? 'Amount *' : 'Rate *', prefixText: '₹ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0 ? 'Required' : null,
                    ),
                  ),
                  if (_type != 'Fixed') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityCtrl,
                        decoration: InputDecoration(labelText: _type == 'Hourly' ? 'Hours' : 'Topics'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i]))),
                      onChanged: (v) => setState(() => _month = v ?? _month),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: [widget.currentYear - 1, widget.currentYear, widget.currentYear + 1].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                      onChanged: (v) => setState(() => _year = v ?? _year),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks'), maxLines: 2),
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
