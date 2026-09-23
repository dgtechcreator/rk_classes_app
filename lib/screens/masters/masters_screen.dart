import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/masters.dart';
import '../../services/masters_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Single admin settings screen mirroring MastersController.Index, which shows Academic Years,
/// Classes, Sections, Batches, Subjects and Expense Categories together on one page — here as tabs
/// instead of stacked sections. Any logged-in staff member can use this (MastersApiController write
/// endpoints are bare [ApiRequireStaff], matching the real MVC controller's bare [RequireLogin]), so
/// there's no permission gating beyond having reached this screen at all.
class MastersScreen extends StatefulWidget {
  const MastersScreen({super.key});

  @override
  State<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends State<MastersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = MastersService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masters'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Years'),
            Tab(text: 'Classes'),
            Tab(text: 'Sections'),
            Tab(text: 'Batches'),
            Tab(text: 'Subjects'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _YearsTab(),
          const _ClassesTab(),
          _SimpleNameTab<SchoolSection>(
            emptyMessage: 'No sections found.',
            emptyIcon: Icons.view_column_outlined,
            addLabel: 'Add Section',
            countLabel: 'students',
            loader: _service.getSections,
            idOf: (s) => s.sectionId,
            nameOf: (s) => s.sectionName,
            activeOf: (s) => s.isActive,
            countOf: (s) => s.studentCount,
            onSave: (id, name, isActive) => _service.saveSection(sectionId: id, sectionName: name, isActive: isActive),
            onDelete: _service.deleteSection,
          ),
          _SimpleNameTab<SchoolBatch>(
            emptyMessage: 'No batches found.',
            emptyIcon: Icons.groups_2_outlined,
            addLabel: 'Add Batch',
            countLabel: 'students',
            loader: _service.getBatches,
            idOf: (b) => b.batchId,
            nameOf: (b) => b.batchName,
            activeOf: (b) => b.isActive,
            countOf: (b) => b.studentCount,
            onSave: (id, name, isActive) => _service.saveBatch(batchId: id, batchName: name, isActive: isActive),
            onDelete: _service.deleteBatch,
          ),
          const _SubjectsTab(),
          _SimpleNameTab<ExpenseCategory>(
            emptyMessage: 'No expense categories found.',
            emptyIcon: Icons.request_quote_outlined,
            addLabel: 'Add Expense Category',
            countLabel: 'uses',
            loader: _service.getExpenseCats,
            idOf: (c) => c.categoryId,
            nameOf: (c) => c.categoryName,
            activeOf: (c) => c.isActive,
            countOf: (c) => c.usageCount,
            onSave: (id, name, isActive) => _service.saveExpenseCat(categoryId: id, categoryName: name, isActive: isActive),
            onDelete: _service.deleteExpenseCat,
          ),
        ],
      ),
    );
  }
}

Widget _formSheet({
  required BuildContext context,
  required String title,
  required List<Widget> fields,
}) {
  return Container(
    padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
    decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...fields,
      ],
    ),
  );
}

/// Reusable CRUD list for the master entities that are just a name + isActive flag
/// (Section, Batch, Expense Category). Years and Classes have one extra field each so they get
/// their own tab widgets below instead of a generic that would need to grow more parameters than
/// it's worth.
class _SimpleNameTab<T> extends StatefulWidget {
  const _SimpleNameTab({
    super.key,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.addLabel,
    required this.countLabel,
    required this.loader,
    required this.idOf,
    required this.nameOf,
    required this.activeOf,
    required this.countOf,
    required this.onSave,
    required this.onDelete,
  });

  final String emptyMessage;
  final IconData emptyIcon;
  final String addLabel;
  final String countLabel;
  final Future<List<T>> Function() loader;
  final int Function(T) idOf;
  final String Function(T) nameOf;
  final bool Function(T) activeOf;
  final int Function(T) countOf;
  final Future<void> Function(int id, String name, bool isActive) onSave;
  final Future<void> Function(int id) onDelete;

  @override
  State<_SimpleNameTab<T>> createState() => _SimpleNameTabState<T>();
}

