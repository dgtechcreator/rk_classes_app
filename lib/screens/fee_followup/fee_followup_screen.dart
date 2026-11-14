import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../services/fee_followup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/common.dart';
import 'followup_student_screen.dart';

String statusLabel(String s) => switch (s) {
      'Overdue' => 'Overdue',
      'Today' => 'Due today',
      'Upcoming' => 'Upcoming',
      'NoNextDate' => 'No next date',
      'NotFollowed' => 'Not followed up',
      _ => 'Paid up',
    };

Color statusColor(String s) => switch (s) {
      'Overdue' => AppColors.danger,
      'Today' => AppColors.warning,
      'Upcoming' => AppColors.info,
      'NoNextDate' => const Color(0xFF7C3AED),
      'NotFollowed' => AppColors.textSecondary,
      _ => AppColors.success,
    };

/// Fee follow-up summary: every student with pending fees or a follow-up, the latest follow-up (who, when, what), the next date
/// and the status. Tap a student for the full history and to add a follow-up. The top-right button exports Excel.
class FeeFollowupScreen extends StatefulWidget {
  const FeeFollowupScreen({super.key});
  @override
  State<FeeFollowupScreen> createState() => _FeeFollowupScreenState();
}

class _FeeFollowupScreenState extends State<FeeFollowupScreen> {
  final _service = FeeFollowupService();
  final _search = TextEditingController();
  Timer? _debounce;
  FollowupSummary? _data;
  String? _status, _outcome;
  DateTime? _from, _to;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = _data == null; _error = null; });
    try {
      final d = await _service.summary(q: _search.text, status: _status, outcome: _outcome, from: _from, to: _to);
      if (mounted) setState(() { _data = d; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _export() async {
    final url = _service.exportUrl(q: _search.text, status: _status, outcome: _outcome, from: _from, to: _to);
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnack(context, 'Could not open the Excel file.', isError: true);
  }

  Future<void> _pickDate(bool isFrom) async {
    final p = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (p != null) {
      setState(() { if (isFrom) { _from = p; } else { _to = p; } });
      _load();
    }
  }

  Widget _chip(String label, String? value) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(label: Text(label), selected: _status == value, onSelected: (_) { setState(() => _status = value); _load(); }),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final fmt = DateFormat('d MMM yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Follow-up'),
        actions: [IconButton(icon: const Icon(Icons.file_download_outlined), tooltip: 'Export to Excel', onPressed: _export)],
      ),
      body: Column(children: [
        ListSearchField(
          controller: _search,
          onChanged: (_) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 400), _load); },
          hint: 'Search student, phone, notes...',
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            _chip('All', null),
            _chip('Overdue${d == null ? '' : ' (${d.overdue})'}', 'Overdue'),
            _chip('Due today${d == null ? '' : ' (${d.today})'}', 'Today'),
            _chip('Upcoming${d == null ? '' : ' (${d.upcoming})'}', 'Upcoming'),
            _chip('No next date${d == null ? '' : ' (${d.noNextDate})'}', 'NoNextDate'),
            _chip('Not followed${d == null ? '' : ' (${d.notFollowed})'}', 'NotFollowed'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Row(children: [
            Expanded(
              child: AppDropdown<String?>(
                initialValue: _outcome,
                decoration: const InputDecoration(labelText: 'Outcome', isDense: true),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Any outcome')),
                  for (final o in FeeFollowupService.outcomes) DropdownMenuItem<String?>(value: o, child: Text(o)),
                ],
                onChanged: (v) { setState(() => _outcome = v); _load(); },
              ),
            ),
            const SizedBox(width: 8),
            ActionChip(label: Text(_from == null ? 'From' : fmt.format(_from!)), onPressed: () => _pickDate(true)),
            const SizedBox(width: 6),
            ActionChip(label: Text(_to == null ? 'To' : fmt.format(_to!)), onPressed: () => _pickDate(false)),
            if (_from != null || _to != null)
              IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { setState(() { _from = null; _to = null; }); _load(); }),
          ]),
        ),
        if (d != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${d.rows.length} students · balance ${money.format(d.totalBalance)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null && d == null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: d == null || d.rows.isEmpty
                          ? ListView(children: const [SizedBox(height: 60), EmptyState(message: 'No students found.', icon: Icons.phone_in_talk_outlined)])
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: d.rows.length,
                              itemBuilder: (_, i) => _tile(d.rows[i], money),
                            ),
                    ),
        ),
      ]),
    );
  }

  Widget _tile(FollowupRow r, NumberFormat money) {
    final l = r.last;
    final c = statusColor(r.status);
    final dt = DateFormat('d MMM, h:mm a');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
        border: Border(left: BorderSide(color: c, width: 4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FollowupStudentScreen(studentId: r.studentId)));
          if (mounted) _load();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(statusLabel(r.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
              ),
            ]),
            Text('${r.group}${r.phone.isEmpty ? '' : ' · ${r.phone}'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              'Balance ${money.format(r.balance)} · ${r.count} follow-up${r.count == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: r.balance > 0 ? AppColors.danger : AppColors.success),
            ),
            if (l != null) ...[
              const SizedBox(height: 4),
              Text(
                '${dt.format(l.at)} · by ${l.followedByName.isEmpty ? '-' : l.followedByName} · ${l.mode}${l.spokeTo == null ? '' : ' · spoke to ${l.spokeTo}'}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(l.outcome, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              if ((l.reason ?? '').isNotEmpty || (l.notes ?? '').isNotEmpty)
                Text(
                  [if ((l.reason ?? '').isNotEmpty) 'Reason: ${l.reason}', if ((l.notes ?? '').isNotEmpty) l.notes!].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              if (l.nextDate != null)
                Text(
                  'Next: ${DateFormat('d MMM yyyy').format(l.nextDate!)} (${l.nextDateBy == 'Parent' ? 'parent said' : 'we will call'})${(l.promisedAmount ?? 0) > 0 ? ' · promised ${money.format(l.promisedAmount)}' : ''}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Not followed up yet - tap to add the first follow-up', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
          ]),
        ),
      ),
    );
  }
}
