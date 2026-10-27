import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/class_note.dart';
import '../../models/lookup.dart';
import '../../services/lookup_service.dart';
import '../../services/notes_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'note_upload_screen.dart';

/// One row of a notes list (shared by the staff screen and the parent screen).
class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.note, required this.onOpen, this.onDelete, this.showGroup = true});
  final ClassNote note;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final bool showGroup;

  @override
  Widget build(BuildContext context) {
    final n = note;
    final meta = [
      if (showGroup && n.groupLabel.isNotEmpty) n.groupLabel,
      if ((n.subjectName ?? '').trim().isNotEmpty) n.subjectName!.trim(),
      DateFormat('d MMM yyyy').format(n.paperDate),
      n.sizeLabel,
    ].join('  •  ');
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: n.soft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(n.icon, color: n.color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.2)),
                      const SizedBox(height: 2),
                      Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if ((n.description ?? '').trim().isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 2), child: Text(n.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    ],
                  ),
                ),
                const Icon(Icons.download_rounded, color: AppColors.primary),
                if (onDelete != null) IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: onDelete)
                else const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Staff: all notes / practice papers with class + type filters; upload and delete with the Edit right.
class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final _service = NotesService();
  bool _loading = true;
  String? _error;
  List<ClassNote> _notes = [];
  List<LookupItem> _classes = [];
  int? _classId;
  String? _kind;

  @override
  void initState() {
    super.initState();
    LookupService().getClasses().then((c) { if (mounted) setState(() => _classes = c); }).catchError((_) {});
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _notes.isEmpty; _error = null; });
    try {
      final list = await _service.getAll(classId: _classId, kind: _kind);
      if (mounted) setState(() { _notes = list; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _open(ClassNote n) async {
    final ok = await _service.open(n.noteId);
    if (!ok && mounted) showSnack(context, 'Could not open the file.', isError: true);
  }

  Future<void> _delete(ClassNote n) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file'),
        content: Text('Delete "${n.title}"? Parents will no longer see it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _service.delete(n.noteId);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _upload() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NoteUploadScreen()));
    if (ok == true) _load();
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: tap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: on ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: on ? AppColors.primary : AppColors.borderNeutral),
            ),
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<Session>().hasEditPerm('class_notes');
    return Scaffold(
      appBar: AppBar(title: const Text('Notes & Practice Papers')),
      floatingActionButton: canEdit ? FloatingActionButton.extended(onPressed: _upload, icon: const Icon(Icons.upload_file_rounded), label: const Text('Upload')) : null,
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
              children: [
                _chip('All', _kind == null, () { setState(() => _kind = null); _load(); }),
                _chip('Notes', _kind == 'Notes', () { setState(() => _kind = 'Notes'); _load(); }),
                _chip('Practice papers', _kind == 'Practice', () { setState(() => _kind = 'Practice'); _load(); }),
                for (final c in _classes) _chip(c.name.trim(), _classId == c.id, () { setState(() => _classId = _classId == c.id ? null : c.id); _load(); }),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null && _notes.isEmpty
                    ? ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _notes.isEmpty
                            ? ListView(children: const [Padding(padding: EdgeInsets.only(top: 60), child: EmptyState(message: 'Nothing uploaded yet.', icon: Icons.description_outlined))])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                                itemCount: _notes.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, i) => NoteTile(note: _notes[i], onOpen: () => _open(_notes[i]), onDelete: canEdit ? () => _delete(_notes[i]) : null),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
