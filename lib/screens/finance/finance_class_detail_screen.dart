import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/finance.dart';
import '../../services/finance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Per-student fee breakdown for one class/batch — mirrors FinanceController.ClassDetail.
class FinanceClassDetailScreen extends StatefulWidget {
  const FinanceClassDetailScreen({super.key, required this.className, required this.batchName});
  final String className;
  final String batchName;

  @override
  State<FinanceClassDetailScreen> createState() => _FinanceClassDetailScreenState();
}

class _FinanceClassDetailScreenState extends State<FinanceClassDetailScreen> {
  final _service = FinanceService();
  bool _loading = true;
  String? _error;
  FinanceClassDetail? _detail;

  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await _service.getClassDetail(widget.className, widget.batchName);
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.className} / ${widget.batchName}')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _detail!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              StatCard(label: 'Students', value: '${d.totalStudents}', color: AppColors.info, icon: Icons.groups),
              StatCard(label: 'Total Fees', value: _fmt.format(d.totalFees), color: AppColors.info, icon: Icons.receipt_long_outlined),
              StatCard(label: 'Collected', value: _fmt.format(d.totalCollected), color: AppColors.success, icon: Icons.check_circle_outline),
              StatCard(label: 'Balance', value: _fmt.format(d.totalBalance), color: d.totalBalance > 0 ? AppColors.warning : AppColors.success, icon: Icons.account_balance_wallet_outlined),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Students'),
          if (d.studentDetails.isEmpty)
            const EmptyState(message: 'No students found.', icon: Icons.person_off_outlined)
          else
            ...d.studentDetails.map((s) => Card(
                  child: ListTile(
                    title: Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Fees ${_fmt.format(s.totalFees)} • Discount ${_fmt.format(s.discount)}'),
                    trailing: Text(_fmt.format(s.balance), style: TextStyle(fontWeight: FontWeight.w700, color: s.balance > 0 ? AppColors.warning : AppColors.success)),
                  ),
                )),
        ],
      ),
    );
  }
}
