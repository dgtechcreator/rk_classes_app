import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/student.dart';
import '../../services/staff_dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../students/student_detail_screen.dart';
import 'receipt_screen.dart';

/// Payments behind the "Fees This Month" dashboard card — the same set the card adds up
/// (payment date in the current month, deleted receipts excluded), so the two always agree.
class FeesThisMonthScreen extends StatefulWidget {
  const FeesThisMonthScreen({super.key});

  @override
  State<FeesThisMonthScreen> createState() => _FeesThisMonthScreenState();
}

class _FeesThisMonthScreenState extends State<FeesThisMonthScreen> {
  final _service = StaffDashboardService();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  bool _loading = true;
  String? _error;
  List<FeePayment> _payments = [];
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _service.getFeesThisMonth();
      if (mounted) setState(() { _payments = res.payments; _total = res.total; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fees · ${DateFormat('MMMM yyyy').format(DateTime.now())}')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _payments.isEmpty
                  ? const EmptyState(message: 'No payments received this month yet.', icon: Icons.payments_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _payments.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => i == 0 ? _summary() : _row(_payments[i - 1]),
                      ),
                    ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${_payments.length} payments received', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          Text(_money.format(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.success)),
        ],
      ),
    );
  }

  Widget _row(FeePayment p) {
    final sub = [
      if (p.className != null && p.className!.trim().isNotEmpty) p.className!.trim(),
      DateFormat('dd MMM').format(p.paymentDate),
      p.paymentMode,
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        onTap: p.studentId == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: p.studentId!))),
        title: Text(p.studentName ?? 'Student', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_money.format(p.netAmount), style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(
              tooltip: 'Receipt',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.receipt_long_outlined, color: AppColors.info),
              onPressed: () => ReceiptScreen.open(context, p),
            ),
          ],
        ),
      ),
    );
  }
}
