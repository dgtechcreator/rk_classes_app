import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/faculty.dart';
import '../../services/faculty_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'faculty_detail_screen.dart';
import 'faculty_form_screen.dart';

class FacultyListScreen extends StatefulWidget {
  const FacultyListScreen({super.key});

  @override
  State<FacultyListScreen> createState() => _FacultyListScreenState();
}

class _FacultyListScreenState extends State<FacultyListScreen> {
  final _service = FacultyService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<Faculty> _faculty = [];
  int _total = 0;
  int _page = 1;
  int _totalPages = 1;

  List<Designation> _designations = [];
  int? _designationId;
  String _status = 'Active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getAll(
        page: 1,
        search: _searchCtrl.text.trim(),
        status: _status,
        designationId: _designationId,
      );
      setState(() {
        _faculty = result.data;
        _total = result.total;
        _page = result.page;
        _totalPages = result.totalPages;
        _designations = result.designations;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _service.getAll(
        page: _page + 1,
        search: _searchCtrl.text.trim(),
        status: _status,
        designationId: _designationId,
      );
      setState(() {
        _faculty = [..._faculty, ...result.data];
        _page = result.page;
        _totalPages = result.totalPages;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      setState(() => _loadingMore = false);
      if (mounted) showSnack(context, e.message, isError: true);
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
        designations: _designations,
        designationId: _designationId,
        status: _status,
        onApply: (designationId, status) {
          setState(() { _designationId = designationId; _status = status; });
          _load();
        },
      ),
    );
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const FacultyFormScreen()));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasEditPerm('faculty');
    final hasActiveFilters = _designationId != null || _status != 'Active';

    return Scaffold(
      appBar: AppBar(
        title: Text('Faculty${_total > 0 ? ' ($_total)' : ''}'),
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
                hintText: 'Search name, employee code, phone...',
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
                    : _faculty.isEmpty
                        ? const EmptyState(message: 'No faculty found.', icon: Icons.school_outlined)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                              itemCount: _faculty.length + (_page < _totalPages ? 1 : 0),
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                if (i >= _faculty.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: _loadingMore
                                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                          : OutlinedButton(onPressed: _loadMore, child: const Text('Load More')),
                                    ),
                                  );
                                }
                                final f = _faculty[i];
                                return _FacultyTile(
                                  faculty: f,
                                  onTap: () async {
                                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FacultyDetailScreen(facultyId: f.facultyId)));
                                    _load();
                                  },
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

class _FacultyTile extends StatelessWidget {
  const _FacultyTile({required this.faculty, required this.onTap});
  final Faculty faculty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [faculty.designationName, faculty.phone].where((e) => e != null && e.isNotEmpty).join(' • ');
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Text(faculty.fullName.isNotEmpty ? faculty.fullName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text(faculty.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle.isEmpty ? faculty.employeeCode : subtitle),
        trailing: faculty.status != 'Active' ? StatusBadge(status: faculty.status) : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.designations, required this.designationId, required this.status, required this.onApply});
  final List<Designation> designations;
  final int? designationId;
  final String status;
  final void Function(int?, String) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  int? _designationId;
  late String _status;

  @override
  void initState() {
    super.initState();
    _designationId = widget.designationId;
    _status = widget.status;
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
          const Text('Filter Faculty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
      isExpanded: true,
            initialValue: widget.designations.any((e) => e.designationId == _designationId) ? _designationId : null,
            decoration: const InputDecoration(labelText: 'Designation'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All')),
              ...widget.designations.map((e) => DropdownMenuItem<int?>(value: e.designationId, child: Text(e.designationName))),
            ],
            onChanged: (v) => setState(() => _designationId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
      isExpanded: true,
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
                  onPressed: () => setState(() { _designationId = null; _status = 'Active'; }),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { widget.onApply(_designationId, _status); Navigator.of(context).pop(); },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
