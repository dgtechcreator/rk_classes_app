import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/fee_structure.dart';
import '../../models/lookup.dart';
import '../../services/fee_structure_service.dart';
import '../../services/lookup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class FeeStructureListScreen extends StatefulWidget {
  const FeeStructureListScreen({super.key});

  @override
  State<FeeStructureListScreen> createState() => _FeeStructureListScreenState();
}

class _FeeStructureListScreenState extends State<FeeStructureListScreen> {
  final _service = FeeStructureService();
  final _lookup = LookupService();

  bool _loading = true;
  String? _error;
  List<FeeStructure> _list = [];
  List<FeeStructureSummary> _summary = [];

  List<LookupItem> _years = [], _classes = [], _sections = [], _feeTypes = [];
  int? _yearId, _classId, _sectionId;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _load();
  }

  Future<void> _loadFilters() async {
    try {
      final years = await _lookup.getYears();
      final classes = await _lookup.getClasses();
      final sections = await _lookup.getSections();
      final feeTypes = await _lookup.getFeeTypes();
      if (mounted) {
        setState(() {
          _years = years; _classes = classes; _sections = sections; _feeTypes = feeTypes;
          _yearId ??= years.firstWhere((y) => y.isActive, orElse: () => years.isNotEmpty ? years.first : LookupItem(id: 0, name: '')).id;
        });
      }
    } catch (_) {
      // Filters are a convenience — the list still works without them.
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getAll(yearId: _yearId, classId: _classId, sectionId: _sectionId);
      setState(() { _list = result.list; _summary = result.summary; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        years: _years, classes: _classes, sections: _sections,
        yearId: _yearId, classId: _classId, sectionId: _sectionId,
        onApply: (yearId, classId, sectionId) {
          setState(() { _yearId = yearId; _classId = classId; _sectionId = sectionId; });
          _load();
        },
      ),
    );
  }

  Future<void> _openForm({FeeStructure? structure}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeeStructureFormSheet(
        structure: structure,
        years: _years, classes: _classes, sections: _sections, feeTypes: _feeTypes,
        defaultYearId: _yearId,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(FeeStructure structure) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Structure'),
        content: Text('Delete "${structure.feeTypeName}" for ${structure.classLabel}? Unpaid student fees for this head will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(structure.structureId);
      if (mounted) showSnack(context, 'Fee structure deleted.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasPerm('fee_structure');
    final hasActiveFilters = _classId != null || _sectionId != null;
    final totalMonthly = _list.fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('Fee Structure${_list.isNotEmpty ? ' (${_list.length})' : ''}'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: hasActiveFilters ? AppColors.primary : null),
            tooltip: 'Filter',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      floatingActionButton: canEdit ? FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)) : null,
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _list.isEmpty
                      ? ListView(children: const [EmptyState(message: 'No fee structures found.', icon: Icons.receipt_long_outlined)])
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                          children: [
                            Row(
                              children: [
                                Expanded(child: StatCard(label: 'Fee Heads', value: '${_list.length}', color: AppColors.info, icon: Icons.receipt_long_outlined)),
                                const SizedBox(width: 10),
                                Expanded(child: StatCard(label: 'Total / Month', value: '₹${totalMonthly.toStringAsFixed(0)}', color: AppColors.primary, icon: Icons.calendar_month_outlined)),
                              ],
                            ),
                            if (_summary.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const SectionHeader(title: 'Class Summary'),
                              ..._summary.map((s) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      dense: true,
                                      title: Text('${s.className ?? '—'} / ${s.sectionName ?? '—'}'),
                                      subtitle: Text('${s.studentCount} students • ${s.feeHeads} heads'),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('₹${s.collectedAmt.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)),
                                          Text('₹${s.pendingAmt.toStringAsFixed(0)} due', style: const TextStyle(color: AppColors.warning, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  )),
                            ],
                            const SizedBox(height: 16),
                            const SectionHeader(title: 'Fee Heads'),
                            ..._list.map((fs) => _FeeStructureTile(
                                  structure: fs,
                                  canEdit: canEdit,
                                  onTap: canEdit ? () => _openForm(structure: fs) : null,
                                  onDelete: canEdit ? () => _delete(fs) : null,
                                )),
                          ],
                        ),
                ),
    );
  }
}

