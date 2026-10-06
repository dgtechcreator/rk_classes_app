import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/contact_number.dart';
import '../../models/finance.dart';
import '../../models/student.dart';
import '../../services/fees_service.dart';
import '../../services/finance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/contact_actions.dart';
import '../fees/receipt_screen.dart';
import '../students/student_detail_screen.dart';

enum FinanceFilter { all, due, paid }

/// How the list is ordered / which figure leads, depending on the dashboard tile it was opened from.
enum FinanceSort { name, fees, collected, balance }

/// Student-wise fee list behind the Finance dashboard: opened from a tile (all students / fees /
/// collected / balance) or from a class-batch row. Every student has Call, WhatsApp (fee reminder when
/// something is due) and Receipt actions; the figures use the same rule as the dashboard totals.
class FinanceStudentsScreen extends StatefulWidget {
  const FinanceStudentsScreen({
    super.key,
    required this.title,
    this.className,
    this.batchName,
    this.sectionName,
    this.anyBatch = false,
    this.filter = FinanceFilter.all,
    this.sort = FinanceSort.name,
  });

  final String title;
  final String? className;
  final String? batchName;
  final String? sectionName;
  final bool anyBatch;
  final FinanceFilter filter;
  final FinanceSort sort;

  @override
  State<FinanceStudentsScreen> createState() => _FinanceStudentsScreenState();
}

