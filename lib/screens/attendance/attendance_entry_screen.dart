import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/contact_actions.dart';
import '../../models/contact_number.dart';

/// Mark / review attendance for one set of students on one date. The set is either an attendance batch
/// ([attBatchId], the green/red cards) or a Class/Section/Batch filter — same data the web page shows.
/// A day that was already marked opens pre-filled (and can be corrected and saved again); an unmarked
/// day starts with everyone on Present until saved.
class AttendanceEntryScreen extends StatefulWidget {
  const AttendanceEntryScreen({
    super.key,
    required this.title,
    required this.date,
    this.attBatchId,
    this.classId,
    this.sectionId,
    this.batchId,
    this.session = 1,
  });

  final String title;
  final DateTime date;
  /// Lecture of the day to open (1 = first). A Sunday / holiday class can have 2 or more.
  final int session;
  final int? attBatchId;
  final int? classId;
  final int? sectionId;
  final int? batchId;

  @override
  State<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends State<AttendanceEntryScreen> {
  final _service = AttendanceService();

  late DateTime _date = DateUtils.dateOnly(widget.date);
  late int _lecture = widget.session;
  List<int> _doneLectures = [];
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  List<AttendanceRecord> _records = [];
  final Map<int, String> _statuses = {};
  int _alreadyMarked = 0;
  bool _isHoliday = false;
  String _holidayReason = '';

  // Lecture details (saved on every row, same as the web page).
  AttendanceOptions _options = AttendanceOptions(subjects: [], teachers: []);
  String? _subject;
  String? _sirName;
  TimeOfDay? _start;
  TimeOfDay? _end;

  final Map<int, List<ContactNumber>> _contactCache = {};

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _load();
  }

  Future<void> _loadOptions() async {
    try {
      final o = await _service.getOptions();
      if (mounted) setState(() => _options = o);
    } on ApiException {
      // Lecture details stay free of choices; attendance itself still works.
    }
  }

