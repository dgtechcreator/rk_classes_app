import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../services/discontinued_service.dart';
import '../../services/lookup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Take a student off the roll: pick class / medium / batch, then the student, check the full picture, give the reason and save.
/// The student becomes Inactive and disappears from every count and list (same as the website).
class DiscontinueNewScreen extends StatefulWidget {
  const DiscontinueNewScreen({super.key});

  @override
  State<DiscontinueNewScreen> createState() => _DiscontinueNewScreenState();
}

class _DiscontinueNewScreenState extends State<DiscontinueNewScreen> {
  final _service = DiscontinuedService();
  final _lookup = LookupService();
  final _reason = TextEditingController();
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  List<LookupItem> _classes = [], _sections = [], _batches = [];
  int? _classId, _sectionId, _batchId, _studentId;
  List<DiscontinuePick> _students = [];
  bool _loadingStudents = false, _loadingOverview = false, _saving = false;
  DiscontinueOverview? _overview;
  String _kind = 'Left';
  DateTime _leftOn = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final r = await Future.wait([_lookup.getClasses(), _lookup.getSections(), _lookup.getBatches()]);
      if (mounted) setState(() { _classes = r[0]; _sections = r[1]; _batches = r[2]; });
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _loadStudents() async {
    setState(() { _students = []; _studentId = null; _overview = null; });
    if (_classId == null) return;
    setState(() => _loadingStudents = true);
    try {
      final list = await _service.getStudents(classId: _classId!, sectionId: _sectionId, batchId: _batchId);
      if (mounted) setState(() { _students = list; _loadingStudents = false; });
    } on ApiException catch (e) {
      if (mounted) { setState(() => _loadingStudents = false); showSnack(context, e.message, isError: true); }
    }
  }

  Future<void> _pickStudent(int? id) async {
    setState(() { _studentId = id; _overview = null; });
    if (id == null) return;
    setState(() => _loadingOverview = true);
    try {
      final o = await _service.getOverview(id);
      if (mounted && _studentId == id) setState(() { _overview = o; _loadingOverview = false; });
    } on ApiException catch (e) {
      if (mounted) { setState(() => _loadingOverview = false); showSnack(context, e.message, isError: true); }
    }
  }

