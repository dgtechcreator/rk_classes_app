import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../models/student.dart';
import '../../services/lookup_service.dart';
import '../../services/student_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Put students into one batch (e.g. split a combined 12th Commerce into "Commerce (Maths)" and
/// "Commerce (S P)"), so By-class attendance and every batch filter finds them.
class BatchAssignScreen extends StatefulWidget {
  const BatchAssignScreen({super.key, required this.batchId, required this.batchName});
  final int batchId;
  final String batchName;

  @override
  State<BatchAssignScreen> createState() => _BatchAssignScreenState();
}

class _BatchAssignScreenState extends State<BatchAssignScreen> {
  final _students = StudentService();
  final _lookup = LookupService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<LookupItem> _classes = [], _sections = [];
  int? _classId, _sectionId;
  List<Student> _list = [];
  final Set<int> _picked = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final c = await _lookup.getClasses();
      final s = await _lookup.getSections();
      if (!mounted) return;
      setState(() { _classes = c; _sections = s; });
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _students.getAll(search: _searchCtrl.text.trim(), classId: _classId, sectionId: _sectionId);
      if (!mounted) return;
      setState(() {
        _list = r.students;
        _picked.removeWhere((id) => !r.students.any((s) => s.studentId == id));
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  bool _inBatch(Student s) => s.batchId == widget.batchId;

  Future<void> _move() async {
    if (_picked.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move students'),
        content: Text('Move ${_picked.length} student(s) to "${widget.batchName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Move')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final n = await withLoader(context, () => _students.setBatch(_picked.toList(), widget.batchId));
      if (!mounted) return;
      showSnack(context, '$n student(s) moved to ${widget.batchName}.');
      _picked.clear();
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
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

  @override
  Widget build(BuildContext context) {
    final selectable = _list.where((s) => !_inBatch(s)).toList();
    final allPicked = selectable.isNotEmpty && selectable.every((s) => _picked.contains(s.studentId));
    return Scaffold(
      appBar: AppBar(title: Text('Assign to ${widget.batchName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(child: _dropdown('Class', _classId, _classes, (v) { setState(() => _classId = v); _load(); })),
                const SizedBox(width: 12),
                Expanded(child: _dropdown('Section', _sectionId, _sections, (v) { setState(() => _sectionId = v); _load(); })),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search name / admission no',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
              ),
            ),
          ),
          if (!_loading && _error == null && selectable.isNotEmpty)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: allPicked,
              title: Text('Select all (${selectable.length})'),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _picked.addAll(selectable.map((s) => s.studentId));
                } else {
                  _picked.clear();
                }
              }),
            ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _list.isEmpty
                        ? const EmptyState(message: 'No students found.', icon: Icons.people_outline)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: _list.length,
                            itemBuilder: (_, i) {
                              final s = _list[i];
                              final here = _inBatch(s);
                              final sub = [s.className, s.sectionName, s.batchName]
                                  .where((e) => e != null && e.isNotEmpty)
                                  .join(' · ');
                              return CheckboxListTile(
                                controlAffinity: ListTileControlAffinity.leading,
                                value: here || _picked.contains(s.studentId),
                                onChanged: here
                                    ? null
                                    : (v) => setState(() {
                                          if (v == true) {
                                            _picked.add(s.studentId);
                                          } else {
                                            _picked.remove(s.studentId);
                                          }
                                        }),
                                title: Text(s.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(here ? '$sub  ·  already in this batch' : sub,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: _picked.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: _move,
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: Text('Move ${_picked.length} to ${widget.batchName}'),
                ),
              ),
            ),
    );
  }
}
