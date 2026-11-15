import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/parent_data_controller.dart';
import '../../models/student.dart';
import '../../services/parent_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_widgets.dart';

/// The student's own basic details, editable by the student / parent: date of birth (required) and email (optional).
/// The photo is changed from the avatar on Home.
class MyDetailsCard extends StatelessWidget {
  const MyDetailsCard({super.key, required this.student});
  final Student student;

  /// Shown value for an empty field: "—" (not blank, so a missing roll is visible).
  static String _or(String? v) => (v ?? '').trim().isEmpty ? '—' : v!.trim();

  Future<void> _edit(BuildContext context) async {
    final ctrl = context.read<ParentDataController>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditDetailsSheet(student: student),
    );
    if (saved == true) await ctrl.load();
  }

  @override
  Widget build(BuildContext context) {
    final dob = student.dateOfBirth;
    final email = (student.email ?? '').trim();
    return ProfileCard(
      title: 'My Details',
      icon: Icons.badge_outlined,
      action: TextButton.icon(
        onPressed: () => _edit(context),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      children: [
        ProfileInfoRow(icon: Icons.person_outline, label: 'Name', value: student.displayName),
        const ProfileDivider(),
        ProfileInfoRow(icon: Icons.confirmation_number_outlined, label: 'Admission No', value: _or(student.admissionNo)),
        const ProfileDivider(),
        ProfileInfoRow(icon: Icons.class_outlined, label: 'Class', value: _or(student.className)),
        const ProfileDivider(),
        ProfileInfoRow(icon: Icons.account_tree_outlined, label: 'Stream / Medium', value: _or(student.sectionName)),
        const ProfileDivider(),
        ProfileInfoRow(icon: Icons.groups_outlined, label: 'Batch', value: _or(student.batchName)),
        const ProfileDivider(),
        ProfileInfoRow(icon: Icons.format_list_numbered, label: 'Roll No', value: _or(student.rollNo)),
        const ProfileDivider(),
        ProfileInfoRow(icon: Icons.cake_outlined, label: 'Date of Birth', value: dob == null ? 'Not set - please add' : DateFormat('d MMM yyyy').format(dob), warn: dob == null),
        const ProfileDivider(),
        ProfileInfoRow(icon: Icons.mail_outline, label: 'Email', value: email.isEmpty ? 'Not added' : email),
      ],
    );
  }
}

class _EditDetailsSheet extends StatefulWidget {
  const _EditDetailsSheet({required this.student});
  final Student student;

  @override
  State<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends State<_EditDetailsSheet> {
  final _email = TextEditingController();
  DateTime? _dob;
  bool _saving = false;
  String? _dobError, _emailError;

  @override
  void initState() {
    super.initState();
    _dob = widget.student.dateOfBirth;
    _email.text = widget.student.email ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 14, now.month, now.day),
      firstDate: DateTime(1980),
      lastDate: now,
    );
    if (picked != null) setState(() { _dob = picked; _dobError = null; });
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    setState(() {
      _dobError = _dob == null ? 'Date of birth is required' : null;
      _emailError = email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? 'Enter a valid email or leave it empty' : null;
    });
    if (_dobError != null || _emailError != null) return;
    setState(() => _saving = true);
    try {
      await withLoader(context, () => ParentService().updateChildDetails(widget.student.studentId, dateOfBirth: _dob!, email: email));
      if (!mounted) return;
      showSnack(context, 'Details updated.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: sheetBottomInset(context) + 20),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Edit My Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDob,
            child: InputDecorator(
              decoration: InputDecoration(labelText: 'Date of Birth *', errorText: _dobError, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(_dob == null ? 'Select date' : DateFormat('d MMM yyyy').format(_dob!), style: TextStyle(color: _dob == null ? AppColors.textSecondary : null)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'Email (optional)', errorText: _emailError),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
