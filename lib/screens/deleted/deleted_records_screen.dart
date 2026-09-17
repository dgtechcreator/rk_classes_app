import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../services/deleted_service.dart';
import '../../widgets/common.dart';

/// Soft-deleted students/faculty/receipts with restore — mirrors DeletedController.Index. Admin-only.
class DeletedRecordsScreen extends StatefulWidget {
  const DeletedRecordsScreen({super.key});

  @override
  State<DeletedRecordsScreen> createState() => _DeletedRecordsScreenState();
}

class _DeletedRecordsScreenState extends State<DeletedRecordsScreen> with SingleTickerProviderStateMixin {
  final _service = DeletedService();
  late final TabController _tabController = TabController(length: 3, vsync: this);
  bool _loading = true;
  String? _error;
  DeletedRecordsData? _data;

  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getAll();
      if (mounted) setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _restore(String label, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Record'),
        content: Text('Restore $label back to the active list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action();
      if (mounted) { showSnack(context, 'Restored.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not restore. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Records'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Students${d != null ? ' (${d.students.length})' : ''}'),
            Tab(text: 'Faculty${d != null ? ' (${d.faculty.length})' : ''}'),
            Tab(text: 'Receipts${d != null ? ' (${d.receipts.length})' : ''}'),
          ],
        ),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _studentsTab(d!),
                    _facultyTab(d),
                    _receiptsTab(d),
                  ],
                ),
    );
  }

  Widget _studentsTab(DeletedRecordsData d) {
    if (d.students.isEmpty) return const EmptyState(message: 'No deleted students.', icon: Icons.check_circle_outline);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: d.students.length,
        itemBuilder: (_, i) {
          final s = d.students[i];
          return Card(
            child: ListTile(
              title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${s.admissionNo} • ${s.classLabel}'),
              trailing: TextButton.icon(
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Restore'),
                onPressed: () => _restore(s.fullName, () => _service.restoreStudent(s.studentId)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _facultyTab(DeletedRecordsData d) {
    if (d.faculty.isEmpty) return const EmptyState(message: 'No deleted faculty.', icon: Icons.check_circle_outline);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: d.faculty.length,
        itemBuilder: (_, i) {
          final f = d.faculty[i];
          return Card(
            child: ListTile(
              title: Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(f.employeeCode),
              trailing: TextButton.icon(
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Restore'),
                onPressed: () => _restore(f.fullName, () => _service.restoreFaculty(f.facultyId)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _receiptsTab(DeletedRecordsData d) {
    if (d.receipts.isEmpty) return const EmptyState(message: 'No deleted receipts.', icon: Icons.check_circle_outline);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: d.receipts.length,
        itemBuilder: (_, i) {
          final p = d.receipts[i];
          return Card(
            child: ListTile(
              title: Text(p.studentName ?? p.receiptNo, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${p.receiptNo} • ${DateFormat.yMMMd().format(p.paymentDate)} • ${_fmt.format(p.netAmount)}'),
              trailing: TextButton.icon(
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Restore'),
                onPressed: () => _restore(p.receiptNo, () => _service.restoreReceipt(p.paymentId)),
              ),
            ),
          );
        },
      ),
    );
  }
}
