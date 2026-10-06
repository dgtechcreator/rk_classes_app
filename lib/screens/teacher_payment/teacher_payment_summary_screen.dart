import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/teacher_payment.dart';
import '../../services/teacher_payment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Teacher-payment summary. Admin / accountant ([mine] = false): filter by year, month, teacher and status and
/// see totals plus a per-teacher breakdown. A teacher ([mine] = true): only their own payments — when each
/// month's payment was made — with no filters on other people.
class TeacherPaymentSummaryScreen extends StatefulWidget {
  const TeacherPaymentSummaryScreen({super.key, this.mine = false, @visibleForTesting this.service});
  final bool mine;
  final TeacherPaymentService? service;

  @override
  State<TeacherPaymentSummaryScreen> createState() => _TeacherPaymentSummaryScreenState();
}

class _TeacherPaymentSummaryScreenState extends State<TeacherPaymentSummaryScreen> {
  late final TeacherPaymentService _service = widget.service ?? TeacherPaymentService();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _months = [for (var m = 1; m <= 12; m++) DateFormat('MMMM').format(DateTime(2000, m))];

  bool _loading = true;
  String? _error;
  TeacherPaymentReport? _report;
  List<TeacherPayment> _all = [];

  late int _year = widget.mine ? 0 : DateTime.now().year; // 0 = all years
  int _month = 0; // 0 = whole year
  int? _facultyId;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetches EVERYTHING once (all years) — the dataset is small — and every filter below is applied on the
  /// phone. Filter taps are therefore instant, never show a spinner and can never leave stale rows behind
  /// because a request failed. Pull-to-refresh / Retry re-fetch.
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = widget.mine ? await _service.getMine() : await _service.getSummary(year: 0);
      if (!mounted) return;
      if (!r.hasPayments) {
        setState(() { _error = 'The server needs to be updated to show the payment summary.'; _loading = false; });
        return;
      }
      setState(() { _report = r; _all = r.payments; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load payments. Please try again.'; _loading = false; });
    }
  }

  List<TeacherPayment> get _filtered {
    final list = _all.where((p) {
      if (_year > 0 && p.paymentYear != _year) return false;
      if (_month > 0 && p.paymentMonth != _month) return false;
      if (_facultyId != null && p.facultyId != _facultyId) return false;
      if (_status == 'paid' && !p.isPaid) return false;
      if (_status == 'pending' && p.isPaid) return false;
      return true;
    }).toList();
    // newest period first, then most recently paid
    list.sort((a, b) {
      final c = (b.paymentYear * 12 + b.paymentMonth).compareTo(a.paymentYear * 12 + a.paymentMonth);
      if (c != 0) return c;
      return (b.paymentDate ?? DateTime(9999)).compareTo(a.paymentDate ?? DateTime(9999));
    });
    return list;
  }

  TeacherPaymentSummary _summarize(List<TeacherPayment> list) {
    double sumOf(Iterable<TeacherPayment> l) => l.fold(0.0, (a, p) => a + p.totalAmount);
    final byTeacher = <int, List<TeacherPayment>>{};
    for (final p in list) { byTeacher.putIfAbsent(p.facultyId, () => []).add(p); }
    final teachers = byTeacher.entries.map((e) {
      final paid = e.value.where((p) => p.isPaid);
      final dates = paid.map((p) => p.paymentDate).whereType<DateTime>().toList()..sort();
      return TeacherPaymentTeacherRow(
        facultyId: e.key,
        facultyName: e.value.first.facultyName.trim(),
        count: e.value.length,
        paidAmount: sumOf(paid),
        pendingAmount: sumOf(e.value.where((p) => !p.isPaid)),
        lastPaidOn: dates.isEmpty ? null : dates.last,
      );
    }).toList()
      ..sort((a, b) {
        final c = (b.paidAmount + b.pendingAmount).compareTo(a.paidAmount + a.pendingAmount);
        return c != 0 ? c : a.facultyName.compareTo(b.facultyName);
      });
    return TeacherPaymentSummary(
      count: list.length,
      paidCount: list.where((p) => p.isPaid).length,
      pendingCount: list.where((p) => !p.isPaid).length,
      totalAmount: sumOf(list),
      paidAmount: sumOf(list.where((p) => p.isPaid)),
      pendingAmount: sumOf(list.where((p) => !p.isPaid)),
      teachers: teachers,
    );
  }

