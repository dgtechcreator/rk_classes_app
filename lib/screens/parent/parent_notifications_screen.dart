import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/parent_data_controller.dart';
import '../../core/parent_notification_controller.dart';
import '../../models/student_activity.dart';
import '../../services/parent_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Everything that happened to my children: absent / present, marks, fees received, lectures scheduled or cancelled.
/// Newest first, grouped by day; the unread ones are tinted. Opening it clears the bell badge.
class ParentNotificationsScreen extends StatefulWidget {
  const ParentNotificationsScreen({super.key});

  @override
  State<ParentNotificationsScreen> createState() => _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState extends State<ParentNotificationsScreen> {
  final _service = ParentService();
  bool _loading = true;
  String? _error;
  List<StudentActivity> _items = [];
  int? _childId;            // null = all children
  ActivityGroup? _group;    // null = all kinds

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _items.isEmpty; _error = null; });
    try {
      final r = await _service.getNotifications();
      if (!mounted) return;
      setState(() { _items = r.items; _loading = false; });
      if (r.unread > 0) {
        // the list keeps showing which ones were new for this visit; only the badge is cleared
        context.read<ParentNotificationController>().markAllSeen();
        _service.markNotificationsRead().catchError((_) {});
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  List<StudentActivity> get _visible => _items
      .where((a) => (_childId == null || a.studentId == _childId) && (_group == null || a.look.group == _group))
      .toList();

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, d MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final children = context.watch<ParentDataController>().children;
    final visible = _visible;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const LoadingView()
          : _error != null && _items.isEmpty
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                    children: [
                      if (children.length > 1)
                        _ChipRow(
                          children: [
                            _FilterChip(label: 'All children', selected: _childId == null, onTap: () => setState(() => _childId = null)),
                            for (final c in children)
                              _FilterChip(
                                label: c.displayName.split(' ').where((w) => w.isNotEmpty).take(2).join(' '),
                                selected: _childId == c.studentId,
                                onTap: () => setState(() => _childId = c.studentId),
                              ),
                          ],
                        ),
                      _ChipRow(
                        children: [
                          _FilterChip(label: 'All', selected: _group == null, onTap: () => setState(() => _group = null)),
                          for (final g in ActivityGroup.values)
                            _FilterChip(label: g.label, selected: _group == g, onTap: () => setState(() => _group = g)),
                        ],
                      ),
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: EmptyState(
                            message: 'No notifications yet.\nAttendance, marks, fees and lecture updates of your child will show here.',
                            icon: Icons.notifications_none_rounded,
                          ),
                        )
                      else
                        ..._grouped(visible, showChild: children.length > 1),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _grouped(List<StudentActivity> items, {required bool showChild}) {
    final out = <Widget>[];
    String? last;
    for (final a in items) {
      final label = _dayLabel(a.createdAt);
      if (label != last) {
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
          child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted)),
        ));
        last = label;
      }
      out.add(_ActivityTile(a: a, showChild: showChild));
    }
    return out;
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.primary : AppColors.borderNeutral),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.a, required this.showChild});
  final StudentActivity a;
  final bool showChild;

  @override
  Widget build(BuildContext context) {
    final look = a.look;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: a.isUnread ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: a.isUnread ? AppColors.border : AppColors.borderNeutral),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: look.soft, borderRadius: BorderRadius.circular(12)),
            child: Icon(look.icon, color: look.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                          if (a.isUnread) ...[
                            const SizedBox(width: 6),
                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(DateFormat('h:mm a').format(a.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(a.message, style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.textPrimary)),
                if (showChild && a.studentName.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(a.studentName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.info)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
