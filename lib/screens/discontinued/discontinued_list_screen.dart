import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/discontinued_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'discontinue_new_screen.dart';

/// Students who left the classes or were removed: reason, who recorded it, and what was paid / pending that day.
/// Same list as the website's Discontinued Students page.
class DiscontinuedListScreen extends StatefulWidget {
  const DiscontinuedListScreen({super.key});

  @override
  State<DiscontinuedListScreen> createState() => _DiscontinuedListScreenState();
}

class _DiscontinuedListScreenState extends State<DiscontinuedListScreen> {
  final _service = DiscontinuedService();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _date = DateFormat('dd MMM yyyy');
  bool _loading = true;
  String? _error;
  List<DiscontinuedEntry> _all = [];
  String _query = '';
  String? _kind; // null = all

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _service.getAll();
      if (mounted) setState(() { _all = list; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  List<DiscontinuedEntry> get _visible {
    final q = _query.trim().toLowerCase();
    return _all.where((d) {
      if (_kind != null && d.kind != _kind) return false;
      if (q.isEmpty) return true;
      return '${d.studentName} ${d.admissionNo} ${d.reason} ${d.className} ${d.recordedByName}'.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.read<Session>().hasEditPerm('discontinued_students');
    final list = _visible;
    final counted = _all.where((d) => !d.returned).toList();
    final paid = counted.fold<double>(0, (a, d) => a + d.paid);
    final pending = counted.fold<double>(0, (a, d) => a + d.pending);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Discontinued Students')),
      floatingActionButton: !canEdit
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const DiscontinueNewScreen()));
                if (saved == true) _load();
              },
              icon: const Icon(Icons.person_off_outlined),
              label: const Text('Discontinue'),
            ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    children: [
                      Row(children: [
                        Expanded(child: _stat('Discontinued', '${counted.length}', AppColors.danger)),
                        const SizedBox(width: 8),
                        Expanded(child: _stat('Paid by them', _money.format(paid), AppColors.success)),
                        const SizedBox(width: 8),
                        Expanded(child: _stat('Pending', _money.format(pending), AppColors.warning)),
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, admission no, reason…'),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        ChoiceChip(label: const Text('All'), selected: _kind == null, onSelected: (_) => setState(() => _kind = null)),
                        ChoiceChip(label: const Text('Left'), selected: _kind == 'Left', onSelected: (_) => setState(() => _kind = 'Left')),
                        ChoiceChip(label: const Text('Removed'), selected: _kind == 'Removed', onSelected: (_) => setState(() => _kind = 'Removed')),
                      ]),
                      const SizedBox(height: 10),
                      if (list.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(message: 'No discontinued students.', icon: Icons.person_off_outlined))
                      else
                        for (final d in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(d)),
                    ],
                  ),
                ),
    );
  }

  Future<void> _revert(DiscontinuedEntry d) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Take ${d.studentName} back?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('The student becomes Active again and is counted everywhere. This entry stays here as history.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Why is the student coming back?')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Take back', style: TextStyle(color: AppColors.success))),
        ],
      ),
    );
    final text = note.text.trim();
    note.dispose();
    if (ok != true) return;
    try {
      if (!mounted) return;
      await withLoader(context, () => _service.revert(d.id, note: text.isEmpty ? null : text));
      if (!mounted) return;
      showSnack(context, '${d.studentName} is active again.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Widget _stat(String label, String value, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c))),
        ]),
      );

  Widget _card(DiscontinuedEntry d) {
    final cls = [d.className, d.sectionName, d.batchName].where((e) => e.isNotEmpty).join(' · ');
    final kindColor = d.removed ? AppColors.danger : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(d.studentName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: kindColor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text(d.removed ? 'Removed' : 'Left', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kindColor)),
          ),
        ]),
        const SizedBox(height: 2),
        Text('${d.admissionNo} · $cls', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (d.returned)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              d.revertedAt != null
                  ? 'Taken back ${_date.format(d.revertedAt!)}${d.revertedByName.isEmpty ? '' : ' by ${d.revertedByName}'}${d.revertNote.isEmpty ? '' : ' — ${d.revertNote}'}'
                  : 'Taken back (active again)',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ),
        const SizedBox(height: 8),
        Text(d.reason, style: const TextStyle(fontSize: 13.5)),
        const SizedBox(height: 10),
        Row(children: [
          _fig('Total fee', _money.format(d.totalFees), AppColors.textPrimary),
          _fig('Paid', _money.format(d.paid), AppColors.success),
          _fig('Pending', _money.format(d.pending), d.pending > 0.5 ? AppColors.danger : AppColors.success),
        ]),
        const SizedBox(height: 8),
        if (d.canRevert && context.read<Session>().hasEditPerm('discontinued_students'))
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.success, side: const BorderSide(color: AppColors.success), visualDensity: VisualDensity.compact),
              onPressed: () => _revert(d),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Revert (take back)'),
            ),
          ),
        Text(
          '${d.leftOn == null ? '' : _date.format(d.leftOn!)} · recorded by ${d.recordedByName.isEmpty ? '—' : d.recordedByName}'
          '${d.recordedAt == null ? '' : ' · ${DateFormat('dd MMM, h:mm a').format(d.recordedAt!)}'}',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      ]),
    );
  }

  Widget _fig(String label, String value, Color c) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c))),
        ]),
      );
}
