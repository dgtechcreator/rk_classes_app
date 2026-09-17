import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/finance.dart';
import '../../services/finance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'finance_class_detail_screen.dart';

/// Collection-analytics dashboard, gated on the `finance_view` permission — mirrors
/// FinanceController.Dashboard. Real per-class/batch fee collection breakdown, tap a row for detail.
class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final _service = FinanceService();
  bool _loading = true;
  String? _error;
  FinanceDashboardData? _data;

  final _fmt = NumberFormat.compactCurrency(symbol: '₹');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getDashboard();
      if (mounted) setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance Dashboard')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final pct = (d.collectionPercentage / 100).clamp(0.0, 1.0);
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
              StatCard(label: 'Total Students', value: '${d.totalStudents}', color: AppColors.info, icon: Icons.groups),
              StatCard(label: 'Total Fees', value: _fmt.format(d.totalFees), color: AppColors.info, icon: Icons.receipt_long_outlined),
              StatCard(label: 'Collected', value: _fmt.format(d.totalCollected), color: AppColors.success, icon: Icons.check_circle_outline),
              StatCard(label: 'Balance', value: _fmt.format(d.totalBalance), color: d.totalBalance > 0 ? AppColors.warning : AppColors.success, icon: Icons.account_balance_wallet_outlined),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Collection %', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${d.collectionPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.success)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'By Class / Batch'),
          if (d.academicData.isEmpty)
            const EmptyState(message: 'No fee structure data yet.', icon: Icons.bar_chart_outlined)
          else
            ...d.academicData.map((row) {
              final rowPct = row.totalFees == 0 ? 0.0 : (row.estimatedCollected / row.totalFees).clamp(0.0, 1.0);
              return Card(
                child: ListTile(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FinanceClassDetailScreen(className: row.className, batchName: row.batchName))),
                  title: Text('${row.className} / ${row.batchName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: rowPct, minHeight: 6, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.info)),
                    ),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${row.studentCount} students', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text(_fmt.format(row.balance), style: TextStyle(fontWeight: FontWeight.w700, color: row.balance > 0 ? AppColors.warning : AppColors.success)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