  Future<void> _save() async {
    if (_studentId == null) return showSnack(context, 'Select a student first.', isError: true);
    if (_reason.text.trim().length < 3) return showSnack(context, 'Please write the reason.', isError: true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discontinue this student?'),
        content: const Text('They become inactive and disappear from every count and list. They can be taken back from Deleted Records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discontinue', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await _service.save(studentId: _studentId!, kind: _kind, reason: _reason.text.trim(), leftOn: _leftOn);
      if (!mounted) return;
      showSnack(context, 'Saved. The student is now inactive.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) { setState(() => _saving = false); showSnack(context, e.message, isError: true); }
    }
  }

  Widget _drop(String label, int? value, List<LookupItem> items, String allLabel, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [DropdownMenuItem<int?>(value: null, child: Text(allLabel)), for (final c in items) DropdownMenuItem<int?>(value: c.id, child: Text(c.name.trim()))],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Discontinue a Student')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          const Text('1. Select student', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _drop('Std / Class *', _classId, _classes, 'Select class', (v) { _classId = v; _loadStudents(); }),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _drop('Medium', _sectionId, _sections, 'All', (v) { _sectionId = v; _loadStudents(); })),
            const SizedBox(width: 10),
            Expanded(child: _drop('Batch', _batchId, _batches, 'All', (v) { _batchId = v; _loadStudents(); })),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            key: ValueKey('stu-$_classId-$_sectionId-$_batchId-${_students.length}'),
            initialValue: _studentId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Student *',
              helperText: _classId == null ? 'Select class first' : _loadingStudents ? 'Loading…' : '${_students.length} active students',
            ),
            items: [for (final s in _students) DropdownMenuItem<int?>(value: s.studentId, child: Text('${s.name} — ${s.admissionNo}', overflow: TextOverflow.ellipsis))],
            onChanged: _students.isEmpty ? null : _pickStudent,
          ),
          if (_loadingOverview) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (_overview != null) ...[
            const SizedBox(height: 18),
            const Text('2. Overview', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _overviewCard(_overview!),
            const SizedBox(height: 18),
            const Text('3. Why is the student leaving?', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _kindTile('Left', 'Left by student / parents', 'They decided to stop (shifted, other classes, personal reason…)'),
            const SizedBox(height: 8),
            _kindTile('Removed', 'Removed by institute', 'We removed the student (fees not paid, discipline…)'),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _leftOn, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)));
                if (d != null) setState(() => _leftOn = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                child: Text(DateFormat('dd MMM yyyy').format(_leftOn)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Reason *', hintText: 'Write the reason in your own words…', alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size.fromHeight(48)),
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_off_outlined),
              label: const Text('Discontinue & Save'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kindTile(String value, String title, String sub) {
    final on = _kind == value;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => setState(() => _kind = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? AppColors.infoSoft : AppColors.surface,
          border: Border.all(color: on ? AppColors.info : AppColors.borderNeutral, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? AppColors.info : AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
        ]),
      ),
    );
  }

  Widget _overviewCard(DiscontinueOverview o) {
    final att = o.attendance;
    final f = o.fee;
    double n(dynamic v) => v is num ? v.toDouble() : 0;
    Widget row(String l, String v, {Color? c, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
            Text(v, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(o.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text('${o.admissionNo} · ${o.classLine}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        if (o.fatherName.isNotEmpty || o.fatherPhone.isNotEmpty) Text('Father: ${o.fatherName} ${o.fatherPhone}', style: const TextStyle(fontSize: 12.5)),
        if (o.motherName.isNotEmpty || o.motherPhone.isNotEmpty) Text('Mother: ${o.motherName} ${o.motherPhone}', style: const TextStyle(fontSize: 12.5)),
        const Divider(height: 22),
        const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        if (att == null || n(att['totalDays']) == 0)
          const Text('No attendance recorded.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))
        else
          Text('${n(att['pct']).toStringAsFixed(1)}%  ·  Present ${att['presentDays']} · Absent ${att['absentDays']} · Late ${att['lateDays']} of ${att['totalDays']} days',
              style: const TextStyle(fontSize: 12.5)),
        const SizedBox(height: 10),
        const Text('Test marks', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(o.testsCount == 0 ? 'No marks entered.' : '${o.marksPct.toStringAsFixed(1)}% average over ${o.testsCount} test entries', style: const TextStyle(fontSize: 12.5)),
        const Divider(height: 22),
        const Text('Fees', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        row('Fee${n(f['additionalCharges']) > 0 ? ' + charges' : ''}', _money.format(n(f['baseFee']) + n(f['additionalCharges']))),
        if (n(f['discount']) > 0) row('Discount', '− ${_money.format(n(f['discount']))}', c: AppColors.textSecondary),
        row('Total to receive', _money.format(n(f['total'])), bold: true),
        row('Paid', _money.format(n(f['paid'])), c: AppColors.success),
        row('Pending', _money.format(o.balance), c: o.balance > 0.5 ? AppColors.danger : AppColors.success, bold: true),
        if (n(f['previousDue']) > 0.5) Text('Includes ${_money.format(n(f['previousDue']))} from earlier years.', style: const TextStyle(fontSize: 11.5, color: AppColors.warning)),
        if (o.payments.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Recent payments', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          for (final p in o.payments)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(children: [
                Expanded(child: Text('${DateFormat('dd MMM yyyy').format(DateTime.tryParse('${p['date']}') ?? DateTime.now())} · ${p['mode'] ?? ''}', style: const TextStyle(fontSize: 12))),
                Text(_money.format(n(p['amount'])), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
            ),
        ],
        if (o.balance > 0.5)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text('${_money.format(o.balance)} is still pending. It is saved in the record, and the student stops being counted in Finance.',
                style: const TextStyle(fontSize: 12, color: AppColors.warning)),
          ),
      ]),
    );
  }
}