class _FinanceStudentsScreenState extends State<FinanceStudentsScreen> {
  final _service = FinanceService();
  final _searchCtrl = TextEditingController();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  bool _loading = true;
  String? _error;
  FinanceStudentsResult? _result;
  late FinanceFilter _filter = widget.filter;
  String _query = '';

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
      final r = await _service.getStudents(className: widget.className, batchName: widget.batchName, sectionName: widget.sectionName, anyBatch: widget.anyBatch);
      if (mounted) setState(() { _result = r; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  List<FinanceStudent> get _visible {
    final all = _result?.students ?? const <FinanceStudent>[];
    final q = _query.trim().toLowerCase();
    final list = all.where((s) {
      switch (_filter) {
        case FinanceFilter.due:
          if (!s.hasDue) return false;
        case FinanceFilter.paid:
          if (s.hasDue) return false;
        case FinanceFilter.all:
          break;
      }
      return q.isEmpty || s.fullName.toLowerCase().contains(q) || s.admissionNo.toLowerCase().contains(q);
    }).toList();
    int cmp(FinanceStudent a, FinanceStudent b) {
      switch (widget.sort) {
        case FinanceSort.fees:
          return b.totalFees.compareTo(a.totalFees);
        case FinanceSort.collected:
          return b.collected.compareTo(a.collected);
        case FinanceSort.balance:
          return b.balance.compareTo(a.balance);
        case FinanceSort.name:
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      }
    }
    list.sort(cmp);
    return list;
  }

  List<ContactNumber> _contacts(FinanceStudent s) => buildContacts(father: s.fatherPhone, mother: s.motherPhone, student: s.phone);

  Map<String, String> _vars(FinanceStudent s, {Map<String, String> extra = const {}}) =>
      ContactActions.baseVars(student: s.fullName, className: s.className, medium: s.sectionName, extra: extra);

  Future<void> _whatsapp(FinanceStudent s) {
    final due = s.hasDue;
    return ContactActions.whatsapp(
      context,
      name: s.fullName,
      contacts: _contacts(s),
      category: due ? 'FeeReminder' : 'General',
      vars: _vars(s, extra: {
        'total': ContactActions.money(s.totalFees - s.discount),
        'paid': ContactActions.money(s.collected),
        'balance': ContactActions.money(s.balance < 0 ? 0 : s.balance),
      }),
    );
  }

  /// Opens the receipt for this student's payment — straight away when there is one, otherwise a picker.
  Future<void> _receipt(FinanceStudent s) async {
    try {
      final info = await FeesService().getPayInfo(s.studentId);
      if (!mounted) return;
      final payments = info.paymentHistory;
      if (payments.isEmpty) {
        showSnack(context, 'No payments received from ${s.fullName} yet.');
        return;
      }
      if (payments.length == 1) {
        await ReceiptScreen.open(context, payments.first);
        return;
      }
      final picked = await showModalBottomSheet<FeePayment>(
        context: context,
        backgroundColor: AppColors.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Receipts · ${s.fullName}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in payments)
                        ListTile(
                          leading: const Icon(Icons.receipt_long_outlined, color: AppColors.info),
                          title: Text(p.receiptNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${DateFormat('dd MMM yyyy').format(p.paymentDate)} · ${p.paymentMode}'),
                          trailing: Text(_money.format(p.netAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () => Navigator.pop(ctx, p),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (picked != null && mounted) await ReceiptScreen.open(context, picked);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final r = _result!;
    final list = _visible;
    final canReceipt = context.read<Session>().hasPerm('fee_collection');
    final canProfile = context.read<Session>().hasPerm('student_view');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _summary(r),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(hintText: 'Search name or admission no.', prefixIcon: Icon(Icons.search_rounded), isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final f in FinanceFilter.values) ...[
                ChoiceChip(
                  label: Text(switch (f) { FinanceFilter.all => 'All', FinanceFilter.due => 'Due', FinanceFilter.paid => 'Paid up' }),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Text('${list.length} students', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            const EmptyState(message: 'No students match.', icon: Icons.groups_outlined)
          else
            for (final s in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: _studentCard(s, canReceipt, canProfile)),
        ],
      ),
    );
  }

  /// Four cards, same look as the Fee Structure header cards: what the group owes in total (after discount),
  /// what has been received, what is pending, and how many students.
  Widget _summary(FinanceStudentsResult r) {
    final net = r.totalFees - r.totalDiscount;
    final recvPct = net <= 0 ? 0 : (r.totalCollected / net * 100).clamp(0, 100).round();
    final pendPct = net <= 0 ? 0 : 100 - recvPct;
    final pending = r.totalBalance < 0 ? 0.0 : r.totalBalance;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatCard(label: 'Total Fee', value: _money.format(net), color: AppColors.info, icon: Icons.receipt_long_outlined)),
            const SizedBox(width: 10),
            Expanded(child: StatCard(label: 'Received · $recvPct%', value: _money.format(r.totalCollected), color: AppColors.success, icon: Icons.check_circle_outline)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: StatCard(label: 'Pending · $pendPct%', value: _money.format(pending), color: pending > 0 ? AppColors.warning : AppColors.success, icon: Icons.account_balance_wallet_outlined)),
            const SizedBox(width: 10),
            Expanded(child: StatCard(label: 'Students', value: '${r.students.length}', color: AppColors.violet, icon: Icons.groups_outlined)),
          ],
        ),
        if (r.totalDiscount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Fee ${_money.format(r.totalFees)} − discount ${_money.format(r.totalDiscount)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ),
      ],
    );
  }

  Widget _studentCard(FinanceStudent s, bool canReceipt, bool canProfile) {
    final hasContact = _contacts(s).isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            onTap: canProfile
                ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: s.studentId)))
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('${s.admissionNo} · ${s.classLabel}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Text('Total ${_money.format(s.totalFees - s.discount)}  ·  Paid ${_money.format(s.collected)}${s.discount > 0 ? '  ·  after ${_money.format(s.discount)} disc' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: s.hasDue ? AppColors.dangerSoft : AppColors.successSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(s.hasDue ? 'Due ${_money.format(s.balance)}' : 'Paid up',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: s.hasDue ? AppColors.danger : AppColors.success)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _action(Icons.call_rounded, 'Call', AppColors.info, hasContact ? () => ContactActions.call(context, name: s.fullName, contacts: _contacts(s)) : null),
                _action(Icons.chat_rounded, s.hasDue ? 'Reminder' : 'WhatsApp', whatsappGreen, hasContact ? () => _whatsapp(s) : null),
                if (canReceipt) _action(Icons.receipt_long_outlined, 'Receipt', AppColors.violet, s.collected > 0 ? () => _receipt(s) : null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback? onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(foregroundColor: color, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
    );
  }
}
