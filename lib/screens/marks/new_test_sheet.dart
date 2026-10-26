import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../models/marks.dart';
import '../../theme/app_theme.dart';

/// What the "New Test" sheet hands back: everything needed to open the marks grid for one subject of one test.
class NewTestResult {
  NewTestResult({
    required this.name,
    required this.classId,
    required this.subjectId,
    required this.date,
    required this.maxMarks,
    this.sectionId,
    this.batchId,
  });

  final String name;
  final int classId;
  final int subjectId;
  final int? sectionId;
  final int? batchId;
  final DateTime date;
  final int maxMarks;
}

/// "New Test" - test name, Std, subject, optional medium / batch, date and total marks, in one place (the website has the
/// same dialog). Nothing is stored yet: the test comes into existence when the first marks are saved.
class NewTestSheet extends StatefulWidget {
  const NewTestSheet({
    super.key,
    required this.classes,
    required this.sections,
    required this.batches,
    required this.existing,
    required this.loadSubjects,
    this.initialClassId,
    this.initialSectionId,
    this.initialBatchId,
  });

  final List<LookupItem> classes, sections, batches;
  final List<ExamOption> existing;
  final Future<List<Subject>> Function(int classId) loadSubjects;
  final int? initialClassId, initialSectionId, initialBatchId;

  @override
  State<NewTestSheet> createState() => _NewTestSheetState();
}

class _NewTestSheetState extends State<NewTestSheet> {
  final _name = TextEditingController();
  final _max = TextEditingController(text: '30');
  int? _classId, _sectionId, _batchId, _subjectId;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<Subject> _subjects = [];
  bool _loadingSubjects = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sectionId = widget.initialSectionId;
    _batchId = widget.initialBatchId;
    if (widget.initialClassId != null) _pickClass(widget.initialClassId);
  }

  @override
  void dispose() {
    _name.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickClass(int? id) async {
    setState(() { _classId = id; _subjectId = null; _subjects = []; _error = null; });
    if (id == null) return;
    setState(() => _loadingSubjects = true);
    try {
      final subs = await widget.loadSubjects(id);
      if (!mounted) return;
      setState(() {
        _subjects = subs;
        if (subs.length == 1) _subjectId = subs.first.subjectId;
        _loadingSubjects = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loadingSubjects = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _start() async {
    final name = _name.text.trim();
    final max = int.tryParse(_max.text.trim());
    String? err;
    if (name.isEmpty) {
      err = 'Please enter the test name.';
    } else if (_classId == null) {
      err = 'Please select the Std.';
    } else if (_subjectId == null) {
      err = 'Please select the subject.';
    } else if (max == null || max < 1 || max > 200) {
      err = 'Total marks must be between 1 and 200.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    // A test is identified by its name + Std: re-using a name opens that test (and keeps its original total).
    var useName = name, useMax = max!, useDate = _date;
    ExamOption? same;
    for (final e in widget.existing) {
      if (e.examName.toLowerCase() == name.toLowerCase() && e.classId == _classId) { same = e; break; }
    }
    if (same != null) {
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Test already exists'),
          content: Text('A test named "${same!.examName}" already exists for this Std'
              '${same.maxMarks != null ? ' (out of ${same.maxMarks})' : ''}. Open it and add or edit the marks for this subject?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open it')),
          ],
        ),
      );
      if (open != true || !mounted) return;
      useName = same.examName;
      if (same.maxMarks != null) useMax = same.maxMarks!;
      if (same.testDate != null) useDate = DateUtils.dateOnly(same.testDate!);
    }

    Navigator.pop(
      context,
      NewTestResult(name: useName, classId: _classId!, subjectId: _subjectId!, sectionId: _sectionId, batchId: _batchId, date: useDate, maxMarks: useMax),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Add New Test', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Test name *', hintText: 'e.g. Unit Test 1, Weekly Test'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: widget.classes.any((c) => c.id == _classId) ? _classId : null,
                      decoration: const InputDecoration(labelText: 'Std *'),
                      items: widget.classes.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: _pickClass,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('subject-$_classId-${_subjects.length}'),
                      isExpanded: true,
                      initialValue: _subjects.any((s) => s.subjectId == _subjectId) ? _subjectId : null,
                      decoration: InputDecoration(labelText: 'Subject *', helperText: _loadingSubjects ? 'Loading...' : (_classId != null && _subjects.isEmpty ? 'No subjects found' : null)),
                      items: _subjects.map((s) => DropdownMenuItem<int?>(value: s.subjectId, child: Text(s.subjectName, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: _classId == null ? null : (v) => setState(() { _subjectId = v; _error = null; }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _optional('Medium / Stream', _sectionId, widget.sections, (v) => setState(() => _sectionId = v))),
                  const SizedBox(width: 12),
                  Expanded(child: _optional('Batch', _batchId, widget.batches, (v) => setState(() => _batchId = v))),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Test date *', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                  child: Text(DateFormat.yMMMd().format(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  labelText: 'Total marks (out of) *',
                  errorText: (() {
                    final v = int.tryParse(_max.text.trim());
                    return (v == null || v < 1 || v > 200) ? 'Enter a number from 1 to 200' : null;
                  })(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [10, 20, 25, 30, 40, 50, 100]
                    .map((m) => ActionChip(label: Text('$m'), visualDensity: VisualDensity.compact, onPressed: () => setState(() => _max.text = '$m')))
                    .toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Next you enter each student\'s marks obtained (or mark Absent) and press Save All. Other subjects of the same test can be added afterwards.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Start Entering Marks'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optional(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: '$label (optional)'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }
}
