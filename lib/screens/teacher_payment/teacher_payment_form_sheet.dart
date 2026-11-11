import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../models/teacher_payment.dart';
import '../../services/lookup_service.dart';
import '../../services/teacher_payment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Add a teacher payment entry, or EDIT an existing one (pending or paid) - same fields as the website's Edit page.
/// A paid entry also lets you correct the payment mode (from the Masters list), reference and paid date.
class TeacherPaymentFormSheet extends StatefulWidget {
  const TeacherPaymentFormSheet({super.key, required this.service, this.faculty = const [], this.facultyPay = const {}, required this.currentMonth, required this.currentYear, this.existing});
  final TeacherPaymentService service;
  final List<LookupItem> faculty;
  /// facultyId -> (salary type, rate) from the Faculty form: choosing a teacher fills the type and rate.
  final Map<int, ({String type, double? rate})> facultyPay;
  final int currentMonth;
  final int currentYear;
  final TeacherPayment? existing;

  bool get isEdit => existing != null;

  @override
  State<TeacherPaymentFormSheet> createState() => _TeacherPaymentFormSheetState();
}

class _TeacherPaymentFormSheetState extends State<TeacherPaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  int? _facultyId;
  late String _type = widget.existing?.paymentType.isNotEmpty == true ? widget.existing!.paymentType : 'Fixed';
  late final _rateCtrl = TextEditingController(text: widget.existing == null ? '' : _trim(widget.existing!.rate));
  late final _quantityCtrl = TextEditingController(text: widget.existing?.quantity == null ? '' : _trim(widget.existing!.quantity!));
  late final _remarksCtrl = TextEditingController(text: widget.existing?.remarks ?? '');
  late final _refCtrl = TextEditingController(text: widget.existing?.transactionRef ?? '');
  late int _month = widget.existing?.paymentMonth ?? widget.currentMonth;
  late int _year = widget.existing?.paymentYear ?? widget.currentYear;
  DateTime? _paidOn;
  String? _mode;
  List<String> _modes = defaultPaymentModes;
  bool _saving = false;

  static const _types = ['Fixed', 'Hourly', 'Topic'];
  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _trim(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    _facultyId = widget.existing?.facultyId;
    _paidOn = widget.existing?.paymentDate;
    _mode = widget.existing?.paymentMode;
    loadPaymentModes().then((m) {
      if (!mounted) return;
      final cur = _mode;
      setState(() => _modes = cur != null && cur.isNotEmpty && !m.contains(cur) ? [...m, cur] : m);
    });
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _quantityCtrl.dispose();
    _remarksCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_facultyId == null) { showSnack(context, 'Select a faculty member.', isError: true); return; }
    setState(() => _saving = true);
    try {
      final rate = double.parse(_rateCtrl.text.trim());
      final qty = _type == 'Fixed' ? null : double.tryParse(_quantityCtrl.text.trim());
      final remarks = _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim();
      if (widget.isEdit) {
        await widget.service.update(
          paymentId: widget.existing!.teacherPaymentId, paymentType: _type, rate: rate, quantity: qty, paymentMonth: _month, paymentYear: _year, remarks: remarks,
          paymentMode: widget.existing!.isPaid ? _mode : null,
          transactionRef: widget.existing!.isPaid ? _refCtrl.text.trim() : null,
          paymentDate: widget.existing!.isPaid ? _paidOn : null,
        );
      } else {
        await widget.service.save(facultyId: _facultyId!, paymentType: _type, rate: rate, quantity: qty, paymentMonth: _month, paymentYear: _year, remarks: remarks);
      }
      if (mounted) { showSnack(context, widget.isEdit ? 'Payment updated.' : 'Payment added.'); Navigator.of(context).pop(true); }
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
    final years = {widget.currentYear - 1, widget.currentYear, widget.currentYear + 1, _year}.toList()..sort();
    final paid = widget.existing?.isPaid == true;
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
                Text(widget.isEdit ? 'Edit Teacher Payment' : 'Add Teacher Payment', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                if (widget.isEdit) Padding(padding: const EdgeInsets.only(top: 2), child: Text('${widget.existing!.facultyName}${paid ? ' · paid' : ' · pending'}', style: const TextStyle(color: AppColors.textSecondary))),
                const SizedBox(height: 16),
                if (!widget.isEdit) ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _facultyId,
                    decoration: const InputDecoration(labelText: 'Faculty *'),
                    items: widget.faculty.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() {
                      _facultyId = v;
                      final pay = v == null ? null : widget.facultyPay[v];
                      if (pay != null) {
                        _type = pay.type;
                        if (pay.rate != null && pay.rate! > 0) _rateCtrl.text = _trim(pay.rate!);
                      }
                    }),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  isExpanded: true,
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
                        decoration: InputDecoration(labelText: _type == 'Hourly' ? 'Hours *' : 'Topics *'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0 ? 'Required' : null,
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _month,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i]))),
                      onChanged: (v) => setState(() => _month = v ?? _month),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                      onChanged: (v) => setState(() => _year = v ?? _year),
                    ),
                  ),
                ]),
                if (paid) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _mode != null && _modes.contains(_mode) ? _mode : null,
                    decoration: const InputDecoration(labelText: 'Payment Mode'),
                    items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() => _mode = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Transaction Ref')),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Paid on: ${_paidOn == null ? '—' : DateFormat.yMMMd().format(_paidOn!)}'),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _paidOn ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (d != null) setState(() => _paidOn = d);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(controller: _remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks'), maxLines: 2),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.isEdit ? 'Save Changes' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Edit one entry in the same sheet from anywhere (Teacher Payment list, its Summary, the Expenses list). True when saved.
Future<bool> editTeacherPayment(BuildContext context, TeacherPaymentService service, TeacherPayment p) async {
  final now = DateTime.now();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TeacherPaymentFormSheet(service: service, currentMonth: now.month, currentYear: now.year, existing: p),
  );
  return saved == true;
}

/// Confirm + delete one entry (it also leaves the Expenses list; restore from Deleted Records). True when deleted.
Future<bool> deleteTeacherPayment(BuildContext context, TeacherPaymentService service, TeacherPayment p) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Payment'),
      content: Text('Remove this ${p.typeLabel} payment for ${p.facultyName} (${p.monthYearLabel})?${p.isPaid ? '\nIt is also removed from the Expenses list.' : ''}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await withLoader(context, () => service.delete(p.teacherPaymentId));
    if (context.mounted) showSnack(context, 'Payment deleted.');
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, isError: true);
  } catch (e) {
    if (context.mounted) showSnack(context, 'Could not delete payment. Please try again.', isError: true);
  }
  return false;
}
