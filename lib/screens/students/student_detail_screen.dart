import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/student_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'student_form_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});
  final int studentId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _service = StudentService();
  bool _loading = true;
  String? _error;
  StudentDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await _service.getById(widget.studentId);
      setState(() { _detail = detail; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StudentFormScreen(student: _detail!.student)));
    if (saved == true) _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Move ${_detail!.student.fullName} to inactive/deleted records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(widget.studentId);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final canEdit = session.isAdmin || session.hasEditPerm('student');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
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
                  ? const EmptyState(message: 'Student not found.')
                  : _buildBody(_detail!),
    );
  }

  Widget _buildBody(StudentDetail detail) {
    final s = detail.student;
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
                  CircleAvatar(radius: 32, backgroundColor: AppColors.primarySoft, child: Text(s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(s.classLabel, style: const TextStyle(color: AppColors.textSecondary)),
                        Text('Admission No: ${s.admissionNo}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  StatusBadge(status: s.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Details'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(children: [
                _row('Roll No', s.rollNo),
                _row('Gender', s.gender),
                _row('Date of Birth', s.dateOfBirth == null ? null : DateFormat.yMMMd().format(s.dateOfBirth!)),
                _row('Blood Group', s.bloodGroup),
                _row('Admission Date', s.admissionDate == null ? null : DateFormat.yMMMd().format(s.admissionDate!)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Contact'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(children: [
                _row('Student Phone', s.phone),
                _row("Father's Name", s.fatherName),
                _row("Father's Phone", s.fatherPhone),
                _row("Mother's Name", s.motherName),
                _row("Mother's Phone", s.motherPhone),
                _row('Email', s.email),
                _row('Address', s.address),
              ]),
            ),
          ),
          if (detail.fees.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'Fee Structure'),
            ...detail.fees.map((f) {
              final m = f as Map;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(m['feeTypeName']?.toString() ?? 'Fee'),
                  trailing: Text('₹${m['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              );
            }),
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
