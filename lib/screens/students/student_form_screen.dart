import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../models/student.dart';
import '../../services/lookup_service.dart';
import '../../services/student_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.student});
  final Student? student;

  bool get isEdit => student != null;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = StudentService();
  final _lookup = LookupService();

  late final TextEditingController _fullName;
  late final TextEditingController _admissionNo;
  late final TextEditingController _rollNo;
  late final TextEditingController _fatherName;
  late final TextEditingController _motherName;
  late final TextEditingController _phone;
  late final TextEditingController _fatherPhone;
  late final TextEditingController _motherPhone;
  late final TextEditingController _email;
  late final TextEditingController _address;

  String? _gender;
  DateTime? _dateOfBirth;
  DateTime? _admissionDate;
  String? _bloodGroup;
  String _status = 'Active';

  bool _loadingLookups = true;
  bool _saving = false;
  List<LookupItem> _years = [], _classes = [], _sections = [], _batches = [];
  int? _yearId, _classId, _sectionId, _batchId;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _fullName = TextEditingController(text: s?.fullName ?? '');
    _admissionNo = TextEditingController(text: s?.admissionNo ?? '');
    _rollNo = TextEditingController(text: s?.rollNo ?? '');
    _fatherName = TextEditingController(text: s?.fatherName ?? '');
    _motherName = TextEditingController(text: s?.motherName ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _fatherPhone = TextEditingController(text: s?.fatherPhone ?? '');
    _motherPhone = TextEditingController(text: s?.motherPhone ?? '');
    _email = TextEditingController(text: s?.email ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _gender = s?.gender;
    _dateOfBirth = s?.dateOfBirth;
    _admissionDate = s?.admissionDate;
    _bloodGroup = s?.bloodGroup;
    _status = s?.status ?? 'Active';
    _yearId = s?.academicYearId;
    _classId = s?.classId;
    _sectionId = s?.sectionId;
    _batchId = s?.batchId;
    _loadLookups();
  }

  @override
  void dispose() {
    for (final c in [_fullName, _admissionNo, _rollNo, _fatherName, _motherName, _phone, _fatherPhone, _motherPhone, _email, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final years = await _lookup.getYears();
      final classes = await _lookup.getClasses();
      final sections = await _lookup.getSections();
      final batches = await _lookup.getBatches();
      setState(() {
        _years = years; _classes = classes; _sections = sections; _batches = batches;
        _yearId ??= years.firstWhere((y) => y.isActive, orElse: () => years.isNotEmpty ? years.first : LookupItem(id: 0, name: '')).id;
        _loadingLookups = false;
      });
    } on ApiException catch (e) {
      if (mounted) { setState(() => _loadingLookups = false); showSnack(context, e.message, isError: true); }
    }
  }

  Future<void> _pickDate({required bool isDob}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isDob ? _dateOfBirth : _admissionDate) ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() { if (isDob) { _dateOfBirth = picked; } else { _admissionDate = picked; } });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final json = {
        'studentId': widget.student?.studentId ?? 0,
        'fullName': _fullName.text.trim(),
        'admissionNo': _admissionNo.text.trim(),
        'rollNo': _rollNo.text.trim(),
        'gender': _gender,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'fatherName': _fatherName.text.trim(),
        'motherName': _motherName.text.trim(),
        'phone': _phone.text.trim(),
        'fatherPhone': _fatherPhone.text.trim(),
        'motherPhone': _motherPhone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'academicYearId': _yearId,
        'classId': _classId,
        'sectionId': _sectionId,
        'batchId': _batchId,
        'bloodGroup': _bloodGroup,
        'admissionDate': _admissionDate?.toIso8601String(),
        'status': _status,
      };
      await _service.save(json);
      if (mounted) {
        showSnack(context, widget.isEdit ? 'Student updated.' : 'Student created.');
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Student' : 'New Student')),
      body: _loadingLookups
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const SectionHeader(title: 'Basic Info'),
                  TextFormField(controller: _fullName, decoration: const InputDecoration(labelText: 'Full Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _admissionNo, decoration: const InputDecoration(labelText: 'Admission No'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _rollNo, decoration: const InputDecoration(labelText: 'Roll No'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
      isExpanded: true,
                        initialValue: _gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female')), DropdownMenuItem(value: 'Other', child: Text('Other'))],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
      isExpanded: true,
                        initialValue: _bloodGroup,
                        decoration: const InputDecoration(labelText: 'Blood Group'),
                        items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (v) => setState(() => _bloodGroup = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _dateField('Date of Birth', _dateOfBirth, () => _pickDate(isDob: true)),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Class & Batch'),
                  _dropdown('Academic Year', _yearId, _years, (v) => setState(() => _yearId = v)),
                  const SizedBox(height: 12),
                  _dropdown('Class', _classId, _classes, (v) => setState(() => _classId = v)),
                  const SizedBox(height: 12),
                  _dropdown('Section', _sectionId, _sections, (v) => setState(() => _sectionId = v)),
                  const SizedBox(height: 12),
                  _dropdown('Batch', _batchId, _batches, (v) => setState(() => _batchId = v)),
                  const SizedBox(height: 12),
                  _dateField('Admission Date', _admissionDate, () => _pickDate(isDob: false)),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Contact'),
                  TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Student Phone')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _fatherName, decoration: const InputDecoration(labelText: "Father's Name")),
                  const SizedBox(height: 12),
                  TextFormField(controller: _fatherPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Father's Phone")),
                  const SizedBox(height: 12),
                  TextFormField(controller: _motherName, decoration: const InputDecoration(labelText: "Mother's Name")),
                  const SizedBox(height: 12),
                  TextFormField(controller: _motherPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Mother's Phone")),
                  const SizedBox(height: 12),
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address', alignLabelWithHint: true)),
                  if (widget.isEdit) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
      isExpanded: true,
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [DropdownMenuItem(value: 'Active', child: Text('Active')), DropdownMenuItem(value: 'Inactive', child: Text('Inactive'))],
                      onChanged: (v) => setState(() => _status = v ?? 'Active'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.isEdit ? 'Save Changes' : 'Create Student'),
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
      items: items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
        child: Text(value == null ? 'Not set' : DateFormat.yMMMd().format(value), style: TextStyle(color: value == null ? AppColors.textSecondary : null)),
      ),
    );
  }
}
