import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/student.dart';
import '../../services/fees_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// What staff typed in a receipt's remarks (the "Additional Charges: ₹x" part is kept by the server and edited
/// from the Collect screen, so it is hidden here).
String remarksWithoutCharges(String? remarks) => (remarks ?? '')
    .split('|')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty && !e.contains('Additional Charges:'))
    .join(' | ');

/// Bottom sheet that corrects a saved receipt in place (same receipt no., no new receipt is created).
/// Returns true when the receipt was changed.
Future<bool?> showReceiptEditSheet(BuildContext context, FeePayment payment, {required bool discountLocked}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiptEditSheet(payment: payment, discountLocked: discountLocked),
    );

class _ReceiptEditSheet extends StatefulWidget {
  const _ReceiptEditSheet({required this.payment, required this.discountLocked});
  final FeePayment payment;
  final bool discountLocked;

  @override
  State<_ReceiptEditSheet> createState() => _ReceiptEditSheetState();
}

class _ReceiptEditSheetState extends State<_ReceiptEditSheet> {
  static const _modes = ['Cash', 'Online Transfer', 'Cheque', 'Demand Draft'];
  final _service = FeesService();

  late final _amount = TextEditingController(text: _num(widget.payment.netAmount));
  late final _discount = TextEditingController(text: _num(widget.payment.discount));
  late final _ref = TextEditingController(text: widget.payment.transactionRef ?? '');
  late final _remarks = TextEditingController(text: remarksWithoutCharges(widget.payment.remarks));
  late DateTime _date = DateUtils.dateOnly(widget.payment.paymentDate);
  late DateTime? _due = widget.payment.dueDate == null ? null : DateUtils.dateOnly(widget.payment.dueDate!);
  late String _mode = widget.payment.paymentMode.trim().isEmpty ? 'Cash' : widget.payment.paymentMode;
  bool _saving = false;

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _amount.dispose();
    _discount.dispose();
    _ref.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _pick(bool due) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: (due ? _due : _date) ?? now,
      firstDate: DateTime(2020),
      lastDate: due ? DateTime(now.year + 2) : now,
      helpText: due ? 'Due date' : 'Payment date',
    );
    if (picked != null) setState(() => due ? _due = picked : _date = picked);
  }

  Future<void> _save() async {
    final paid = double.tryParse(_amount.text.trim());
    final disc = double.tryParse(_discount.text.trim().isEmpty ? '0' : _discount.text.trim());
    if (paid == null || paid <= 0) return showSnack(context, 'Enter the amount received.', isError: true);
    if (disc == null || disc < 0) return showSnack(context, 'Enter a valid discount.', isError: true);
    setState(() => _saving = true);
    try {
      await _service.updatePayment(
        widget.payment.paymentId,
        paidAmount: paid,
        discount: disc,
        paymentDate: _date,
        dueDate: _due,
        paymentMode: _mode,
        transactionRef: _ref.text,
        remarks: _remarks.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final modes = {..._modes, _mode}.toList();
    final fmt = DateFormat('d MMM yyyy');
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit receipt ${widget.payment.receiptNo}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Changes this receipt only - no new receipt is made.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount received (₹)', prefixText: '₹ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _discount,
              enabled: !widget.discountLocked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Discount on this receipt (₹)',
                prefixText: '₹ ',
                helperText: widget.discountLocked ? 'Discount was given on another receipt of this student - locked.' : null,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('Paid ${fmt.format(_date)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: Text(_due == null ? 'Due date' : 'Due ${fmt.format(_due!)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Payment mode'),
              items: [for (final m in modes) DropdownMenuItem(value: m, child: Text(m))],
              onChanged: (v) => setState(() => _mode = v ?? _mode),
            ),
            const SizedBox(height: 10),
            TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Transaction ref (UTR / cheque no.)')),
            const SizedBox(height: 10),
            TextField(controller: _remarks, maxLength: 250, decoration: const InputDecoration(labelText: 'Remarks', counterText: '')),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel'))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
