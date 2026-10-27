import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/class_note.dart';
import '../../services/notes_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../notes/notes_list_screen.dart';

/// Notes and daily practice papers of my child's class (a student sees their own class's).
class ParentNotesScreen extends StatefulWidget {
  const ParentNotesScreen({super.key, required this.studentId});
  final int studentId;

  @override
  State<ParentNotesScreen> createState() => _ParentNotesScreenState();
}

class _ParentNotesScreenState extends State<ParentNotesScreen> {
  final _service = NotesService();
  bool _loading = true;
  String? _error;
  List<ClassNote> _notes = [];
  String? _kind;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _notes.isEmpty; _error = null; });
    try {
      final list = await _service.getForChild(widget.studentId);
      if (mounted) setState(() { _notes = list; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _open(ClassNote n) async {
    final ok = await _service.open(n.noteId);
    if (!ok && mounted) showSnack(context, 'Could not open the file.', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _kind == null ? _notes : _notes.where((n) => n.kind == _kind).toList();
    Widget chip(String label, String? k) {
      final on = _kind == k;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () => setState(() => _kind = k),
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
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notes & Practice Papers')),
      body: _loading
          ? const LoadingView()
          : _error != null && _notes.isEmpty
              ? ErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: Row(children: [chip('All', null), chip('Notes', 'Notes'), chip('Practice papers', 'Practice')]),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: shown.isEmpty
                            ? ListView(children: const [Padding(padding: EdgeInsets.only(top: 60), child: EmptyState(message: 'Nothing uploaded for your class yet.', icon: Icons.description_outlined))])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                                itemCount: shown.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, i) => NoteTile(note: shown[i], onOpen: () => _open(shown[i]), showGroup: false),
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
