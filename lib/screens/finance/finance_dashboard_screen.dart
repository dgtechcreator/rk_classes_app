import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/finance.dart';
import '../../services/finance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'finance_students_screen.dart';

/// Finance overview: collection hero, four tappable tiles (each opens the matching student list with
/// call / WhatsApp / receipt actions) and a class-wise breakdown whose rows open that class's students.
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

  final _compact = NumberFormat.compactCurrency(symbol: '₹');
  final _full = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

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

  void _open(FinanceStudentsScreen screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? SafeArea(
                  child: Column(
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: BackButton()),
                      Expanded(child: ErrorView(message: _error!, onRetry: _load)),
                    ],
                  ),
                )
              : RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final pct = (d.collectionPercentage / 100).clamp(0.0, 1.0);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _header(d, pct)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              GridView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 56),
                children: [
                  SlimStatCard(
                    label: 'Total Students', value: '${d.totalStudents}', color: AppColors.info, icon: Icons.groups,
                    onTap: () => _open(const FinanceStudentsScreen(title: 'All Students')),
                  ),
                  SlimStatCard(
                    label: 'Total Fees', value: _compact.format(d.totalFees), color: AppColors.violet, icon: Icons.receipt_long_outlined,
                    onTap: () => _open(const FinanceStudentsScreen(title: 'Total Fees', sort: FinanceSort.fees)),
                  ),
                  SlimStatCard(
                    label: 'Collected', value: _compact.format(d.totalCollected), color: AppColors.success, icon: Icons.check_circle_outline,
                    onTap: () => _open(const FinanceStudentsScreen(title: 'Collected Fees', sort: FinanceSort.collected)),
                  ),
                  SlimStatCard(
                    label: 'Balance', value: _compact.format(d.totalBalance), color: d.totalBalance > 0 ? AppColors.warning : AppColors.success,
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => _open(const FinanceStudentsScreen(title: 'Pending Dues', filter: FinanceFilter.due, sort: FinanceSort.balance)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Class-wise'),
              if (d.academicData.isEmpty)
                const EmptyState(message: 'No fee data yet.', icon: Icons.bar_chart_outlined)
              else
                for (final row in d.academicData) Padding(padding: const EdgeInsets.only(bottom: 10), child: _classCard(row)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _header(FinanceDashboardData d, double pct) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      child: Container(
        padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 4, 18, 20),
        decoration: const BoxDecoration(gradient: AppGradients.primarySheen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                BackButton(color: Colors.white),
                Text('Finance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Collected so far', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(_full.format(d.totalCollected), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 2),
                        Text('of ${_full.format(d.totalFees)} total fees', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _chip('Discount ${_compact.format(d.totalDiscount)}'),
                            _chip('Balance ${_compact.format(d.totalBalance)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: CircularProgressIndicator(value: pct, strokeWidth: 8, strokeCap: StrokeCap.round, backgroundColor: Colors.white24, color: Colors.white),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${d.collectionPercentage.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                            const Text('collected', style: TextStyle(color: Colors.white70, fontSize: 9.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );

  Widget _classCard(FinanceAcademicRow row) {
    final cls = row.className.trim();
    final batch = row.batchName.trim();
    final title = batch.isEmpty ? cls : '$cls · $batch';
    final pct = row.totalFees <= 0 ? 0.0 : (row.estimatedCollected / row.totalFees * 100).clamp(0.0, 100.0);
    final due = row.balance > 0.5;
    Widget fig(String label, double v, Color c) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_compact.format(v), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c)),
              ),
            ],
          ),
        );
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => _open(FinanceStudentsScreen(title: title, className: cls, batchName: batch, sort: FinanceSort.balance)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text('${row.studentCount} students', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.info)),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                fig('Fees', row.totalFees, AppColors.textPrimary),
                fig('Collected', row.estimatedCollected, AppColors.success),
                fig('Discount', row.estimatedDiscount, AppColors.info),
                fig('Balance', row.balance < 0 ? 0 : row.balance, due ? AppColors.danger : AppColors.success),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              due ? '${pct.toStringAsFixed(0)}% collected · tap to see students with dues' : '${pct.toStringAsFixed(0)}% collected · fully settled',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
