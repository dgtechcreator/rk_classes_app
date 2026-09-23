import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/lookup.dart';
import '../../models/marks.dart';
import '../../services/lookup_service.dart';
import '../../services/marks_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Marks entry — mirrors MarksController.Index + Save. Pick year/class/section/batch/subject/exam
/// (typing a new exam name starts a new test; picking a suggestion reloads any marks already entered
/// for it), then key in each student's marks (or mark them Absent), respecting the subject's MaxMarks,
/// and Save All posts the batch in one MarksSaveReq.
class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  final _service = MarksService();
  final _lookup = LookupService();
  final _examCtrl = TextEditingController();
  Timer? _examDebounce;

  bool _loadingFilters = true;
  bool _loadingList = false;
  bool _saving = false;
  String? _filtersError;
  String? _listError;

  List<LookupItem> _years = [], _classes = [], _sections = [], _batches = [];
  List<Subject> _subjects = [];
  List<ExamOption> _examOptions = [];
  int? _yearId, _classId, _sectionId, _batchId, _subjectId;
  DateTime _testDate = DateTime.now();

  List<StudentMarkRow> _students = [];
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, bool> _absent = {};

  Subject? get _selectedSubject {
    for (final s in _subjects) {
      if (s.subjectId == _subjectId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void dispose() {
    _examDebounce?.cancel();
    _examCtrl.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFilters() async {
    setState(() { _loadingFilters = true; _filtersError = null; });
    try {
      final years = await _lookup.getYears();
      final classes = await _lookup.getClasses();
      final sections = await _lookup.getSections();
      final batches = await _lookup.getBatches();
      final exams = await _lookup.getExams();
      if (!mounted) return;
      setState(() {
        _years = years; _classes = classes; _sections = sections; _batches = batches;
        _examOptions = exams;
        _yearId ??= years.firstWhere((y) => y.isActive, orElse: () => years.isNotEmpty ? years.first : LookupItem(id: 0, name: '')).id;
        _loadingFilters = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _filtersError = e.message; _loadingFilters = false; });
    }
  }

  Future<void> _onClassChanged(int? v) async {
    setState(() { _classId = v; _sectionId = null; _batchId = null; _subjectId = null; _subjects = []; _students = []; });
    if (v == null) return;
    try {
      final subs = await _lookup.getSubjects(v);
      if (!mounted) return;
      setState(() {
        _subjects = subs;
        if (subs.length == 1) _subjectId = subs.first.subjectId;
      });
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
    _reload();
  }

  Future<void> _reload() async {
    if (_classId == null) {
      setState(() { _students = []; _listError = null; });
      return;
    }
    setState(() { _loadingList = true; _listError = null; });
    try {
      final data = await _service.getEntryData(
        yearId: _yearId, classId: _classId, sectionId: _sectionId, batchId: _batchId,
        subjectId: _subjectId, examName: _examCtrl.text.trim(), testDate: _testDate,
        maxMarks: _selectedSubject?.maxMarks ?? 100,
      );
      if (!mounted) return;
      setState(() {
        _students = data.students;
        if (data.examList.isNotEmpty) _examOptions = data.examList;
        _rebuildControllers();
        _loadingList = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _listError = e.message; _loadingList = false; });
    }
  }

  void _rebuildControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _absent.clear();
    for (final s in _students) {
      _controllers[s.studentId] = TextEditingController(text: s.marksObtained == null ? '' : _trimNum(s.marksObtained!));
      _absent[s.studentId] = s.isAbsent;
    }
  }

  String _trimNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _onExamChanged(String _) {
    _examDebounce?.cancel();
    _examDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_classId != null && _subjectId != null) _reload();
    });
  }

  void _pickExam(String name) {
    setState(() => _examCtrl.text = name);
    _examDebounce?.cancel();
    if (_classId != null && _subjectId != null) _reload();
  }

  Future<void> _pickTestDate() async {
    final picked = await showDatePicker(context: context, initialDate: _testDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked == null) return;
    setState(() => _testDate = picked);
  }

  int get _enteredCount => _students.where((s) => (_absent[s.studentId] ?? false) || (_controllers[s.studentId]?.text.trim().isNotEmpty ?? false)).length;

  Future<void> _saveAll() async {
    if (_students.isEmpty) return;
    final subject = _selectedSubject;
    if (subject == null) { showSnack(context, 'Pick a subject first.', isError: true); return; }
    final examName = _examCtrl.text.trim();
    if (examName.isEmpty) { showSnack(context, 'Enter an exam/test name.', isError: true); return; }

    final entries = <Map<String, dynamic>>[];
    for (final s in _students) {
      final isAbsent = _absent[s.studentId] ?? false;
      final text = _controllers[s.studentId]?.text.trim() ?? '';
      double? marks;
      if (!isAbsent) {
        if (text.isEmpty) continue;
        marks = double.tryParse(text);
        if (marks == null || marks < 0 || marks > subject.maxMarks) {
          showSnack(context, '${s.fullName}: marks must be between 0 and ${subject.maxMarks}.', isError: true);
          return;
        }
      }
      entries.add({'studentId': s.studentId, 'subjectId': subject.subjectId, 'marks': marks ?? 0, 'isAbsent': isAbsent});
    }
    if (entries.isEmpty) { showSnack(context, 'Enter marks for at least one student.', isError: true); return; }

    setState(() => _saving = true);
    try {
      final message = await _service.save(
        examName: examName, classId: _classId!, yearId: _yearId ?? 0,
        maxMarks: subject.maxMarks, testDate: _testDate, entries: entries,
      );
      if (mounted) { showSnack(context, message); _reload(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.hasPerm('marks_entry')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Marks Entry')),
        body: const EmptyState(message: 'You do not have permission to enter marks.', icon: Icons.lock_outline),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Marks Entry')),
      body: _loadingFilters
          ? const LoadingView()
          : _filtersError != null
              ? ErrorView(message: _filtersError!, onRetry: _loadFilters)
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        children: [
                          _buildFilters(),
                          const SizedBox(height: 12),
                          _buildBody(),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _students.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveAll,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save All ($_enteredCount / ${_students.length})'),
                ),
              ),
            ),
    );
  }

  Widget _buildFilters() {
    final relevantExams = _examOptions.where((e) => _classId == null || e.classId == null || e.classId == _classId).toList();
    final examNames = <String>{...relevantExams.map((e) => e.examName)}.where((n) => n.isNotEmpty).take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _dropdown('Year', _yearId, _years, (v) { setState(() => _yearId = v); _reload(); })),
                const SizedBox(width: 12),
                Expanded(child: _dropdown('Class', _classId, _classes, _onClassChanged)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dropdown('Section', _sectionId, _sections, (v) { setState(() => _sectionId = v); _reload(); })),
                const SizedBox(width: 12),
                Expanded(child: _dropdown('Batch', _batchId, _batches, (v) { setState(() => _batchId = v); _reload(); })),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
      isExpanded: true,
              initialValue: _subjects.any((s) => s.subjectId == _subjectId) ? _subjectId : null,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: _subjects.map((s) => DropdownMenuItem<int?>(value: s.subjectId, child: Text('${s.subjectName} (max ${s.maxMarks})'))).toList(),
              onChanged: _classId == null ? null : (v) { setState(() => _subjectId = v); _reload(); },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _examCtrl,
              onChanged: _onExamChanged,
              decoration: const InputDecoration(labelText: 'Exam / Test Name', hintText: 'e.g. Unit Test 1, Half Yearly...'),
            ),
            if (examNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: examNames.map((n) => ActionChip(label: Text(n), onPressed: () => _pickExam(n))).toList(),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTestDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Test Date', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                child: Text(DateFormat.yMMMd().format(_testDate)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildBody() {
    if (_classId == null) {
      return const EmptyState(message: 'Pick a class to load students.', icon: Icons.groups_outlined);
    }
    if (_loadingList) return const LoadingView();
    if (_listError != null) return ErrorView(message: _listError!, onRetry: _reload);
    if (_students.isEmpty) {
      return const EmptyState(message: 'No students found for this class/section/batch.', icon: Icons.groups_outlined);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in _students) ...[
          _MarkEntryTile(
            student: s,
            controller: _controllers[s.studentId]!,
            isAbsent: _absent[s.studentId] ?? false,
            maxMarks: _selectedSubject?.maxMarks ?? s.maxMarks,
            onAbsentChanged: (v) => setState(() => _absent[s.studentId] = v),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MarkEntryTile extends StatelessWidget {
  const _MarkEntryTile({
    required this.student, required this.controller, required this.isAbsent, required this.maxMarks, required this.onAbsentChanged,
  });
  final StudentMarkRow student;
  final TextEditingController controller;
  final bool isAbsent;
  final int maxMarks;
  final ValueChanged<bool> onAbsentChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  Text(student.rollNo?.isNotEmpty == true ? '${student.admissionNo} • Roll ${student.rollNo}' : student.admissionNo,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
              width: 72,
              child: TextField(
                controller: controller,
                enabled: !isAbsent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(hintText: '/$maxMarks', isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8)),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(value: isAbsent, onChanged: (v) => onAbsentChanged(v ?? false)),
                const Text('Absent', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