  TimeOfDay? _parseTime(String? v) {
    if (v == null || v.isEmpty) return null;
    final p = v.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _fmtTime(TimeOfDay? t) =>
      t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = widget.attBatchId != null
          ? await _service.getBatchDetail(widget.attBatchId!, _date, session: _lecture)
          : await _service.getForDate(date: _date, classId: widget.classId, sectionId: widget.sectionId, batchId: widget.batchId, session: _lecture);
      if (!mounted) return;
      setState(() {
        _records = r.records;
        _statuses
          ..clear()
          ..addEntries(r.records.map((e) => MapEntry(e.studentId, e.attendanceStatus)));
        _alreadyMarked = r.totalMarked;
        _isHoliday = r.isHoliday;
        _holidayReason = r.holidayReason;
        _doneLectures = r.doneSessions;
        // A marked day brings its own lecture details; an empty day keeps what was already picked.
        if (r.totalMarked > 0) {
          _subject = r.subject;
          _sirName = r.sirName;
          _start = _parseTime(r.startTime);
          _end = _parseTime(r.endTime);
        }
        _dirty = false;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  // ── Holiday: "no class for this batch today" (same as the website's batch page) ─────────────────
  bool get _canHoliday =>
      widget.attBatchId != null && !context.read<Session>().isClassRep && !_date.isAfter(DateUtils.dateOnly(DateTime.now()));

  Future<void> _markHoliday() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Holiday for ${widget.title}?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('There is no class for this batch on this date. The parents of its students are notified.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason (optional)', hintText: 'Shown to parents')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark holiday')),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (ok != true) return;
    try {
      if (!mounted) return;
      final n = await withLoader(context, () => _service.markHoliday(widget.attBatchId!, _date, reason: text.isEmpty ? null : text));
      if (!mounted) return;
      showSnack(context, n > 0 ? 'Holiday marked. $n parent login(s) were told there is no class.' : 'Holiday marked.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _cancelHoliday() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel the holiday?'),
        content: const Text('The parents are told that the class is on.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel holiday', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (!mounted) return;
      await withLoader(context, () => _service.cancelHoliday(widget.attBatchId!, _date));
      if (!mounted) return;
      showSnack(context, 'Holiday cancelled. Parents were told the class is on.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Widget _holidayBanner() => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), border: Border.all(color: const Color(0xFFFBBF24), width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(children: [
          const Text('🏖', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Holiday - no class for this batch', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
              Text(_holidayReason.isEmpty ? 'Parents were told there is no class.' : '$_holidayReason - parents were told there is no class.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E))),
            ]),
          ),
          if (_canHoliday) TextButton(onPressed: _cancelHoliday, child: const Text('Cancel holiday', style: TextStyle(color: AppColors.danger))),
        ]),
      );

  Widget _markHolidayBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Row(children: [
          const Expanded(child: Text('No class for this batch today?', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
          OutlinedButton.icon(
            // The app theme gives every outlined button a full-width minimum (Size.fromHeight). Inside a Row that
            // squeezes the Expanded text above to zero width (letters stack vertically, list disappears) on
            // some devices — so this button must opt out of the full-width minimum.
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
              side: const BorderSide(color: Color(0xFFFBBF24)),
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _markHoliday,
            icon: const Icon(Icons.beach_access_outlined, size: 18),
            label: const Text('Mark Holiday'),
          ),
        ]),
      );

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Attendance changes on this screen have not been saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _changeDate(DateTime d) async {
    final day = DateUtils.dateOnly(d);
    if (day.isAfter(DateUtils.dateOnly(DateTime.now()))) return;
    if (DateUtils.isSameDay(day, _date)) return;
    final session = context.read<Session>();
    if (session.isClassRep && day.isBefore(session.crEarliestDate)) return;   // a CR works on the last few days only
    if (!await _confirmDiscard()) return;
    setState(() { _date = day; _lecture = 1; });   // a new day starts at its first lecture
    _load();
  }

  Future<void> _changeLecture(int n) async {
    if (n == _lecture) return;
    if (!await _confirmDiscard()) return;
    setState(() { _lecture = n; _subject = null; _sirName = null; _start = null; _end = null; });
    _load();
  }

  Future<void> _pickDate() async {
    final session = context.read<Session>();
    final first = session.isClassRep ? session.crEarliestDate : DateTime(2020);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: first,
      lastDate: DateTime.now(),
      helpText: 'Attendance date',
    );
    if (picked != null) _changeDate(picked);
  }

  void _setStatus(int studentId, String status) => setState(() { _statuses[studentId] = status; _dirty = true; });

  void _markAll(String status) => setState(() {
        for (final r in _records) { _statuses[r.studentId] = status; }
        _dirty = true;
      });

  int _count(String s) => _statuses.values.where((v) => v == s).length;

  Future<void> _save() async {
    if (_records.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final message = await _service.save(
        date: _date,
        classId: widget.classId,
        sectionId: widget.sectionId,
        batchId: widget.batchId,
        attBatchId: widget.attBatchId,
        session: _lecture,
        subject: _subject,
        sirName: _sirName,
        startTime: _fmtTime(_start),
        endTime: _fmtTime(_end),
        entries: _records
            .map((r) => {'studentId': r.studentId, 'status': _statuses[r.studentId] ?? 'Present', 'remarks': r.remarks})
            .toList(),
      );
      if (!mounted) return;
      showSnack(context, message);
      setState(() => _dirty = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<ContactNumber>?> _contactsFor(AttendanceRecord r) async {
    final cached = _contactCache[r.studentId];
    if (cached != null) return cached;
    try {
      final c = await _service.getStudentContact(r.studentId);
      final list = buildContacts(father: c.father, mother: c.mother, student: c.student);
      _contactCache[r.studentId] = list;
      return list;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
      return null;
    }
  }

  Future<void> _call(AttendanceRecord r) async {
    final contacts = await _contactsFor(r);
    if (contacts == null || !mounted) return;
    await ContactActions.call(context, name: r.fullName, contacts: contacts);
  }

  Future<void> _whatsapp(AttendanceRecord r) async {
    final contacts = await _contactsFor(r);
    if (contacts == null || !mounted) return;
    await ContactActions.whatsapp(
      context,
      name: r.fullName,
      contacts: contacts,
      category: 'Absent',
      vars: ContactActions.baseVars(student: r.fullName, className: r.className, medium: r.sectionName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
        body: Column(
          children: [
            _dateBar(),
            Expanded(child: _body()),
          ],
        ),
        bottomNavigationBar: _records.isEmpty || _isHoliday
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_alreadyMarked > 0 ? 'Update Attendance (${_records.length})' : 'Save Attendance (${_records.length})'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _dateBar() => Column(
        children: [
          AttendanceDateBar(date: _date, onChanged: _changeDate, onPick: _pickDate),
          LectureBar(selected: _lecture, done: _doneLectures, onChanged: _changeLecture),
          if (!_loading && _error == null && _isHoliday) _holidayBanner() else if (!_loading && _error == null && _canHoliday) _markHolidayBar(),
        ],
      );

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_isHoliday) return const SizedBox.shrink();   // holiday: the banner above says it, no entry list
    if (_records.isEmpty) {
      return const EmptyState(message: 'No active students found here.', icon: Icons.groups_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          _statusBanner(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: StatCard(label: 'Present', value: '${_count('Present')}', color: AppColors.present, icon: Icons.check_circle_outline)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Absent', value: '${_count('Absent')}', color: AppColors.absent, icon: Icons.cancel_outlined)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(label: 'Late', value: '${_count('Late')}', color: AppColors.late, icon: Icons.schedule_outlined)),
            ],
          ),
          const SizedBox(height: 10),
          _lectureDetails(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markAll('Present'),
                  icon: const Icon(Icons.check, size: 18, color: AppColors.present),
                  label: const Text('All Present', style: TextStyle(color: AppColors.present)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markAll('Absent'),
                  icon: const Icon(Icons.close, size: 18, color: AppColors.absent),
                  label: const Text('All Absent', style: TextStyle(color: AppColors.absent)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in _records) ...[
            _StudentAttendanceTile(
              record: r,
              status: _statuses[r.studentId] ?? 'Present',
              onChanged: (s) => _setStatus(r.studentId, s),
              onCall: () => _call(r),
              onWhatsapp: () => _whatsapp(r),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final marked = _alreadyMarked > 0;
    final pending = _records.length - _alreadyMarked;
    final color = marked ? AppColors.success : AppColors.danger;
    final soft = marked ? AppColors.successSoft : AppColors.dangerSoft;
    final lecture = _lecture > 1 ? ' (${LectureBar.ordinal(_lecture)} lecture)' : '';
    final text = !marked
        ? 'Attendance not taken for ${DateFormat('d MMM').format(_date)}$lecture — everyone starts as Present until you save.'
        : pending > 0
            ? 'Attendance taken$lecture · $pending student${pending == 1 ? '' : 's'} still not saved (shown as Present).'
            : 'Attendance already taken for ${DateFormat('d MMM').format(_date)}$lecture — you can correct it and update.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Row(
        children: [
          Icon(marked ? Icons.check_circle : Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5))),
        ],
      ),
    );
  }

  Widget _lectureDetails() {
    final subjects = {..._options.subjects, if (_subject != null && _subject!.isNotEmpty) _subject!}.toList();
    final teachers = [
      ..._options.teachers,
      if (_sirName != null && _sirName!.isNotEmpty && !_options.teachers.any((t) => t.fullName == _sirName))
        AttendanceTeacher(fullName: _sirName!, displayName: _sirName!),
    ];
    final summary = [
      if (_subject != null && _subject!.isNotEmpty) _subject!.trim(),
      if (_sirName != null && _sirName!.isNotEmpty) _sirName!.trim(),
      if (_start != null || _end != null) '${_start?.format(context) ?? '—'} → ${_end?.format(context) ?? '—'}',
    ].join(' · ');

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: const Icon(Icons.menu_book_outlined, color: AppColors.primary),
          title: const Text('Lecture details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(summary.isEmpty ? 'Subject, faculty and timing (optional)' : summary,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: subjects.contains(_subject) ? _subject : null,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— Select Subject —')),
                ...subjects.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s.trim(), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() { _subject = v; _dirty = true; }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: teachers.any((t) => t.fullName == _sirName) ? _sirName : null,
              decoration: const InputDecoration(labelText: 'Faculty name'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— Select Teacher —')),
                ...teachers.map((t) => DropdownMenuItem<String?>(value: t.fullName, child: Text(t.displayName, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() { _sirName = v; _dirty = true; }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _timeField('Start time', _start, (t) => setState(() { _start = t; _dirty = true; }))),
                const SizedBox(width: 12),
                Expanded(child: _timeField('End time', _end, (t) => setState(() { _end = t; _dirty = true; }))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? value, ValueChanged<TimeOfDay?> onChanged) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: value ?? TimeOfDay.now());
        if (t != null) onChanged(t);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.access_time, size: 18)
              : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => onChanged(null)),
        ),
        child: Text(value == null ? '—' : value.format(context)),
      ),
    );
  }
}

/// ‹ [date] › bar with Today / Yesterday chips — shared by the attendance list and entry screens so the
/// previous-day review works the same everywhere. Future dates are never selectable.
/// "1st lecture / 2nd lecture / + Add" chips: a Sunday or holiday class can meet more than once a day and each
/// lecture has its own attendance (who came to the 1st, who to the 2nd). A tick marks lectures already taken.
class LectureBar extends StatelessWidget {
  const LectureBar({super.key, required this.selected, required this.done, required this.onChanged});
  final int selected;
  final List<int> done;
  final ValueChanged<int> onChanged;

  static const maxLectures = 6;

  static String ordinal(int n) => n == 1 ? '1st' : n == 2 ? '2nd' : n == 3 ? '3rd' : '${n}th';

  @override
  Widget build(BuildContext context) {
    final last = [selected, if (done.isNotEmpty) done.reduce((a, b) => a > b ? a : b), 1].reduce((a, b) => a > b ? a : b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          for (var n = 1; n <= last; n++) ...[
            ChoiceChip(
              label: Text('${ordinal(n)} lecture'),
              avatar: done.contains(n) ? const Icon(Icons.check_circle, size: 16, color: AppColors.success) : null,
              selected: selected == n,
              onSelected: (_) => onChanged(n),
            ),
            const SizedBox(width: 8),
          ],
          if (last < maxLectures)
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text('Add ${ordinal(last + 1)} lecture'),
              onPressed: () => onChanged(last + 1),
            ),
        ],
      ),
    );
  }
}