class _SimpleNameTabState<T> extends State<_SimpleNameTab<T>> {
  bool _loading = true;
  String? _error;
  List<T> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await widget.loader();
      setState(() { _items = items; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _openForm({T? item}) async {
    final nameCtrl = TextEditingController(text: item == null ? '' : widget.nameOf(item));
    bool isActive = item == null ? true : widget.activeOf(item);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _formSheet(
          context: ctx,
          title: item == null ? widget.addLabel : 'Edit',
          fields: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *'), autofocus: true),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: isActive,
              onChanged: (v) => setSheetState(() => isActive = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) { showSnack(context, 'Name is required.', isError: true); return; }
    try {
      await widget.onSave(item == null ? 0 : widget.idOf(item), name, isActive);
      if (mounted) { showSnack(context, item == null ? 'Added.' : 'Updated.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _confirmDelete(T item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${widget.nameOf(item)}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.onDelete(widget.idOf(item));
      if (mounted) { showSnack(context, 'Deleted.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? EmptyState(message: widget.emptyMessage, icon: widget.emptyIcon)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          return Card(
                            child: ListTile(
                              title: Text(widget.nameOf(item), style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${widget.countOf(item)} ${widget.countLabel}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!widget.activeOf(item)) const Padding(padding: EdgeInsets.only(right: 6), child: StatusBadge(status: 'Inactive')),
                                  IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(item: item)),
                                  IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger), onPressed: () => _confirmDelete(item)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _YearsTab extends StatefulWidget {
  const _YearsTab();

  @override
  State<_YearsTab> createState() => _YearsTabState();
}

class _YearsTabState extends State<_YearsTab> {
  final _service = MastersService();
  bool _loading = true;
  String? _error;
  List<AcademicYear> _years = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final years = await _service.getYears();
      setState(() { _years = years; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _openForm({AcademicYear? year}) async {
    final nameCtrl = TextEditingController(text: year?.yearName ?? '');
    bool isCurrent = year?.isCurrent ?? false;
    bool isActive = year?.isActive ?? true;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _formSheet(
          context: ctx,
          title: year == null ? 'Add Academic Year' : 'Edit Academic Year',
          fields: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Year Name * (e.g. 2025-26)'), autofocus: true),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Current Year'),
              value: isCurrent,
              onChanged: (v) => setSheetState(() => isCurrent = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: isActive,
              onChanged: (v) => setSheetState(() => isActive = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) { showSnack(context, 'Year name is required.', isError: true); return; }
    try {
      await _service.saveYear(yearId: year?.yearId ?? 0, yearName: name, isCurrent: isCurrent, isActive: isActive);
      if (mounted) { showSnack(context, year == null ? 'Academic year added.' : 'Academic year updated.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _confirmDelete(AcademicYear year) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Academic Year'),
        content: Text('Delete "${year.yearName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteYear(year.yearId);
      if (mounted) { showSnack(context, 'Academic year deleted.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _years.isEmpty
                  ? const EmptyState(message: 'No academic years found.', icon: Icons.calendar_today_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                        itemCount: _years.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final y = _years[i];
                          return Card(
                            child: ListTile(
                              title: Row(
                                children: [
                                  Flexible(child: Text(y.yearName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  if (y.isCurrent) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                                      child: const Text('Current', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text('${y.studentCount} students'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!y.isActive) const Padding(padding: EdgeInsets.only(right: 6), child: StatusBadge(status: 'Inactive')),
                                  IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(year: y)),
                                  IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger), onPressed: () => _confirmDelete(y)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _ClassesTab extends StatefulWidget {
  const _ClassesTab();

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  final _service = MastersService();
  bool _loading = true;
  String? _error;
  List<SchoolClass> _classes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final classes = await _service.getClasses();
      setState(() { _classes = classes; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _openForm({SchoolClass? klass}) async {
    final nameCtrl = TextEditingController(text: klass?.className ?? '');
    final orderCtrl = TextEditingController(text: '${klass?.orderNo ?? (_classes.length + 1)}');
    bool isActive = klass?.isActive ?? true;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _formSheet(
          context: ctx,
          title: klass == null ? 'Add Class' : 'Edit Class',
          fields: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Class Name *'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: orderCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Order No')),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: isActive,
              onChanged: (v) => setSheetState(() => isActive = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) { showSnack(context, 'Class name is required.', isError: true); return; }
    try {
      await _service.saveClass(
        classId: klass?.classId ?? 0,
        className: name,
        orderNo: int.tryParse(orderCtrl.text.trim()) ?? 0,
        isActive: isActive,
      );
      if (mounted) { showSnack(context, klass == null ? 'Class added.' : 'Class updated.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _confirmDelete(SchoolClass klass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Delete "${klass.className}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteClass(klass.classId);
      if (mounted) { showSnack(context, 'Class deleted.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _classes.isEmpty
                  ? const EmptyState(message: 'No classes found.', icon: Icons.class_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                        itemCount: _classes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = _classes[i];
                          return Card(
                            child: ListTile(
                              title: Text(c.className, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Order ${c.orderNo} • ${c.studentCount} students'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!c.isActive) const Padding(padding: EdgeInsets.only(right: 6), child: StatusBadge(status: 'Inactive')),
                                  IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(klass: c)),
                                  IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger), onPressed: () => _confirmDelete(c)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _SubjectsTab extends StatefulWidget {
  const _SubjectsTab();

  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  final _service = MastersService();
  bool _loadingClasses = true;
  String? _classError;
  List<SchoolClass> _classes = [];
  int? _classId;

  bool _loadingSubjects = false;
  String? _subjectError;
  List<MasterSubject> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() { _loadingClasses = true; _classError = null; });
    try {
      final classes = await _service.getClasses();
      _classId ??= classes.isNotEmpty ? classes.first.classId : null;
      setState(() { _classes = classes; _loadingClasses = false; });
      if (_classId != null) _loadSubjects();
    } on ApiException catch (e) {
      setState(() { _classError = e.message; _loadingClasses = false; });
    }
  }

  Future<void> _loadSubjects() async {
    if (_classId == null) return;
    setState(() { _loadingSubjects = true; _subjectError = null; });
    try {
      final subjects = await _service.getSubjectsForClass(_classId!);
      setState(() { _subjects = subjects; _loadingSubjects = false; });
    } on ApiException catch (e) {
      setState(() { _subjectError = e.message; _loadingSubjects = false; });
    }
  }

  Future<void> _openForm({MasterSubject? subject}) async {
    if (_classId == null) return;
    final nameCtrl = TextEditingController(text: subject?.subjectName ?? '');
    final codeCtrl = TextEditingController(text: subject?.subjectCode ?? '');
    final maxMarksCtrl = TextEditingController(text: '${subject?.maxMarks ?? 100}');
    final passMarksCtrl = TextEditingController(text: '${subject?.passMarks ?? 35}');
    bool isActive = subject?.isActive ?? true;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _formSheet(
          context: ctx,
          title: subject == null ? 'Add Subject' : 'Edit Subject',
          fields: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Subject Name *'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Subject Code')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: maxMarksCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Marks'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: passMarksCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pass Marks'))),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: isActive,
              onChanged: (v) => setSheetState(() => isActive = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) { showSnack(context, 'Subject name is required.', isError: true); return; }
    try {
      await _service.saveSubject(
        subjectId: subject?.subjectId ?? 0,
        subjectName: name,
        subjectCode: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
        classId: _classId!,
        maxMarks: int.tryParse(maxMarksCtrl.text.trim()) ?? 100,
        passMarks: int.tryParse(passMarksCtrl.text.trim()) ?? 35,
        isActive: isActive,
      );
      if (mounted) { showSnack(context, subject == null ? 'Subject added.' : 'Subject updated.'); _loadSubjects(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _confirmDelete(MasterSubject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text('Delete "${subject.subjectName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteSubject(subject.subjectId);
      if (mounted) { showSnack(context, 'Subject deleted.'); _loadSubjects(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _classId == null ? null : FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: _loadingClasses
          ? const LoadingView()
          : _classError != null
              ? ErrorView(message: _classError!, onRetry: _loadClasses)
              : _classes.isEmpty
                  ? const EmptyState(message: 'No classes found. Add a class first.', icon: Icons.class_outlined)
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: DropdownButtonFormField<int>(
      isExpanded: true,
                            initialValue: _classId,
                            decoration: const InputDecoration(labelText: 'Class'),
                            items: _classes.map((c) => DropdownMenuItem(value: c.classId, child: Text(c.className))).toList(),
                            onChanged: (v) { setState(() => _classId = v); _loadSubjects(); },
                          ),
                        ),
                        Expanded(
                          child: _loadingSubjects
                              ? const LoadingView()
                              : _subjectError != null
                                  ? ErrorView(message: _subjectError!, onRetry: _loadSubjects)
                                  : _subjects.isEmpty
                                      ? const EmptyState(message: 'No subjects found for this class.', icon: Icons.menu_book_outlined)
                                      : RefreshIndicator(
                                          onRefresh: _loadSubjects,
                                          child: ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                                            itemCount: _subjects.length,
                                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                                            itemBuilder: (_, i) {
                                              final s = _subjects[i];
                                              return Card(
                                                child: ListTile(
                                                  title: Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                  subtitle: Text('${s.subjectCode ?? '—'} • Max ${s.maxMarks} / Pass ${s.passMarks}'),
                                                  trailing: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(subject: s)),
                                                      IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger), onPressed: () => _confirmDelete(s)),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                        ),
                      ],
                    ),
    );
  }
}
