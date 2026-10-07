import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/lookup.dart';
import '../../models/marks.dart';
import '../../models/toppers.dart';
import '../../services/lookup_service.dart';
import '../../services/marks_service.dart';
import '../../widgets/common.dart';
import '../../widgets/toppers_card.dart';

/// Admin / staff view of everyone's rankers — mirrors Marks → Top 5 Students on the web (Overall, Class-wise,
/// Test-wise and Subject-wise Top 5, optionally narrowed to one class / medium). Parents only ever see the
/// Top 5 of their own child's class (Grades tab), never this screen.
class TopStudentsScreen extends StatefulWidget {
  const TopStudentsScreen({super.key});

  @override
  State<TopStudentsScreen> createState() => _TopStudentsScreenState();
}

class _TopStudentsScreenState extends State<TopStudentsScreen> {
  final _marks = MarksService();
  final _lookup = LookupService();

  bool _loading = true;
  String? _error;
  List<LookupItem> _classes = [], _sections = [];
  int? _classId, _sectionId;
  TopStudentsResult? _result;
  int _view = 0; // 0 overall, 1 class-wise, 2 test-wise, 3 subject-wise

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final classes = await _lookup.getClasses();
      final sections = await _lookup.getSections();
      if (!mounted) return;
      setState(() { _classes = classes; _sections = sections; });
    } on ApiException {
      // filters just stay empty; the ranking itself can still load
    }
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _marks.getTopStudents(classId: _classId, sectionId: _sectionId);
      if (mounted) setState(() { _result = r; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  TopperSection _section(List<TopStudentRow> rows) => TopperSection(
        ranked: rows.length,
        top: rows
            .map((r) => TopperRow(
                  rank: r.rank,
                  fullName: r.fullName,
                  percentage: r.percentage,
                  totalObtained: r.totalObtained,
                  totalMax: r.totalMax,
                  isMe: false,
                ))
            .toList(),
      );

  Widget _dropdown(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name.trim(), overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.hasPerm('marks_topstudents')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Top Students')),
        body: const EmptyState(message: 'You do not have permission to view top students.', icon: Icons.lock_outline),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Top Students')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(child: _dropdown('Class', _classId, _classes, (v) { setState(() => _classId = v); _load(); })),
                const SizedBox(width: 12),
                Expanded(child: _dropdown('Medium', _sectionId, _sections, (v) { setState(() => _sectionId = v); _load(); })),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Overall')),
                  ButtonSegment(value: 1, label: Text('Class')),
                  ButtonSegment(value: 2, label: Text('Test')),
                  ButtonSegment(value: 3, label: Text('Subject')),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final r = _result;
    if (r == null) return const EmptyState(message: 'No data.', icon: Icons.emoji_events_outlined);

    final Map<String, List<TopStudentRow>> groups = switch (_view) {
      0 => {'Overall Top 5': r.overallTop5},
      1 => r.classwiseTop5,
      2 => r.testwiseTop5,
      _ => r.subjectwiseTop5,
    };
    final entries = groups.entries.where((e) => e.value.isNotEmpty).toList();
    if (entries.isEmpty) {
      return const EmptyState(message: 'No marks recorded for this selection yet.', icon: Icons.emoji_events_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final e = entries[i];
          final cls = _view == 0 ? e.value.first.classLabel : null;
          return ToppersCard(
            title: _view == 0 ? 'Top 5 — all tests combined' : e.key.trim(),
            subtitle: cls,
            section: _section(e.value),
          );
        },
      ),
    );
  }
}
