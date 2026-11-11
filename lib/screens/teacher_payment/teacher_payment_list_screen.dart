import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/lookup.dart';
import '../../models/teacher_payment.dart';
import '../../services/lookup_service.dart';
import '../../services/teacher_payment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'teacher_payment_form_sheet.dart';
import 'teacher_payment_summary_screen.dart';

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
      builder: (_) => TeacherPaymentFormSheet(service: _service, faculty: data.allFaculty, facultyPay: data.facultyPay, currentMonth: data.currentMonth, currentYear: data.currentYear),
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
      if (!mounted) return;
      await withLoader(context, () => _service.markAsPaid(paymentId: p.teacherPaymentId, paymentMode: result['mode'], transactionRef: result['ref']));
      if (mounted) { showSnack(context, 'Marked as paid.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not update payment. Please try again.', isError: true);
    }
  }

  Future<void> _deletePayment(TeacherPayment p) async {
    if (await deleteTeacherPayment(context, _service, p) && mounted) _load();
  }

  Future<void> _editPayment(TeacherPayment p) async {
    if (await editTeacherPayment(context, _service, p) && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasPerm('teacher_payment');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Payment'),
        actions: [
          IconButton(
            tooltip: 'Summary',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeacherPaymentSummaryScreen())),
          ),
        ],
      ),
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
            ...data.unpaidPayments.map((p) => _PaymentTile(payment: p, canEdit: canEdit, onMarkPaid: () => _markPaid(p), onEdit: () => _editPayment(p), onDelete: () => _deletePayment(p))),
          const SizedBox(height: 20),
          SectionHeader(title: 'This Month (${data.monthlyPayments.length})'),
          if (data.monthlyPayments.isEmpty)
            const EmptyState(message: 'No payments recorded this month.', icon: Icons.currency_rupee)
          else
            ...data.monthlyPayments.map((p) => _PaymentTile(payment: p, canEdit: canEdit, onMarkPaid: p.isPaid ? null : () => _markPaid(p), onEdit: () => _editPayment(p), onDelete: () => _deletePayment(p))),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.canEdit, this.onMarkPaid, required this.onEdit, required this.onDelete});
  final TeacherPayment payment;
  final bool canEdit;
  final VoidCallback? onMarkPaid;
  final VoidCallback onEdit;
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
              IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.info), tooltip: 'Edit', onPressed: onEdit),
              IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), tooltip: 'Delete', onPressed: onDelete),
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
  List<String> _modes = defaultPaymentModes;

  @override
  void initState() {
    super.initState();
    loadPaymentModes().then((m) {
      if (mounted) setState(() { _modes = m; if (!m.contains(_mode)) _mode = m.first; });
    });
  }

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
      isExpanded: true,
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
