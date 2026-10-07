import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/masters.dart';
import '../../services/masters_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Masters → Attendance Batches (mirrors Masters/AttendanceBatches on the web): named groups of students
/// such as "5th English Morning" that show up as green / light-red cards on the Attendance screen.
class AttendanceBatchesTab extends StatefulWidget {
  const AttendanceBatchesTab({super.key});

  @override
  State<AttendanceBatchesTab> createState() => _AttendanceBatchesTabState();
}

class _AttendanceBatchesTabState extends State<AttendanceBatchesTab> {
  final _service = MastersService();
  bool _loading = true;
  String? _error;
  List<AttendanceBatchInfo> _batches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _service.getAttendanceBatches();
      if (mounted) setState(() { _batches = list; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _open([AttendanceBatchInfo? batch]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AttendanceBatchEditScreen(batch: batch)));
    if (saved == true) _load();
  }

  Future<void> _delete(AttendanceBatchInfo b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete batch?'),
        content: Text('"${b.batchName}" will be removed from the attendance cards. Past attendance is not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteAttendanceBatch(b.batchId);
      if (mounted) { showSnack(context, 'Batch deleted.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('New Batch'),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _batches.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 60),
                          EmptyState(message: 'No attendance batches yet.\nTap "New Batch" to group students for quick attendance.', icon: Icons.layers_outlined),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                          itemCount: _batches.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final b = _batches[i];
                            return Card(
                              child: ListTile(
                                onTap: () => _open(b),
                                leading: const CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(Icons.layers_outlined, color: AppColors.primary)),
                                title: Text(b.batchName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${b.studentCount} students'),
                                trailing: IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                  onPressed: () => _delete(b),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

/// Create / edit one attendance batch: name + the students that belong to it. The class / medium / batch
/// filters only narrow the list being shown — students ticked under one filter stay ticked when the
/// filter changes, so one batch can mix classes.
class AttendanceBatchEditScreen extends StatefulWidget {
  const AttendanceBatchEditScreen({super.key, this.batch});
  final AttendanceBatchInfo? batch;

  @override
  State<AttendanceBatchEditScreen> createState() => _AttendanceBatchEditScreenState();
}

class _AttendanceBatchEditScreenState extends State<AttendanceBatchEditScreen> {
  final _service = MastersService();
  final _name = TextEditingController();

  bool _loadingLookups = true;
  bool _loadingStudents = false;
  bool _saving = false;
  String? _error;

  List<SchoolClass> _classes = [];
  List<SchoolSection> _sections = [];
  List<SchoolBatch> _batches = [];
  int? _classId, _sectionId, _batchId;

  List<BatchStudentOption> _shown = [];
  final Set<int> _selected = {};

  bool get _isEdit => widget.batch != null;

  @override
  void initState() {
    super.initState();
    if (widget.batch != null) {
      _name.text = widget.batch!.batchName;
      _selected.addAll(widget.batch!.studentIds);
    }
    _loadLookups();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() { _loadingLookups = true; _error = null; });
    try {
      final classes = await _service.getClasses();
      final sections = await _service.getSections();
      final batches = await _service.getBatches();
      if (!mounted) return;
      setState(() { _classes = classes; _sections = sections; _batches = batches; _loadingLookups = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loadingLookups = false; });
    }
  }

  Future<void> _loadStudents() async {
    if (_classId == null && _sectionId == null && _batchId == null) {
      setState(() => _shown = []);
      return;
    }
    setState(() => _loadingStudents = true);
    try {
      final list = await _service.getStudentsForAttendanceBatch(classId: _classId, sectionId: _sectionId, batchId: _batchId);
      if (mounted) setState(() { _shown = list; _loadingStudents = false; });
    } on ApiException catch (e) {
      if (mounted) { setState(() => _loadingStudents = false); showSnack(context, e.message, isError: true); }
    }
  }

  bool get _allShownSelected => _shown.isNotEmpty && _shown.every((s) => _selected.contains(s.studentId));

  void _toggleAllShown(bool on) => setState(() {
        for (final s in _shown) {
          on ? _selected.add(s.studentId) : _selected.remove(s.studentId);
        }
      });

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) { showSnack(context, 'Please enter a batch name.', isError: true); return; }
    if (_selected.isEmpty) { showSnack(context, 'Select at least one student.', isError: true); return; }
    setState(() => _saving = true);
    try {
      await _service.saveAttendanceBatch(batchId: widget.batch?.batchId ?? 0, batchName: name, studentIds: _selected.toList());
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Batch updated.' : 'Batch "$name" created with ${_selected.length} students.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dropdown<T>(String label, int? value, List<T> items, int Function(T) idOf, String Function(T) nameOf, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: items.any((e) => idOf(e) == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: idOf(e), child: Text(nameOf(e).trim(), overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Attendance Batch' : 'New Attendance Batch')),
      body: _loadingLookups
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _loadLookups)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Batch name *', hintText: 'e.g. 9TH ENGLISH MORNING'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _dropdown<SchoolClass>('Class', _classId, _classes, (c) => c.classId, (c) => c.className, (v) { setState(() => _classId = v); _loadStudents(); })),
                        const SizedBox(width: 12),
                        Expanded(child: _dropdown<SchoolSection>('Medium', _sectionId, _sections, (s) => s.sectionId, (s) => s.sectionName, (v) { setState(() => _sectionId = v); _loadStudents(); })),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dropdown<SchoolBatch>('Batch', _batchId, _batches, (b) => b.batchId, (b) => b.batchName, (v) { setState(() => _batchId = v); _loadStudents(); }),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text('${_selected.length} selected in this batch',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        if (_shown.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _toggleAllShown(!_allShownSelected),
                            icon: Icon(_allShownSelected ? Icons.check_box : Icons.check_box_outline_blank, size: 20),
                            label: Text(_allShownSelected ? 'Unselect shown' : 'Select all shown'),
                          ),
                      ],
                    ),
                    if (_loadingStudents)
                      const LoadingView()
                    else if (_shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Text('Pick a class, medium or batch above to list students.',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      for (final s in _shown)
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: CheckboxListTile(
                            dense: true,
                            value: _selected.contains(s.studentId),
                            onChanged: (v) => setState(() => v == true ? _selected.add(s.studentId) : _selected.remove(s.studentId)),
                            title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(s.details, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isEdit ? 'Save Changes' : 'Create Batch'),
          ),
        ),
      ),
    );
  }
}
