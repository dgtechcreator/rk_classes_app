import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/attendance.dart';
import '../../models/lookup.dart';
import '../../services/attendance_service.dart';
import '../../services/lookup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'attendance_entry_screen.dart';
import 'attendance_report_screen.dart';

/// Attendance home — mirrors the web Attendance page. For the chosen date it lists every attendance
/// batch as a card (green = attendance taken, light red = still pending, with present/total); tapping a
/// card opens that batch's entry screen, pre-filled when the day was already marked. The "By class"
/// tab is the Class/Section/Batch filter for ad-hoc groups. Any past date can be picked to review it.
class AttendanceMarkScreen extends StatefulWidget {
  const AttendanceMarkScreen({super.key});

  @override
  State<AttendanceMarkScreen> createState() => _AttendanceMarkScreenState();
}

class _AttendanceMarkScreenState extends State<AttendanceMarkScreen> {
  final _service = AttendanceService();
  final _lookup = LookupService();

  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _byClass = false;

  bool _loadingBatches = true;
  String? _batchesError;
  List<AttendanceBatchSummary> _batches = [];

  bool _loadingFilters = false;
  bool _filtersLoaded = false;
  String? _filtersError;
  List<LookupItem> _classes = [], _sections = [], _batchLookup = [];
  int? _classId, _sectionId, _batchId;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() { _loadingBatches = true; _batchesError = null; });
    final requested = _date;
    try {
      final list = await _service.getBatches(requested);
      // Ignore a slow answer for a date the user already moved away from.
      if (!mounted || requested != _date) return;
      setState(() { _batches = list; _loadingBatches = false; });
    } on ApiException catch (e) {
      if (mounted && requested == _date) setState(() { _batchesError = e.message; _loadingBatches = false; });
    }
  }

  Future<void> _loadFilters() async {
    if (_filtersLoaded || _loadingFilters) return;
    setState(() { _loadingFilters = true; _filtersError = null; });
    try {
      final classes = await _lookup.getClasses();
      final sections = await _lookup.getSections();
      final batches = await _lookup.getBatches();
      if (!mounted) return;
      setState(() { _classes = classes; _sections = sections; _batchLookup = batches; _loadingFilters = false; _filtersLoaded = true; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _filtersError = e.message; _loadingFilters = false; });
    }
  }

  void _setDate(DateTime d) {
    final day = DateUtils.dateOnly(d);
    if (day.isAfter(DateUtils.dateOnly(DateTime.now())) || DateUtils.isSameDay(day, _date)) return;
    setState(() => _date = day);
    _loadBatches();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Attendance date',
    );
    if (picked != null) _setDate(picked);
  }

  Future<void> _openBatch(AttendanceBatchSummary b) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AttendanceEntryScreen(title: b.batchName, date: _date, attBatchId: b.batchId),
    ));
    if (mounted) _loadBatches();
  }

  String _lookupName(List<LookupItem> items, int? id) => items.where((e) => e.id == id).map((e) => e.name).firstOrNull ?? '';

  Future<void> _openClassFilter() async {
    final label = [_lookupName(_classes, _classId), _lookupName(_sections, _sectionId), _lookupName(_batchLookup, _batchId)]
        .where((e) => e.isNotEmpty)
        .join(' / ');
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AttendanceEntryScreen(
        title: label.isEmpty ? 'Attendance' : label,
        date: _date,
        classId: _classId,
        sectionId: _sectionId,
        batchId: _batchId,
      ),
    ));
    if (mounted) _loadBatches();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.hasPerm('attendance_entry')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Take Attendance')),
        body: const EmptyState(message: 'You do not have permission to take attendance.', icon: Icons.lock_outline),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        actions: [
          if (session.hasPerm('attendance_report'))
            IconButton(
              icon: const Icon(Icons.bar_chart_outlined),
              tooltip: 'Report',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceReportScreen())),
            ),
        ],
      ),
      body: Column(
        children: [
          AttendanceDateBar(date: _date, onChanged: _setDate, onPick: _pickDate),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.layers_outlined, size: 18), label: Text('Batches')),
                  ButtonSegment(value: true, icon: Icon(Icons.filter_alt_outlined, size: 18), label: Text('By class')),
                ],
                selected: {_byClass},
                onSelectionChanged: (s) {
                  setState(() => _byClass = s.first);
                  if (_byClass) _loadFilters();
                },
              ),
            ),
          ),
          Expanded(child: _byClass ? _buildClassFilter() : _buildBatches()),
        ],
      ),
    );
  }

  // ── Batches tab ──────────────────────────────────────────────────────────────────────────────

  Widget _buildBatches() {
    if (_loadingBatches) return const LoadingView();
    if (_batchesError != null) return ErrorView(message: _batchesError!, onRetry: _loadBatches);
    if (_batches.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBatches,
        child: ListView(children: const [
          SizedBox(height: 60),
          EmptyState(
            message: 'No attendance batches yet.\nCreate them in Masters → Attendance Batches, or use the "By class" tab.',
            icon: Icons.layers_outlined,
          ),
        ]),
      );
    }

    final done = _batches.where((b) => b.isMarked).length;
    return RefreshIndicator(
      onRefresh: _loadBatches,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: _batches.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == 0) return _legend(done, _batches.length);
          final b = _batches[i - 1];
          return AttendanceBatchCard(batch: b, onTap: () => _openBatch(b));
        },
      ),
    );
  }

  Widget _legend(int done, int total) {
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          dot(AppColors.success, 'Marked'),
          const SizedBox(width: 14),
          dot(const Color(0xFFF87171), 'Pending'),
          const Spacer(),
          Text('$done of $total marked', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── By class tab ─────────────────────────────────────────────────────────────────────────────

  Widget _buildClassFilter() {
    if (_loadingFilters) return const LoadingView();
    if (_filtersError != null) return ErrorView(message: _filtersError!, onRetry: () { _filtersLoaded = false; _loadFilters(); });
    final hasFilter = _classId != null || _sectionId != null || _batchId != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        Row(
          children: [
            Expanded(child: _dropdown('Class', _classId, _classes, (v) => setState(() => _classId = v))),
            const SizedBox(width: 12),
            Expanded(child: _dropdown('Section', _sectionId, _sections, (v) => setState(() => _sectionId = v))),
          ],
        ),
        const SizedBox(height: 12),
        _dropdown('Batch', _batchId, _batchLookup, (v) => setState(() => _batchId = v)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: hasFilter ? _openClassFilter : null,
          icon: const Icon(Icons.groups_outlined),
          label: const Text('Load students'),
        ),
        if (!hasFilter)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Pick a class, section or batch to load students.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ),
      ],
    );
  }

  Widget _dropdown(String label, int? value, List<LookupItem> items, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      initialValue: items.any((e) => e.id == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))),
      ],
      onChanged: onChanged,
    );
  }
}

/// One attendance batch for the selected date: green when attendance was taken, light red while it is
/// still pending. The pill on the right is present / total (e.g. 15/20).
class AttendanceBatchCard extends StatelessWidget {
  const AttendanceBatchCard({super.key, required this.batch, required this.onTap});
  final AttendanceBatchSummary batch;
  final VoidCallback onTap;

  static const _pendingBg = Color(0xFFFEE2E2);
  static const _pendingBorder = Color(0xFFFCA5A5);
  static const _pendingText = Color(0xFF991B1B);

  @override
  Widget build(BuildContext context) {
    final done = batch.isMarked;
    final bg = done ? const Color(0xFF16A34A) : _pendingBg;
    final fg = done ? Colors.white : _pendingText;
    final subtitle = !done
        ? 'Not marked yet'
        : [
            'Absent ${batch.absent}',
            if (batch.late > 0) 'Late ${batch.late}',
            if (batch.pending > 0) '${batch.pending} pending',
          ].join(' · ');

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: done ? const Color(0xFF15803D) : _pendingBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(done ? Icons.check_circle : Icons.pending_outlined, color: fg, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch.batchName, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: fg.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text('${batch.present}/${batch.total}',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Icon(Icons.chevron_right, color: fg.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
