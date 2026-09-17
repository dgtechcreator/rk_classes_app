import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/lookup.dart';
import '../../models/student.dart';
import '../../services/lookup_service.dart';
import '../../services/student_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'student_detail_screen.dart';
import 'student_form_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _service = StudentService();
  final _lookup = LookupService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<Student> _students = [];
  int _total = 0;

  List<LookupItem> _classes = [];
  List<LookupItem> _sections = [];
  List<LookupItem> _batches = [];
  int? _classId, _sectionId, _batchId;
  String _status = 'Active';

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final classes = await _lookup.getClasses();
      final sections = await _lookup.getSections();
      final batches = await _lookup.getBatches();
      if (mounted) setState(() { _classes = classes; _sections = sections; _batches = batches; });
    } catch (_) {
      // Filters are a convenience — the list still works without them.
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getAll(
        search: _searchCtrl.text.trim(),
        classId: _classId, sectionId: _sectionId, batchId: _batchId,
        status: _status,
      );
      setState(() { _students = result.students; _total = result.total; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        classes: _classes, sections: _sections, batches: _batches,
        classId: _classId, sectionId: _sectionId, batchId: _batchId, status: _status,
        onApply: (classId, sectionId, batchId, status) {
          setState(() { _classId = classId; _sectionId = sectionId; _batchId = batchId; _status = status; });
          _load();
        },
      ),
    );
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const StudentFormScreen()));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasEditPerm('student');
    final hasActiveFilters = _classId != null || _sectionId != null || _batchId != null || _status != 'Active';

    return Scaffold(
      appBar: AppBar(
        title: Text('Students${_total > 0 ? ' ($_total)' : ''}'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: hasActiveFilters ? AppColors.primary : null),
            tooltip: 'Filter',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      floatingActionButton: canEdit ? FloatingActionButton(onPressed: _openCreate, child: const Icon(Icons.add)) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or admission no...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close), onPressed: () { _searchCtrl.clear(); _load(); })
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _students.isEmpty
                        ? const EmptyState(message: 'No students found.', icon: Icons.groups_outlined)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                              itemCount: _students.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _StudentTile(student: _students[i], onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: _students[i].studentId)));
                                _load();
                              }),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.onTap});
  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Text(student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${student.admissionNo} • ${student.classLabel}'),
        trailing: student.status != 'Active' ? StatusBadge(status: student.status) : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.classes, required this.sections, required this.batches,
    required this.classId, required this.sectionId, required this.batchId, required this.status,
    required this.onApply,
  });
  final List<LookupItem> classes, sections, batches;
  final int? classId, sectionId, batchId;
  final String status;
  final void Function(int?, int?, int?, String) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  int? _classId, _sectionId, _batchId;
  late String _status;

  @override
  void initState() {
    super.initState();
    _classId = widget.classId; _sectionId = widget.sectionId; _batchId = widget.batchId; _status = widget.status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filter Students', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _dropdown('Class', _classId, widget.classes, (v) => setState(() => _classId = v)),
          const SizedBox(height: 12),
          _dropdown('Section', _sectionId, widget.sections, (v) => setState(() => _sectionId = v)),
          const SizedBox(height: 12),
          _dropdown('Batch', _batchId, widget.batches, (v) => setState(() => _batchId = v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'Active'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () { setState(() { _classId = null; _sectionId = null; _batchId = null; _status = 'Active'; }); },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { widget.onApply(_classId, _sectionId, _batchId, _status); Navigator.of(context).pop(); },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))),
      ],
      onChanged: onChanged,
    );
  }
}
