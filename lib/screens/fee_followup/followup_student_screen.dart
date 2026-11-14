import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../services/fee_followup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// One student's fee follow-up: balance, phone numbers, "Add follow-up", and the full history (who, when, what was said, next date).
class FollowupStudentScreen extends StatefulWidget {
  const FollowupStudentScreen({super.key, required this.studentId});
  final int studentId;
  @override
  State<FollowupStudentScreen> createState() => _FollowupStudentScreenState();
}

class _FollowupStudentScreenState extends State<FollowupStudentScreen> {
  final _service = FeeFollowupService();
  FollowupStudent? _s;
  bool _loading = true;
  String? _error;
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _s == null; _error = null; });
    try {
      final s = await _service.student(widget.studentId);
      if (mounted) setState(() { _s = s; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _add() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddSheet(studentId: widget.studentId),
    );
    if (ok == true) {
      if (mounted) showSnack(context, 'Follow-up saved.');
      _load();
    }
  }

  Future<void> _delete(FollowupEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this follow-up?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(e.id);
      _load();
    } on ApiException catch (x) {
      if (mounted) showSnack(context, x.message, isError: true);
    }
  }

  String _last10(String p) {
    final d = p.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final dt = DateFormat('d MMM yyyy, h:mm a');
    return Scaffold(
      appBar: AppBar(title: Text(s?.name ?? 'Fee Follow-up')),
      floatingActionButton: s == null ? null : FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_call), label: const Text('Add follow-up')),
      body: _loading
          ? const LoadingView()
          : _error != null && s == null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s!.admissionNo} · ${s.group}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                        const SizedBox(height: 8),
                        Row(children: [
                          _fig('Total fees', _money.format(s.totalFees), AppColors.textPrimary),
                          _fig('Collected', _money.format(s.collected), AppColors.success),
                          _fig('Balance', _money.format(s.balance), s.balance > 0 ? AppColors.danger : AppColors.success),
                        ]),
                        const SizedBox(height: 6),
                        for (final p in s.phones)
                          Row(children: [
                            SizedBox(width: 58, child: Text(p.$1, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                            Expanded(child: Text(p.$2, style: const TextStyle(fontWeight: FontWeight.w700))),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.call, color: AppColors.info, size: 20),
                              onPressed: () => launchUrl(Uri.parse('tel:${p.$2}')),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.chat, color: Color(0xFF16A34A), size: 20),
                              onPressed: () => launchUrl(Uri.parse('https://wa.me/91${_last10(p.$2)}'), mode: LaunchMode.externalApplication),
                            ),
                          ]),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    SectionHeader(title: 'History (${s.history.length})'),
                    if (s.history.isEmpty) const EmptyState(message: 'No follow-up recorded yet.\nTap "Add follow-up".', icon: Icons.phone_in_talk_outlined),
                    for (final h in s.history) _entry(h.$1, h.$2, dt),
                  ]),
                ),
    );
  }

  Widget _fig(String label, String v, Color c) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c))),
        ]),
      );

  Widget _entry(FollowupEntry e, bool canDelete, DateFormat dt) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.soft,
          border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${dt.format(e.at)} · ${e.outcome}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
            if (canDelete)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                onPressed: () => _delete(e),
              ),
          ]),
          Text(
            'by ${e.followedByName.isEmpty ? '-' : e.followedByName} · ${e.mode}${e.spokeTo == null ? '' : ' · spoke to ${e.spokeTo}'}${e.balanceAtTime == null ? '' : ' · balance then ${_money.format(e.balanceAtTime)}'}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if ((e.reason ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('Reason: ${e.reason}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          if ((e.notes ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.notes!, style: const TextStyle(fontSize: 13))),
          if (e.nextDate != null || (e.promisedAmount ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${e.nextDate != null ? 'Next: ${DateFormat('d MMM yyyy').format(e.nextDate!)} (${e.nextDateBy == 'Parent' ? 'parent said' : 'we will call again'})' : ''}${(e.promisedAmount ?? 0) > 0 ? ' · promised ${_money.format(e.promisedAmount)}' : ''}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.info),
              ),
            ),
        ]),
      );
}

class _AddSheet extends StatefulWidget {
  const _AddSheet({required this.studentId});
  final int studentId;
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _service = FeeFollowupService();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final _amount = TextEditingController();
  String _mode = 'Call';
  String? _spoke, _outcome;
  DateTime? _next;
  String _nextBy = 'Parent';
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_outcome == null) {
      showSnack(context, 'Choose what came of the follow-up.', isError: true);
      return;
    }
    if (_notes.text.trim().isEmpty && _reason.text.trim().isEmpty) {
      showSnack(context, 'Write what was said, or the reason the fees are pending.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.add(
        studentId: widget.studentId,
        mode: _mode,
        spokeTo: _spoke,
        outcome: _outcome!,
        reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        promisedAmount: double.tryParse(_amount.text.trim()),
        nextDate: _next,
        nextDateBy: _next == null ? null : _nextBy,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Add follow-up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('It is saved with your name and the time now.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, children: [
            for (final m in FeeFollowupService.modes) ChoiceChip(label: Text(m), selected: _mode == m, onSelected: (_) => setState(() => _mode = m)),
          ]),
          const SizedBox(height: 10),
          const Text('Spoke to', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Wrap(spacing: 6, children: [
            for (final m in FeeFollowupService.spokeTo) ChoiceChip(label: Text(m), selected: _spoke == m, onSelected: (v) => setState(() => _spoke = v ? m : null)),
          ]),
          const SizedBox(height: 10),
          const Text('What came of it *', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Wrap(spacing: 6, children: [
            for (final o in FeeFollowupService.outcomes) ChoiceChip(label: Text(o), selected: _outcome == o, onSelected: (v) => setState(() => _outcome = v ? o : null)),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _reason, maxLength: 300, decoration: const InputDecoration(labelText: 'Reason the fees are pending', counterText: '')),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 1500,
            decoration: const InputDecoration(labelText: 'What was said (the conversation)', alignLabelWithHint: true, counterText: ''),
          ),
          const SizedBox(height: 10),
          TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount promised (₹)')),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _next ?? DateTime.now().add(const Duration(days: 3)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (p != null) setState(() => _next = p);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Next date',
                suffixIcon: _next == null
                    ? const Icon(Icons.calendar_today_outlined, size: 18)
                    : IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _next = null)),
              ),
              child: Text(_next == null ? 'Not set' : DateFormat('EEE, d MMM yyyy').format(_next!)),
            ),
          ),
          if (_next != null) ...[
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Parent', label: Text('Parent gave this date')),
                ButtonSegment(value: 'Self', label: Text('I set it (call again)')),
              ],
              selected: {_nextBy},
              onSelectionChanged: (v) => setState(() => _nextBy = v.first),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save follow-up'),
          ),
        ]),
      ),
    );
  }
}
