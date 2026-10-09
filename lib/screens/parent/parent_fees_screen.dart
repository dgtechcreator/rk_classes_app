import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/parent_data_controller.dart';
import '../../models/student.dart';
import '../../theme/app_theme.dart';
import '../../widgets/attendance_ring.dart';
import '../../widgets/common.dart';
import '../fees/receipt_screen.dart';

/// Parent's fee view: how much is fixed, paid and left (after discount), the fee heads, and every
/// payment with its receipt (view / share as PDF).
class ParentFeesScreen extends StatelessWidget {
  const ParentFeesScreen({super.key, this.standalone = false});

  /// True when pushed from Home (shows a back arrow); false when it is a bottom-nav tab.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ParentDataController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: standalone ? AppBar(title: const Text('Fees')) : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: ctrl.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (!standalone) TabHeader(title: 'Fees', subtitle: ctrl.selected?.displayName),
              _body(context, ctrl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ParentDataController ctrl) {
    if (ctrl.loading && ctrl.data == null) return const Padding(padding: EdgeInsets.only(top: 40), child: LoadingView());
    if (ctrl.error != null && ctrl.data == null) return ErrorView(message: ctrl.error!, onRetry: ctrl.load);
    final d = ctrl.data;
    final student = ctrl.selected;
    if (d == null || student == null) return const EmptyState(message: 'No fee details yet.', icon: Icons.receipt_long_outlined);

    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final paidPct = d.netTotal <= 0 ? 0.0 : (d.totalPaid / d.netTotal * 100).clamp(0.0, 100.0);
    final due = d.balance > 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: AppShadows.card),
          child: Row(
            children: [
              AttendanceRing(percent: paidPct, color: due ? AppColors.warning : AppColors.success, label: 'Paid'),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _figure('Total fee', money.format(d.netTotal), AppColors.textPrimary),
                    const SizedBox(height: 10),
                    _figure('Paid', money.format(d.totalPaid), AppColors.success),
                    const SizedBox(height: 10),
                    _figure('Balance', money.format(d.balance), due ? AppColors.danger : AppColors.success),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _pill(due ? 'Balance due ${money.format(d.balance)}' : 'All fees paid', due ? AppColors.dangerSoft : AppColors.successSoft, due ? AppColors.danger : AppColors.success),
            if (due && d.dueDate != null) _pill('Due by ${DateFormat('dd MMM yyyy').format(d.dueDate!)}', AppColors.warningSoft, AppColors.warning),
            if (d.discount > 0) _pill('Discount ${money.format(d.discount)}', AppColors.infoSoft, AppColors.info),
            if (d.additionalCharges > 0) _pill('Extra charges ${money.format(d.additionalCharges)}', AppColors.violetSoft, AppColors.violet),
          ],
        ),
        if (d.feeStructures.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionHeader(title: 'Fee Details'),
          for (final fs in d.feeStructures)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(fs.feeTypeName ?? 'Fee', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(fs.isMonthly ? 'Monthly · due day ${fs.dueDay}' : 'One-time'),
                trailing: Text(money.format(fs.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
        const SizedBox(height: 14),
        SectionHeader(title: 'Payments & Receipts (${d.feeHistory.length})'),
        if (d.feeHistory.isEmpty)
          const EmptyState(message: 'No payments recorded yet.', icon: Icons.history)
        else
          for (final p in d.feeHistory) _paymentCard(context, p, money, student, d),
      ],
    );
  }

  Widget _paymentCard(BuildContext context, FeePayment p, NumberFormat money, Student student, ParentDashboardData d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => ReceiptScreen.openForParent(context, p, student: student, balance: d.balance, dueDate: d.dueDate),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(money.format(p.netAmount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('${DateFormat('dd MMM yyyy').format(p.paymentDate)} · ${p.paymentMode}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(p.receiptNo, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => ReceiptScreen.openForParent(context, p, student: student, balance: d.balance, dueDate: d.dueDate),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Receipt'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _figure(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ),
          ),
        ],
      );

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
      );
}
