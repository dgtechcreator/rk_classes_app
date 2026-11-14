import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/classroom_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/common.dart';

String _ap(String t) {
  final p = t.split(':');
  if (p.length < 2) return t;
  final h = int.tryParse(p[0]) ?? 0, m = int.tryParse(p[1]) ?? 0;
  return '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// Classrooms: the live board (free / engaged now, until when, which lecture), the room history, and (for those who may
/// edit the schedule) the list of rooms to add, edit or delete.
class ClassroomScreen extends StatelessWidget {
  const ClassroomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canEdit = context.read<Session>().hasEditPerm('lecture_schedule');
    return DefaultTabController(
      length: canEdit ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Classrooms'),
          bottom: TabBar(tabs: [const Tab(text: 'Live board'), const Tab(text: 'History'), if (canEdit) const Tab(text: 'Rooms')]),
        ),
        body: TabBarView(children: [const _BoardTab(), const _HistoryTab(), if (canEdit) const _RoomsTab()]),
      ),
    );
  }
}

// ───────────────────────────── Live board ─────────────────────────────

class _BoardTab extends StatefulWidget {
  const _BoardTab();
  @override
  State<_BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<_BoardTab> with AutomaticKeepAliveClientMixin {
  final _service = ClassroomService();
  final _search = TextEditingController();
  String _q = '';
  BoardData? _data;
  DateTime? _date; // null = now
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) { if (mounted && _date == null) _load(silent: true); });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = _data == null; _error = null; });
    try {
      final d = await _service.board(date: _date);
      if (mounted) setState(() { _data = d; _loading = false; });
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (p != null) { setState(() => _date = DateUtils.isSameDay(p, DateTime.now()) ? null : p); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final d = _data;
    final rooms = d == null ? <RoomState>[] : d.rooms.where((r) => matchesSearch(_q, [r.name, r.location, r.current?.teacher, r.current?.subject, r.current?.groupLabel])).toList();
    return Column(children: [
      ListSearchField(controller: _search, onChanged: (v) => setState(() => _q = v), hint: 'Search room, teacher, subject, class...'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(children: [
          ActionChip(avatar: const Icon(Icons.calendar_today_outlined, size: 16), label: Text(_date == null ? 'Today · now' : DateFormat('EEE, d MMM yyyy').format(_date!)), onPressed: _pickDate),
          if (_date != null) TextButton(onPressed: () { setState(() => _date = null); _load(); }, child: const Text('Back to now')),
          const Spacer(),
          if (d != null && d.isToday) ...[
            _count('${d.busy}', 'Engaged', AppColors.danger),
            const SizedBox(width: 12),
            _count('${d.free}', 'Free', AppColors.success),
          ],
        ]),
      ),
      Expanded(
        child: _loading
            ? const LoadingView()
            : _error != null && d == null
                ? ErrorView(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: rooms.isEmpty
                        ? ListView(children: const [SizedBox(height: 60), EmptyState(message: 'No classrooms to show.\nAdd rooms under the "Rooms" tab.', icon: Icons.meeting_room_outlined)])
                        : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), itemCount: rooms.length, itemBuilder: (_, i) => _roomCard(rooms[i], d!)),
                  ),
      ),
    ]);
  }

  Widget _count(String n, String label, Color c) => Column(children: [
        Text(n, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
      ]);

  Widget _lectureLine(RoomLecture l, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${l.subject} · ${l.teacher ?? ''}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: color)),
        Text('${l.groupLabel} · ${_ap(l.startTime)} - ${_ap(l.endTime)}${(l.topic ?? '').isNotEmpty ? ' · ${l.topic}' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]);

  Widget _roomCard(RoomState r, BoardData d) {
    final busy = r.busy;
    final accent = busy ? AppColors.danger : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft, border: Border(left: BorderSide(color: accent, width: 5))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(children: [
            Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            if (d.isToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(busy ? 'ENGAGED' : 'FREE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent)),
              ),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((r.location ?? '').isNotEmpty || r.capacity != null)
                Text([if ((r.location ?? '').isNotEmpty) r.location!, if (r.capacity != null) '${r.capacity} seats'].join(' · '), style: const TextStyle(fontSize: 12)),
              if (busy && r.current != null) ...[
                const SizedBox(height: 6),
                _lectureLine(r.current!),
                Text('Engaged until ${_ap(r.busyUntil ?? r.current!.endTime)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.danger)),
              ] else if (d.isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(r.next != null ? 'Free until ${_ap(r.next!.startTime)}' : 'Free for the rest of the day', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                ),
              if (r.next != null && (busy || !d.isToday)) ...[
                const SizedBox(height: 6),
                Text(d.isToday ? 'NEXT' : 'FIRST', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
                _lectureLine(r.next!),
              ] else if (r.next != null) ...[
                const SizedBox(height: 6),
                const Text('NEXT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
                _lectureLine(r.next!),
              ],
            ]),
          ),
          children: [
            if (r.day.isEmpty)
              const Align(alignment: Alignment.centerLeft, child: Text('No lectures planned in this room that day.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)))
            else ...[
              Align(alignment: Alignment.centerLeft, child: Text("Day plan (${r.day.length})", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
              const SizedBox(height: 4),
              for (final l in r.day)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${_ap(l.startTime)}-${_ap(l.endTime)} · ${l.subject} · ${l.groupLabel} · ${l.teacher ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: l.phase == 'ongoing' ? FontWeight.w800 : FontWeight.w400,
                        color: l.phase == 'ongoing' ? AppColors.danger : (l.phase == 'ended' || l.phase == 'done') ? AppColors.textMuted : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── History ─────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> with AutomaticKeepAliveClientMixin {
  final _service = ClassroomService();
  final _search = TextEditingController();
  Timer? _debounce;
  List<Classroom> _rooms = [];
  int? _roomId;
  late DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  late DateTime _to = DateTime.now().add(const Duration(days: 7));
  RoomHistory? _data;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _service.list(all: true).then((r) { if (mounted) setState(() => _rooms = r); }).catchError((_) {});
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = _data == null; _error = null; });
    try {
      final d = await _service.history(classroomId: _roomId, from: _from, to: _to, q: _search.text);
      if (mounted) setState(() { _data = d; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _pick(bool isFrom) async {
    final p = await showDatePicker(context: context, initialDate: isFrom ? _from : _to, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (p == null) return;
    setState(() { if (isFrom) { _from = p; if (_to.isBefore(p)) _to = p; } else { _to = p; if (_from.isAfter(p)) _from = p; } });
    _load();
  }

  static (String, Color) _phase(String p) => switch (p) {
        'done' => ('Held', AppColors.success),
        'ended' => ('Not updated', AppColors.warning),
        'ongoing' => ('Ongoing', AppColors.danger),
        'upcoming' => ('Upcoming', AppColors.info),
        _ => ('Cancelled', AppColors.textMuted),
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final d = _data;
    final fmt = DateFormat('d MMM yyyy');
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: AppDropdown<int?>(
          initialValue: _roomId,
          alwaysSearch: true,
          decoration: const InputDecoration(labelText: 'Classroom', isDense: true),
          items: [const DropdownMenuItem<int?>(value: null, child: Text('All classrooms')), for (final r in _rooms) DropdownMenuItem<int?>(value: r.id, child: Text(r.name))],
          onChanged: (v) { setState(() => _roomId = v); _load(); },
        ),
      ),
      ListSearchField(controller: _search, onChanged: (_) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 400), _load); }, hint: 'Search teacher, subject, class...'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Row(children: [
          ActionChip(avatar: const Icon(Icons.date_range, size: 16), label: Text('From ${fmt.format(_from)}'), onPressed: () => _pick(true)),
          const SizedBox(width: 8),
          ActionChip(avatar: const Icon(Icons.date_range, size: 16), label: Text('To ${fmt.format(_to)}'), onPressed: () => _pick(false)),
        ]),
      ),
      if (d != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: Align(alignment: Alignment.centerLeft, child: Text('${d.count} lectures · ${d.hours.toStringAsFixed(1)} hours (cancelled not counted)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)))),
      Expanded(
        child: _loading
            ? const LoadingView()
            : _error != null && d == null
                ? ErrorView(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: d == null || d.lectures.isEmpty
                        ? ListView(children: const [SizedBox(height: 60), EmptyState(message: 'No lectures found for this selection.', icon: Icons.history)])
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: d.lectures.length,
                            itemBuilder: (_, i) {
                              final l = d.lectures[i];
                              final (label, color) = _phase(l.phase);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text('${l.classroom ?? ''} · ${DateFormat('EEE, d MMM yyyy').format(l.date)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
                                      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text('${_ap(l.startTime)} - ${_ap(l.endTime)} · ${l.subject}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text('${l.teacher ?? ''} · ${l.groupLabel}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                                  if ((l.topic ?? '').isNotEmpty) Text('Topic: ${l.topic}', style: const TextStyle(fontSize: 12.5)),
                                  if ((l.statusNote ?? '').isNotEmpty) Text('Note: ${l.statusNote}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ]),
                              );
                            },
                          ),
                  ),
      ),
    ]);
  }
}

// ───────────────────────────── Manage rooms ─────────────────────────────

class _RoomsTab extends StatefulWidget {
  const _RoomsTab();
  @override
  State<_RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<_RoomsTab> with AutomaticKeepAliveClientMixin {
  final _service = ClassroomService();
  List<Classroom> _rooms = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _rooms.isEmpty; _error = null; });
    try {
      final r = await _service.list(all: true);
      if (mounted) setState(() { _rooms = r; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _form([Classroom? c]) async {
    final name = TextEditingController(text: c?.name ?? '');
    final loc = TextEditingController(text: c?.location ?? '');
    final cap = TextEditingController(text: c?.capacity?.toString() ?? '');
    bool active = c?.isActive ?? true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(c == null ? 'Add classroom' : 'Edit classroom', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name * (e.g. Room 101)')),
              const SizedBox(height: 12),
              TextField(controller: loc, decoration: const InputDecoration(labelText: 'Floor / building')),
              const SizedBox(height: 12),
              TextField(controller: cap, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seats')),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active (can be picked for lectures)'), value: active, onChanged: (v) => setS(() => active = v)),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (name.text.trim().isEmpty) { showSnack(context, 'Enter the classroom name.', isError: true); return; }
    try {
      await _service.save(id: c?.id ?? 0, name: name.text.trim(), location: loc.text.trim().isEmpty ? null : loc.text.trim(), capacity: int.tryParse(cap.text.trim()), isActive: active);
      if (mounted) { showSnack(context, c == null ? 'Classroom added.' : 'Classroom updated.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _delete(Classroom c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete classroom?'),
        content: Text('${c.name} will be removed. Old lectures keep their record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.delete(c.id);
      if (mounted) { showSnack(context, 'Classroom deleted.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _form(), icon: const Icon(Icons.add), label: const Text('Add classroom')),
      body: _loading
          ? const LoadingView()
          : _error != null && _rooms.isEmpty
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _rooms.isEmpty
                      ? ListView(children: const [SizedBox(height: 60), EmptyState(message: 'No classrooms yet.\nTap "Add classroom" - Room 101, Lab, Hall ...', icon: Icons.meeting_room_outlined)])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                          itemCount: _rooms.length,
                          itemBuilder: (_, i) {
                            final c = _rooms[i];
                            return Card(
                              child: ListTile(
                                onTap: () => _form(c),
                                leading: CircleAvatar(backgroundColor: c.isActive ? AppColors.primarySoft : AppColors.border, child: Icon(Icons.meeting_room_outlined, color: c.isActive ? AppColors.primary : AppColors.textSecondary)),
                                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text([if ((c.location ?? '').isNotEmpty) c.location!, if (c.capacity != null) '${c.capacity} seats', if (!c.isActive) 'Switched off'].join(' · ')),
                                trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _delete(c)),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
