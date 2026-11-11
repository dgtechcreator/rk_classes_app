import 'package:fl_chart/fl_chart.dart';
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
import 'fee_reminder_queue.dart';

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
    this.noMedium = false,
    this.filter = FinanceFilter.all,
    this.sort = FinanceSort.name,
  });

  final String title;
  final String? className;
  final String? batchName;
  final String? sectionName;
  final bool anyBatch;
  /// Only students of that class/batch who have no medium (section) set.
  final bool noMedium;
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
      var r = await _service.getStudents(className: widget.className, batchName: widget.batchName, sectionName: widget.sectionName, anyBatch: widget.anyBatch);
      if (widget.noMedium) {
        final list = r.students.where((s) => s.sectionName.trim().isEmpty).toList();
        r = FinanceStudentsResult(
          students: list,
          totalFees: list.fold(0.0, (a, s) => a + s.totalFees),
          totalCollected: list.fold(0.0, (a, s) => a + s.collected),
          totalDiscount: list.fold(0.0, (a, s) => a + s.discount),
          totalBalance: list.fold(0.0, (a, s) => a + s.balance),
        );
      }
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
      final hay = '${s.fullName} ${s.admissionNo}'.toLowerCase();
      return q.isEmpty || q.split(RegExp(r'[\s,.]+')).where((t) => t.isNotEmpty).every(hay.contains);
    }).toList();
    int cmp(FinanceStudent a, FinanceStudent b) {
      switch (widget.sort) {
        case FinanceSort.fees:
          return (b.totalFees - b.discount).compareTo(a.totalFees - a.discount);
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

  /// Students on screen (after the search box) who owe fees - the ones a reminder goes to.
  List<FinanceStudent> get _dueList => _visible.where((s) => s.hasDue && !s.feeNotSet).toList();

  /// One button for the whole list: choose app notification (instant, to every parent) or the WhatsApp queue.
  Future<void> _remindAll() async {
    final due = _dueList;
    if (due.isEmpty) return;
    final pending = due.fold<double>(0, (sum, s) => sum + s.balance);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Fee reminder to ${due.length} students', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Text('Total due ${_money.format(pending)}', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
              title: const Text('App notification to all parents', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Goes out instantly - parents see it in the RK Classes app.'),
              onTap: () => Navigator.pop(ctx, 'app'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: whatsappGreen),
              title: const Text('WhatsApp, one after another', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Every parent chat opens with the message ready - you only press Send.'),
              onTap: () => Navigator.pop(ctx, 'whatsapp'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'whatsapp') {
      await showFeeReminderQueue(context, due);
      return;
    }
    try {
      if (!mounted) return;
      final sent = await withLoader(context, () => _service.remindDue(due.map((s) => s.studentId).toList()));
      if (mounted) showSnack(context, sent > 0 ? 'Fee reminder sent to $sent parents.' : 'No reminder was needed - nobody owes fees.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
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
        if (await ReceiptScreen.open(context, payments.first) && mounted) _load();
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
      if (picked != null && mounted && await ReceiptScreen.open(context, picked) && mounted) _load();
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
    final canRemind = context.read<Session>().hasPerm('finance_view');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _summary(r),
          const SizedBox(height: 12),
          if (_dueList.isNotEmpty && canRemind) ...[
            FilledButton.icon(
              onPressed: _remindAll,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text('Send fee reminder to all due (${_dueList.length})'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(hintText: 'Search name, father, mother or admission no.', prefixIcon: Icon(Icons.search_rounded), isDense: true),
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

  /// One round chart for the group: green = received, red = still pending (both as % of the fee after discount),
  /// with the total fee, received, pending and student count beside it.
  Widget _summary(FinanceStudentsResult r) {
    final net = r.totalFees - r.totalDiscount;
    final pending = r.totalBalance < 0 ? 0.0 : r.totalBalance;
    final recvPct = net <= 0 ? 0 : (r.totalCollected / net * 100).clamp(0, 100).round();
    final pendPct = net <= 0 ? 0 : 100 - recvPct;
    final any = net > 0;
    Widget legend(String label, String value, Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
            Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 140, height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(PieChartData(
                      sectionsSpace: any && recvPct > 0 && pendPct > 0 ? 2 : 0,
                      centerSpaceRadius: 44,
                      startDegreeOffset: -90,
                      sections: [
                        PieChartSectionData(value: any ? r.totalCollected.clamp(0, net).toDouble() : 0, color: AppColors.success, radius: 22, showTitle: false),
                        PieChartSectionData(value: any ? (net - r.totalCollected).clamp(0, net).toDouble() : 1, color: any ? AppColors.danger : AppColors.borderNeutral, radius: 22, showTitle: false),
                      ],
                    )),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$recvPct%', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.success)),
                      const Text('paid', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    legend('Received · $recvPct%', _money.format(r.totalCollected), AppColors.success),
                    legend('Pending · $pendPct%', _money.format(pending), AppColors.danger),
                    const Divider(height: 14),
                    legend('Total fee', _money.format(net), AppColors.textSecondary),
                    legend('Students', '${r.students.length}', AppColors.violet),
                  ],
                ),
              ),
            ],
          ),
          if (r.totalDiscount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Fee ${_money.format(r.totalFees)} − discount ${_money.format(r.totalDiscount)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
        ],
      ),
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
                        Text(s.feeNotSet
                                ? 'Fee not set  ·  Paid ${_money.format(s.collected)}${s.discount > 0 ? '  ·  disc ${_money.format(s.discount)}' : ''}'
                                : 'Total ${_money.format(s.totalFees - s.discount)}  ·  Paid ${_money.format(s.collected)}${s.discount > 0 ? '  ·  after ${_money.format(s.discount)} disc' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: s.feeNotSet ? AppColors.warningSoft : (s.hasDue ? AppColors.dangerSoft : AppColors.successSoft), borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(s.feeNotSet ? 'Fee not set' : (s.hasDue ? 'Due ${_money.format(s.balance)}${s.previousDue > 0.5 ? ' · old ${_money.format(s.previousDue)}' : ''}' : 'Paid up'),
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: s.feeNotSet ? AppColors.warning : (s.hasDue ? AppColors.danger : AppColors.success))),
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