class _FeeStructureTile extends StatelessWidget {
  const _FeeStructureTile({required this.structure, required this.canEdit, this.onTap, this.onDelete});
  final FeeStructure structure;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
        ),
        title: Text(structure.feeTypeName ?? 'Fee', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${structure.classLabel} • Due day ${structure.dueDay}${structure.yearName != null ? ' • ${structure.yearName}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₹${structure.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (canEdit && onDelete != null)
              IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.years, required this.classes, required this.sections,
    required this.yearId, required this.classId, required this.sectionId,
    required this.onApply,
  });
  final List<LookupItem> years, classes, sections;
  final int? yearId, classId, sectionId;
  final void Function(int?, int?, int?) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  int? _yearId, _classId, _sectionId;

  @override
  void initState() {
    super.initState();
    _yearId = widget.yearId; _classId = widget.classId; _sectionId = widget.sectionId;
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
          const Text('Filter Fee Structures', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _dropdown('Academic Year', _yearId, widget.years, (v) => setState(() => _yearId = v)),
          const SizedBox(height: 12),
          _dropdown('Class', _classId, widget.classes, (v) => setState(() => _classId = v)),
          const SizedBox(height: 12),
          _dropdown('Section', _sectionId, widget.sections, (v) => setState(() => _sectionId = v)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() { _classId = null; _sectionId = null; }),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { widget.onApply(_yearId, _classId, _sectionId); Navigator.of(context).pop(); },
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
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))),
      ],
      onChanged: onChanged,
    );
  }
}

class _FeeStructureFormSheet extends StatefulWidget {
  const _FeeStructureFormSheet({
    required this.structure, required this.years, required this.classes,
    required this.sections, required this.feeTypes, this.defaultYearId,
  });
  final FeeStructure? structure;
  final List<LookupItem> years, classes, sections, feeTypes;
  final int? defaultYearId;

  bool get isEdit => structure != null;

  @override
  State<_FeeStructureFormSheet> createState() => _FeeStructureFormSheetState();
}

class _FeeStructureFormSheetState extends State<_FeeStructureFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _service = FeeStructureService();
  late final TextEditingController _amount;
  late final TextEditingController _dueDay;
  late final TextEditingController _remarks;

  int? _yearId, _classId, _sectionId, _feeTypeId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.structure;
    _amount = TextEditingController(text: s == null ? '' : s.amount.toStringAsFixed(2));
    _dueDay = TextEditingController(text: (s?.dueDay ?? 10).toString());
    _remarks = TextEditingController(text: s?.remarks ?? '');
    _yearId = s?.academicYearId ?? widget.defaultYearId;
    _classId = s?.classId;
    _sectionId = s?.sectionId;
    _feeTypeId = s?.feeTypeId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _dueDay.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_yearId == null || _classId == null || _sectionId == null || _feeTypeId == null) {
      showSnack(context, 'Please select Year, Class, Section and Fee Type.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.save({
        'structureId': widget.structure?.structureId ?? 0,
        'academicYearId': _yearId,
        'classId': _classId,
        'sectionId': _sectionId,
        'feeTypeId': _feeTypeId,
        'amount': double.tryParse(_amount.text.trim()) ?? 0,
        'dueDay': int.tryParse(_dueDay.text.trim()) ?? 10,
        'isMonthly': true,
        'remarks': _remarks.text.trim(),
      });
      if (mounted) {
        showSnack(context, widget.isEdit ? 'Fee structure updated.' : 'Fee structure created.');
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.isEdit ? 'Edit Fee Head' : 'Add Fee Head', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                if (widget.isEdit) ...[
                  _readOnlyRow('Academic Year', widget.structure!.yearName),
                  _readOnlyRow('Class / Section', widget.structure!.classLabel),
                  _readOnlyRow('Fee Type', widget.structure!.feeTypeName),
                ] else ...[
                  _dropdown('Academic Year *', _yearId, widget.years, (v) => setState(() => _yearId = v)),
                  const SizedBox(height: 12),
                  _dropdown('Class *', _classId, widget.classes, (v) => setState(() => _classId = v)),
                  const SizedBox(height: 12),
                  _dropdown('Section *', _sectionId, widget.sections, (v) => setState(() => _sectionId = v)),
                  const SizedBox(height: 12),
                  _dropdown('Fee Type *', _feeTypeId, widget.feeTypes, (v) => setState(() => _feeTypeId = v)),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (₹) *'),
                  validator: (v) => (v == null || double.tryParse(v.trim()) == null || double.parse(v.trim()) <= 0) ? 'Enter a valid amount' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dueDay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Due Day of Month (1-28)'),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.isEdit ? 'Save Changes' : 'Create Fee Head'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _dropdown(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))).toList(),
      validator: (v) => v == null ? 'Required' : null,
      onChanged: onChanged,
    );
  }
}
