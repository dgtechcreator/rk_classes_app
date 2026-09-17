import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/faculty_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'faculty_form_screen.dart';

class FacultyDetailScreen extends StatefulWidget {
  const FacultyDetailScreen({super.key, required this.facultyId});
  final int facultyId;

  @override
  State<FacultyDetailScreen> createState() => _FacultyDetailScreenState();
}

class _FacultyDetailScreenState extends State<FacultyDetailScreen> {
  final _service = FacultyService();
  bool _loading = true;
  String? _error;
  FacultyDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await _service.getById(widget.facultyId);
      setState(() { _detail = detail; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => FacultyFormScreen(faculty: _detail!.faculty)));
    if (saved == true) _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Faculty'),
        content: Text('Mark ${_detail!.faculty.fullName} as Inactive?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(widget.facultyId);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasEditPerm('faculty');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Profile'),
        actions: canEdit && _detail != null
            ? [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: _delete),
              ]
            : null,
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _detail == null
                  ? const EmptyState(message: 'Faculty member not found.')
                  : _buildBody(_detail!),
    );
  }

  Widget _buildBody(FacultyDetail detail) {
    final f = detail.faculty;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(f.fullName.isNotEmpty ? f.fullName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(f.designationName ?? '—', style: const TextStyle(color: AppColors.textSecondary)),
                        Text('Employee Code: ${f.employeeCode}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  StatusBadge(status: f.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Personal Info'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(children: [
                _row('Gender', f.gender),
                _row('Date of Birth', f.dateOfBirth == null ? null : DateFormat.yMMMd().format(f.dateOfBirth!)),
                _row('Blood Group', f.bloodGroup),
                _row('Aadhar No', f.aadharNo),
                _row('Address', f.address),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Contact'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(children: [
                _row('Phone', f.phone),
                _row('Alternate Phone', f.alternatePhone),
                _row('Email', f.email),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Professional'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(children: [
                _row('Qualification', f.qualification),
                _row('Specialization', f.specialization),
                _row('Date of Joining', f.dateOfJoining == null ? null : DateFormat.yMMMd().format(f.dateOfJoining!)),
                _row('Monthly Salary', f.salary == null ? null : '₹${f.salary!.toStringAsFixed(0)}'),
                _row('Remarks', f.remarks),
              ]),
            ),
          ),
          if (detail.subjects.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'Assigned Subjects'),
            ...detail.subjects.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(s.subjectName ?? 'Subject'),
                    subtitle: Text([s.className, s.sectionName].where((e) => e != null && e.isNotEmpty).join(' / ')),
                  ),
                )),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
