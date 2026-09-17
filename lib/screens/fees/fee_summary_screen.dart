import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/student.dart';
import '../../services/fees_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Paginated fee payment history with search/month filter and delete — mirrors FeesController's
/// Summary partial (_Summary.cshtml).
class FeeSummaryScreen extends StatefulWidget {
  const FeeSummaryScreen({super.key});

  @override
  State<FeeSummaryScreen> createState() => _FeeSummaryScreenState();
}

class _FeeSummaryScreenState extends State<FeeSummaryScreen> {
  final _service = FeesService();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<FeePayment> _payments = [];
  int _total = 0;
  double _grandTotal = 0;
  int _page = 1;
  String? _month;
  static const _pageSize = 15;

  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

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
      final result = await _service.getSummary(page: _page, search: _searchCtrl.text.trim(), month: _month);
      if (mounted) setState(() { _payments = result.payments; _total = result.total; _grandTotal = result.grandTotalAmount; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _delete(FeePayment p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Remove receipt ${p.receiptNo} for ${_fmt.format(p.netAmount)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deletePayment(p.paymentId);
      if (mounted) { showSnack(context, 'Payment deleted.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  int get _totalPages => _total == 0 ? 1 : ((_total - 1) ~/ _pageSize) + 1;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasPerm('fee_collect');
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(labelText: 'Search student, receipt no.', prefixIcon: Icon(Icons.search)),
              onSubmitted: (_) { _page = 1; _load(); },
            ),
          ),
          Expanded(child: _buildBody(canEdit)),
        ],
      ),
    );
  }

  Widget _buildBody(bool canEdit) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Row(
            children: [
              Expanded(child: StatCard(label: 'Payments', value: '$_total', color: AppColors.info, icon: Icons.receipt_long_outlined)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Total Amount', value: _fmt.format(_grandTotal), color: AppColors.success, icon: Icons.trending_up)),
            ],
          ),
          const SizedBox(height: 16),
          if (_payments.isEmpty)
            const EmptyState(message: 'No payments found.', icon: Icons.receipt_long_outlined)
          else
            ..._payments.map((p) => Card(
                  child: ListTile(
                    title: Text(p.studentName ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${p.receiptNo} • ${DateFormat.yMMMd().format(p.paymentDate)} • ${p.paymentMode}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_fmt.format(p.netAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (canEdit)
                          IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _delete(p)),
                      ],
                    ),
                  ),
                )),
          if (_totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null),
                Text('Page $_page of $_totalPages'),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: _page < _totalPages ? () { setState(() => _page++); _load(); } : null),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
