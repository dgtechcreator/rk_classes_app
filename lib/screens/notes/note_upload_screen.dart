import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/lookup.dart';
import '../../services/lookup_service.dart';
import '../../services/notes_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Upload notes or the daily practice paper for a class (optionally one medium / batch). The class's parents are notified.
class NoteUploadScreen extends StatefulWidget {
  const NoteUploadScreen({super.key, this.initialKind = 'Notes'});
  final String initialKind;

  @override
  State<NoteUploadScreen> createState() => _NoteUploadScreenState();
}

class _NoteUploadScreenState extends State<NoteUploadScreen> {
  final _lookup = LookupService();
  final _service = NotesService();
  final _title = TextEditingController();
  final _desc = TextEditingController();

  late String _kind = widget.initialKind;
  List<LookupItem> _classes = [], _sections = [], _batches = [];
  List<String> _subjects = [];
  int? _classId, _sectionId, _batchId;
  String? _subject;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  PlatformFile? _file;
  int _fileSize = 0;
  Uint8List? _bytes;
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final r = await Future.wait([_lookup.getClasses(), _lookup.getSections(), _lookup.getBatches()]);
      if (mounted) setState(() { _classes = r[0]; _sections = r[1]; _batches = r[2]; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) { setState(() => _loading = false); showSnack(context, e.message, isError: true); }
    }
  }

  Future<void> _classChanged(int? id) async {
    setState(() { _classId = id; _subject = null; _subjects = []; });
    if (id == null) return;
    try {
      final subs = await _lookup.getSubjects(id);
      if (mounted && _classId == id) setState(() => _subjects = subs.map((s) => s.subjectName.trim()).where((s) => s.isNotEmpty).toSet().toList());
    } on ApiException {
      // the subject box simply stays empty
    }
  }

  Future<void> _pickFile() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png', 'txt'],
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();   // works on every platform (the web picker has no file path)
    if (mounted) setState(() { _file = f; _bytes = bytes; _fileSize = bytes.length; });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_classId == null) return showSnack(context, 'Select a class.', isError: true);
    if (_title.text.trim().isEmpty) return showSnack(context, 'Enter a title.', isError: true);
    if (_file == null) return showSnack(context, 'Choose a file.', isError: true);
    if (_fileSize > 15 * 1024 * 1024) return showSnack(context, 'File is too large (max 15 MB).', isError: true);
    setState(() => _saving = true);
    try {
      final bytes = _bytes!;
      await _service.upload(
        kind: _kind, title: _title.text.trim(), description: _desc.text, classId: _classId!, sectionId: _sectionId, batchId: _batchId,
        subjectName: _subject, paperDate: _date, bytes: bytes, fileName: _file!.name,
      );
      if (!mounted) return;
      showSnack(context, 'Uploaded. Parents of the class have been notified.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) { setState(() => _saving = false); showSnack(context, e.message, isError: true); }
    }
  }

  Widget _drop<T>(String label, T? value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) => DropdownButtonFormField<T>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: items,
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: _loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Notes', icon: Icon(Icons.description_outlined), label: Text('Notes')),
                    ButtonSegment(value: 'Practice', icon: Icon(Icons.edit_note_rounded), label: Text('Practice paper')),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 14),
                _drop<int>('Class *', _classId, [for (final c in _classes) DropdownMenuItem(value: c.id, child: Text(c.name.trim()))], _classChanged),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _drop<int?>('Medium', _sectionId, [const DropdownMenuItem(value: null, child: Text('All')), for (final s in _sections) DropdownMenuItem(value: s.id, child: Text(s.name.trim()))], (v) => setState(() => _sectionId = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _drop<int?>('Batch', _batchId, [const DropdownMenuItem(value: null, child: Text('All')), for (final b in _batches) DropdownMenuItem(value: b.id, child: Text(b.name.trim()))], (v) => setState(() => _batchId = v))),
                ]),
                const SizedBox(height: 12),
                _drop<String?>('Subject', _subject, [const DropdownMenuItem(value: null, child: Text('-')), for (final s in _subjects) DropdownMenuItem(value: s, child: Text(s))], (v) => setState(() => _subject = v)),
                const SizedBox(height: 12),
                TextField(controller: _title, maxLength: 200, decoration: const InputDecoration(labelText: 'Title *', hintText: 'e.g. Algebra - Chapter 3 notes', counterText: '')),
                const SizedBox(height: 12),
                TextField(controller: _desc, maxLines: 2, maxLength: 1000, decoration: const InputDecoration(labelText: 'Note (optional)', counterText: '')),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: _kind == 'Practice' ? 'Practice paper for' : 'Date', suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
                    child: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(_file == null ? 'Choose file (PDF, Word, PPT, Excel, image)' : '${_file!.name}  (${(_fileSize / 1024).ceil()} KB)', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_saving ? 'Uploading...' : 'Upload'),
                ),
                const SizedBox(height: 8),
                const Center(child: Text('Parents and students of the class get a notification.', style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
              ],
            ),
    );
  }
}