class AttendanceDateBar extends StatelessWidget {
  const AttendanceDateBar({super.key, required this.date, required this.onChanged, required this.onPick, this.allowFuture = false});
  final bool allowFuture;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(date, today);
    final isYesterday = DateUtils.isSameDay(date, today.subtract(const Duration(days: 1)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Previous day',
                onPressed: () => onChanged(date.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: InkWell(
                  onTap: onPick,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(DateFormat('d MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                        Text(DateFormat('EEEE').format(date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Next day',
                onPressed: (isToday && !allowFuture) ? null : () => onChanged(date.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(label: const Text('Today'), selected: isToday, onSelected: (_) => onChanged(today)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Yesterday'), selected: isYesterday, onSelected: (_) => onChanged(today.subtract(const Duration(days: 1)))),
              const SizedBox(width: 8),
              if (allowFuture) ...[
                ChoiceChip(label: const Text('Tomorrow'), selected: DateUtils.isSameDay(date, today.add(const Duration(days: 1))), onSelected: (_) => onChanged(today.add(const Duration(days: 1)))),
                const SizedBox(width: 8),
              ],
              ActionChip(avatar: const Icon(Icons.history, size: 16), label: const Text('Pick date'), onPressed: onPick),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentAttendanceTile extends StatelessWidget {
  const _StudentAttendanceTile({
    required this.record,
    required this.status,
    required this.onChanged,
    required this.onCall,
    required this.onWhatsapp,
  });
  final AttendanceRecord record;
  final String status;
  final ValueChanged<String> onChanged;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;

  @override
  Widget build(BuildContext context) {
    final sub = [
      record.admissionNo,
      if (record.rollNo?.isNotEmpty == true) 'Roll ${record.rollNo}',
      if (record.className?.isNotEmpty == true) record.className!,
    ].where((e) => e.isNotEmpty).join(' • ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                ProfileAvatar(name: record.fullName, photoPath: record.profilePicPath, size: 40, background: AppColors.primarySoft, foreground: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.fullName, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Call',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCall,
                  icon: const Icon(Icons.call, color: AppColors.info, size: 22),
                ),
                IconButton(
                  tooltip: 'WhatsApp',
                  visualDensity: VisualDensity.compact,
                  onPressed: onWhatsapp,
                  icon: const Icon(Icons.chat, color: whatsappGreen, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                children: [
                  Expanded(child: _statusButton('Present', AppColors.present, Icons.check)),
                  const SizedBox(width: 8),
                  Expanded(child: _statusButton('Absent', AppColors.absent, Icons.close)),
                  const SizedBox(width: 8),
                  Expanded(child: _statusButton('Late', AppColors.late, Icons.schedule)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(String value, Color color, IconData icon) {
    final selected = status == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: selected ? 0 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
