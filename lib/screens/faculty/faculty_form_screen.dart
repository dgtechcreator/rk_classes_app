import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/faculty.dart';
import '../../services/faculty_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class FacultyFormScreen extends StatefulWidget {
  const FacultyFormScreen({super.key, this.faculty});
  final Faculty? faculty;

  bool get isEdit => faculty != null;

  @override
  State<FacultyFormScreen> createState() => _FacultyFormScreenState();
}

class _FacultyFormScreenState extends State<FacultyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FacultyService();

  late final TextEditingController _employeeCode;
  late final TextEditingController _fullName;
  late final TextEditingController _qualification;
  late final TextEditingController _specialization;
  late final TextEditingController _aadharNo;
  late final TextEditingController _phone;
  late final TextEditingController _alternatePhone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _salary;
  late final TextEditingController _remarks;

  String? _gender;
  String? _bloodGroup;
  DateTime? _dateOfBirth;
  DateTime? _dateOfJoining;
  int? _designationId;
  String _status = 'Active';

  bool _loadingLookups = true;
  bool _saving = false;
  List<Designation> _designations = [];

  @override
  void initState() {
    super.initState();
    final f = widget.faculty;
    _employeeCode = TextEditingController(text: f?.employeeCode ?? '');
    _fullName = TextEditingController(text: f?.fullName ?? '');
    _qualification = TextEditingController(text: f?.qualification ?? '');
    _specialization = TextEditingController(text: f?.specialization ?? '');
    _aadharNo = TextEditingController(text: f?.aadharNo ?? '');
    _phone = TextEditingController(text: f?.phone ?? '');
    _alternatePhone = TextEditingController(text: f?.alternatePhone ?? '');
    _email = TextEditingController(text: f?.email ?? '');
    _address = TextEditingController(text: f?.address ?? '');
    _salary = TextEditingController(text: f?.salary == null ? '' : f!.salary!.toStringAsFixed(2));
    _remarks = TextEditingController(text: f?.remarks ?? '');
    _gender = f?.gender;
    _bloodGroup = f?.bloodGroup;
    _dateOfBirth = f?.dateOfBirth;
    _dateOfJoining = f?.dateOfJoining ?? (widget.isEdit ? null : DateTime.now());
    _designationId = f?.designationId;
    _status = f?.status ?? 'Active';
    _loadDesignations();
  }

  @override
  void dispose() {
    for (final c in [_employeeCode, _fullName, _qualification, _specialization, _aadharNo, _phone, _alternatePhone, _email, _address, _salary, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDesignations() async {
    try {
      final designations = await _service.getDesignations();
      if (mounted) setState(() { _designations = designations; _loadingLookups = false; });
    } on ApiException catch (e) {
      if (mounted) { setState(() => _loadingLookups = false); showSnack(context, e.message, isError: true); }
    }
  }

  Future<void> _pickDate({required bool isDob}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isDob ? _dateOfBirth : _dateOfJoining) ?? now,
      firstDate: DateTime(1960),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() { if (isDob) { _dateOfBirth = picked; } else { _dateOfJoining = picked; } });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final json = {
        'facultyId': widget.faculty?.facultyId ?? 0,
        'employeeCode': _employeeCode.text.trim(),
        'fullName': _fullName.text.trim(),
        'designationId': _designationId,
        'qualification': _qualification.text.trim(),
        'specialization': _specialization.text.trim(),
        'gender': _gender,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'dateOfJoining': _dateOfJoining?.toIso8601String(),
        'phone': _phone.text.trim(),
        'alternatePhone': _alternatePhone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'salary': _salary.text.trim().isEmpty ? null : double.tryParse(_salary.text.trim()),
        'bloodGroup': _bloodGroup,
        'aadharNo': _aadharNo.text.trim(),
        'status': _status,
        'remarks': _remarks.text.trim(),
      };
      await _service.save(json);
      if (mounted) {
        showSnack(context, widget.isEdit ? 'Faculty updated.' : 'Faculty created.');
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
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Faculty' : 'New Faculty')),
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
                  TextFormField(
                    controller: _employeeCode,
                    decoration: InputDecoration(labelText: 'Employee Code', hintText: widget.isEdit ? null : 'Leave blank to auto-generate'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _bloodGroup,
                        decoration: const InputDecoration(labelText: 'Blood Group'),
                        items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (v) => setState(() => _bloodGroup = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _dateField('Date of Birth', _dateOfBirth, () => _pickDate(isDob: true)),
                  const SizedBox(height: 12),
                  TextFormField(controller: _aadharNo, decoration: const InputDecoration(labelText: 'Aadhar No')),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Contact'),
                  TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _alternatePhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Alternate Phone')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address', alignLabelWithHint: true)),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Professional'),
                  DropdownButtonFormField<int?>(
                    initialValue: _designations.any((e) => e.designationId == _designationId) ? _designationId : null,
                    decoration: const InputDecoration(labelText: 'Designation *'),
                    items: _designations.map((e) => DropdownMenuItem<int?>(value: e.designationId, child: Text(e.designationName))).toList(),
                    validator: (v) => v == null ? 'Required' : null,
                    onChanged: (v) => setState(() => _designationId = v),
                  ),
                  const SizedBox(height: 12),
                  _dateField('Date of Joining', _dateOfJoining, () => _pickDate(isDob: false)),
                  const SizedBox(height: 12),
                  TextFormField(controller: _qualification, decoration: const InputDecoration(labelText: 'Qualification', hintText: 'e.g. B.Ed, M.A., M.Sc.')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _specialization, decoration: const InputDecoration(labelText: 'Specialization / Subjects', hintText: 'e.g. Mathematics, Science')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _salary, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly Salary (₹)')),
                  if (widget.isEdit) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [DropdownMenuItem(value: 'Active', child: Text('Active')), DropdownMenuItem(value: 'Inactive', child: Text('Inactive'))],
                      onChanged: (v) => setState(() => _status = v ?? 'Active'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(controller: _remarks, maxLines: 2, decoration: const InputDecoration(labelText: 'Remarks', alignLabelWithHint: true)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.isEdit ? 'Save Changes' : 'Create Faculty'),
                  ),
                ],
              ),
            ),
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
