import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/contact_number.dart';
import '../../models/student.dart';
import '../../services/fees_service.dart';
import '../../services/student_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/contact_actions.dart';
import '../fees/receipt_screen.dart';
import 'student_form_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});
  final int studentId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _service = StudentService();
  bool _loading = true;
  String? _error;
  StudentDetail? _detail;

  final _feesService = FeesService();
  FeePayInfo? _fees;
  String? _feesError;
  bool _feesLoading = false;
  bool _showAllPayments = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fee figures come from the same endpoint the Fees module uses (GET /api/fees/pay/{id}), so the
  /// profile can never disagree with the collection screen. Needs the fee_collection permission —
  /// without it the section is simply not shown.
  bool get _canSeeFees => context.read<Session>().hasPerm('fee_collection');

  Future<void> _loadFees() async {
    if (!_canSeeFees) return;
    setState(() { _feesLoading = true; _feesError = null; });
    try {
      final info = await _feesService.getPayInfo(widget.studentId);
      if (mounted) setState(() { _fees = info; _feesLoading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _feesError = e.message; _feesLoading = false; });
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await _service.getById(widget.studentId);
      if (!mounted) return;
      setState(() { _detail = detail; _loading = false; });
      _loadFees();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StudentFormScreen(student: _detail!.student)));
    if (saved == true) _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Move ${_detail!.student.displayName} to inactive/deleted records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(widget.studentId);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasEditPerm('student');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        actions: canEdit && _detail != null
            ? [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: _delete),
              ]
            : null,
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _detail == null
                  ? const EmptyState(message: 'Student not found.')
                  : _buildBody(_detail!),
    );
  }

  Widget _buildBody(StudentDetail detail) {
    final s = detail.student;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
              Row(
                children: [
                  CircleAvatar(radius: 32, backgroundColor: AppColors.primarySoft, child: Text(s.displayName.isNotEmpty ? s.displayName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(s.classLabel, style: const TextStyle(color: AppColors.textSecondary)),
                        Text('Admission No: ${s.admissionNo}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  StatusBadge(status: s.status),
                ],
              ),
              const SizedBox(height: 14),
              _contactButtons(s),
              ]),
            ),
          ),
          if (_canSeeFees) ...[
            const SizedBox(height: 16),
            _buildFeesSection(s),
          ],
          const SizedBox(height: 16),
          const SectionHeader(title: 'Details'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(children: [
                _row('Roll No', s.rollNo),
                _row('Gender', s.gender),
                _row('Date of Birth', s.dateOfBirth == null ? null : DateFormat.yMMMd().format(s.dateOfBirth!)),
                _row('Blood Group', s.bloodGroup),
                _row('Admission Date', s.admissionDate == null ? null : DateFormat.yMMMd().format(s.admissionDate!)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Contact'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(children: [
                _row('Student Phone', s.phone),
                _row("Father's Name", s.fatherName),
                _row("Father's Phone", s.fatherPhone),
                _row("Mother's Name", s.motherName),
                _row("Mother's Phone", s.motherPhone),
                _row('Email', s.email),
                _row('Address', s.address),
              ]),
            ),
          ),
          if (detail.fees.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'Fee Structure'),
            ...detail.fees.map((f) {
              final m = f as Map;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(m['feeTypeName']?.toString() ?? 'Fee'),
                  trailing: Text('₹${m['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<ContactNumber> _contactsOf(Student s) => buildContacts(father: s.fatherPhone, mother: s.motherPhone, student: s.phone);

  Map<String, String> _vars(Student s, {Map<String, String> extra = const {}}) =>
      ContactActions.baseVars(student: s.displayName, className: s.className, medium: s.sectionName, extra: extra);

  Widget _contactButtons(Student s) {
    final contacts = _contactsOf(s);
    final enabled = contacts.isNotEmpty;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? () => ContactActions.call(context, name: s.displayName, contacts: contacts) : null,
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.info, side: const BorderSide(color: AppColors.info), minimumSize: const Size.fromHeight(42)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: enabled
                    ? () => ContactActions.whatsapp(context, name: s.displayName, contacts: contacts, category: 'General', vars: _vars(s))
                    : null,
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('WhatsApp'),
                style: FilledButton.styleFrom(backgroundColor: whatsappGreen, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(42)),
              ),
            ),
          ],
        ),
        if (!enabled)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No valid phone number saved for this student.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
      ],
    );
  }

  Widget _buildFeesSection(Student s) {
    if (_feesLoading && _fees == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))));
    }
    if (_fees == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline, color: AppColors.danger),
          title: Text(_feesError ?? 'Could not load fees.', style: const TextStyle(fontSize: 13)),
          trailing: TextButton(onPressed: _loadFees, child: const Text('Retry')),
        ),
      );
    }
    final f = _fees!;
    final money = ContactActions.money;
    final due = f.balance > 0;
    final total = f.netTotal;
    final extra = f.additionalCharges;
    final recent = _showAllPayments ? f.paymentHistory : f.paymentHistory.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Fees', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: due ? AppColors.warningSoft : AppColors.successSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(due ? 'Due ₹${money(f.balance)}' : 'Fully paid',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: due ? AppColors.warning : AppColors.success)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _feeFigure('Total', total, AppColors.textPrimary),
                _feeFigure('Paid', f.totalPaid, AppColors.success),
                _feeFigure('Balance', f.balance, due ? AppColors.danger : AppColors.success),
              ],
            ),
            if (extra > 0.5 || f.existingDiscount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  [
                    if (extra > 0.5) 'Includes ₹${money(extra)} additional charges',
                    if (f.existingDiscount > 0) 'Total is after ₹${money(f.existingDiscount)} discount',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            if (recent.isNotEmpty) ...[
              const Divider(height: 22),
              for (final p in recent)
                InkWell(
                  onTap: () => ReceiptScreen.open(context, p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${DateFormat('dd MMM yyyy').format(p.paymentDate)} · ${p.paymentMode}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                              Text(p.receiptNo, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Text('₹${money(p.netAmount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        IconButton(
                          tooltip: 'Receipt',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.receipt_long_outlined, size: 22, color: AppColors.info),
                          onPressed: () => ReceiptScreen.open(context, p),
                        ),
                      ],
                    ),
                  ),
                ),
              if (f.paymentHistory.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => setState(() => _showAllPayments = !_showAllPayments),
                    child: Text(_showAllPayments ? 'Show fewer' : 'Show all ${f.paymentHistory.length} payments', style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
            if (due) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _contactsOf(s).isEmpty
                    ? null
                    : () => ContactActions.whatsapp(
                          context,
                          name: s.displayName,
                          contacts: _contactsOf(s),
                          category: 'FeeReminder',
                          vars: _vars(s, extra: {
                            'total': money(total),
                            'paid': money(f.totalPaid),
                            'balance': money(f.balance),
                          }),
                        ),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Send Fee Reminder on WhatsApp'),
                style: FilledButton.styleFrom(backgroundColor: whatsappGreen, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(44)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _feeFigure(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('₹${ContactActions.money(value)}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