  void _setFilter(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mine ? 'My Payments' : 'Payment Summary')),
      body: _loading && _report == null
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final r = _report!;
    if (widget.mine && !r.linked) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.link_off_rounded, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(r.message ?? 'Your login is not linked to a faculty profile yet.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        ],
      );
    }
    final pays = _filtered;
    final s = _summarize(pays);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (widget.mine && (r.facultyName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(r.facultyName!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          _filters(r),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatCard(label: widget.mine ? 'Total' : 'Total Payments', value: _money.format(s.totalAmount), color: AppColors.info, icon: Icons.receipt_long_outlined)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Paid · ${s.paidCount}', value: _money.format(s.paidAmount), color: AppColors.success, icon: Icons.check_circle_outline)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: StatCard(label: 'Pending · ${s.pendingCount}', value: _money.format(s.pendingAmount), color: s.pendingAmount > 0 ? AppColors.warning : AppColors.success, icon: Icons.hourglass_bottom_rounded)),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: widget.mine ? 'Entries' : 'Teachers',
                  value: widget.mine ? '${s.count}' : '${s.teachers.length}',
                  color: AppColors.violet,
                  icon: widget.mine ? Icons.list_alt_rounded : Icons.groups_outlined,
                ),
              ),
            ],
          ),
          if (!widget.mine && s.teachers.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'By Teacher'),
            for (final t in s.teachers) _teacherRow(t),
          ],
          const SizedBox(height: 20),
          SectionHeader(title: widget.mine ? 'Payment History (${pays.length})' : 'Payments (${pays.length})'),
          if (pays.isEmpty)
            const EmptyState(message: 'No payments for this selection.', icon: Icons.currency_rupee)
          else
            for (final p in pays) _paymentCard(p),
        ],
      ),
    );
  }

  Widget _filters(TeacherPaymentReport r) {
    final years = {..._all.map((p) => p.paymentYear), DateTime.now().year}.toList()..sort((a, b) => b.compareTo(a));
    final yearItems = [
      const DropdownMenuItem(value: 0, child: Text('All years')),
      for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
    ];
    if (widget.mine) {
      return DropdownButtonFormField<int>(
        isExpanded: true,
        initialValue: yearItems.any((e) => e.value == _year) ? _year : 0,
        decoration: const InputDecoration(labelText: 'Year', isDense: true),
        items: yearItems,
        onChanged: (v) => _setFilter(() => _year = v ?? 0),
      );
    }
    final faculty = [...r.faculty]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _year == 0 || years.contains(_year) ? _year : 0,
                decoration: const InputDecoration(labelText: 'Year', isDense: true),
                items: yearItems,
                onChanged: (v) => _setFilter(() => _year = v ?? 0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _month,
                decoration: const InputDecoration(labelText: 'Month', isDense: true),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('All months')),
                  for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(_months[m - 1])),
                ],
                onChanged: (v) => _setFilter(() => _month = v ?? 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: faculty.any((f) => f.id == _facultyId) ? _facultyId : null,
          decoration: const InputDecoration(labelText: 'Teacher', isDense: true),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('All teachers')),
            for (final f in faculty) DropdownMenuItem<int?>(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => _setFilter(() => _facultyId = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final o in const [('all', 'All'), ('paid', 'Paid'), ('pending', 'Pending')]) ...[
              ChoiceChip(
                label: Text(o.$2),
                selected: _status == o.$1,
                onSelected: (_) => _setFilter(() => _status = o.$1),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _teacherRow(TeacherPaymentTeacherRow t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _setFilter(() => _facultyId = t.facultyId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySoft,
                child: Text(t.facultyName.isNotEmpty ? t.facultyName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.facultyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${t.count} ${t.count == 1 ? 'entry' : 'entries'}${t.lastPaidOn != null ? ' · last paid ${DateFormat('dd MMM yyyy').format(t.lastPaidOn!)}' : ''}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money.format(t.paidAmount), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
                  if (t.pendingAmount > 0) Text('${_money.format(t.pendingAmount)} pending', style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentCard(TeacherPayment p) {
    final paidLine = p.isPaid
        ? 'Paid on ${p.paymentDate == null ? '—' : DateFormat('dd MMM yyyy').format(p.paymentDate!)}${(p.paymentMode ?? '').isNotEmpty ? ' · ${p.paymentMode}' : ''}'
        : 'Payment pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.mine) Text(p.facultyName.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(p.monthYearLabel, style: TextStyle(fontWeight: widget.mine ? FontWeight.w800 : FontWeight.w500, fontSize: widget.mine ? 15 : 13)),
                  const SizedBox(height: 2),
                  Text(
                    '${p.typeLabel}${p.paymentType != 'Fixed' && p.quantity != null ? ' · ${p.quantity!.toStringAsFixed(p.quantity! % 1 == 0 ? 0 : 1)} × ${_money.format(p.rate)}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(paidLine, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.isPaid ? AppColors.success : AppColors.warning)),
                  if ((p.receiptNo ?? '').isNotEmpty) Text('Receipt ${p.receiptNo}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_money.format(p.totalAmount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                StatusBadge(status: p.statusLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
