import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/realtime_notification_service.dart';
import '../../models/student_activity.dart';
import '../../models/task_notification.dart';
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class TasksNotificationsScreen extends StatefulWidget {
  /// [active] is false while the screen sits hidden in the bottom-tab stack: it still loads (so the list is ready), but only
  /// marks the notifications as read once the tab is actually opened.
  const TasksNotificationsScreen({super.key, this.active = true});
  final bool active;

  @override
  State<TasksNotificationsScreen> createState() => _TasksNotificationsScreenState();
}

class _TasksNotificationsScreenState extends State<TasksNotificationsScreen> with SingleTickerProviderStateMixin {
  final _service = TaskService();
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  List<AppNotification> _notifications = [];
  List<TaskItem> _tasks = [];
  int _liveCount = -1;
  final _newIds = <int>{};   // unread when this visit began: keep them highlighted although the server already marked them read

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void didUpdateWidget(covariant TasksNotificationsScreen old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) _load();   // tab just opened: show the latest and mark it read
    if (old.active && !widget.active) _newIds.clear();   // leaving the tab: what was new has been seen
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // a notification arrived over SignalR (a lecture given to this teacher...): reload the list
    final live = context.watch<RealtimeNotificationService>().notifications.length;
    if (_liveCount != -1 && live != _liveCount) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    _liveCount = live;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = _notifications.isEmpty && _tasks.isEmpty; _error = null; });
    try {
      final data = await _service.getNotifications();
      if (!mounted) return;
      final fresh = data.notifications.where((n) => n.isUnread).map((n) => n.notificationId);
      setState(() { _notifications = data.notifications; _tasks = data.tasks; _loading = false; _newIds.addAll(fresh); });
      if (widget.active && data.notifications.any((n) => n.isUnread)) {
        final live = context.read<RealtimeNotificationService>();
        live.markAllReadLocally();
        _service.markAllNotificationsRead().then((_) => live.refresh()).catchError((_) {});
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (!n.isUnread) return;
    try {
      await _service.markNotificationRead(n.notificationId);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _dismiss(AppNotification n) async {
    try {
      await _service.dismissNotification(n.notificationId);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _completeTask(TaskItem t) async {
    try {
      await _service.completeTask(t.taskId);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _deleteTask(TaskItem t) async {
    try {
      await _service.deleteTask(t.taskId);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _openCreateTask() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateTaskSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks & Notifications'),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: 'Notifications'),
          Tab(text: 'Tasks'),
        ]),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _openCreateTask, child: const Icon(Icons.add)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : TabBarView(controller: _tabController, children: [_buildNotificationsTab(), _buildTasksTab()]),
    );
  }

  static ActivityLook _lookOf(String type) => switch (type) {
        'Lecture' => ActivityLook.of('lecture'),
        'FeesDue' => ActivityLook.of('fee'),
        'Attendance' => ActivityLook.of('absent'),
        _ => const ActivityLook(Icons.notifications_rounded, AppColors.info, AppColors.infoSoft, ActivityGroup.attendance),
      };

  Widget _buildNotificationsTab() {
    if (_notifications.isEmpty) return const EmptyState(message: 'No notifications yet.', icon: Icons.notifications_none);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final n = _notifications[i];
          final look = _lookOf(n.type);
          final isNew = n.isUnread || _newIds.contains(n.notificationId);
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 2, 10),
            decoration: BoxDecoration(
              color: isNew ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: isNew ? AppColors.border : AppColors.borderNeutral),
            ),
            child: InkWell(
              onTap: () => _markRead(n),
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
                        Text(n.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(n.message, style: const TextStyle(fontSize: 13, height: 1.35)),
                        const SizedBox(height: 4),
                        Text(DateFormat('d MMM, h:mm a').format(n.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: () => _dismiss(n)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty) return const EmptyState(message: 'No tasks yet. Tap + to create one.', icon: Icons.checklist_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = _tasks[i];
          return Card(
            child: ListTile(
              title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${t.studentName != null ? '${t.studentName} • ' : ''}Due ${DateFormat.yMMMd().format(t.dueDate)}'),
              leading: StatusBadge(status: t.status),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.check_circle_outline, color: AppColors.success), onPressed: () => _completeTask(t)),
                  IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _deleteTask(t)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreateTaskSheet extends StatefulWidget {
  const _CreateTaskSheet();

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _service = TaskService();
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime _dueDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showSnack(context, 'Title is required.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createTask(title: _title.text.trim(), description: _description.text.trim(), dueDate: _dueDate);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)', alignLabelWithHint: true)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due Date'),
            subtitle: Text(DateFormat.yMMMd().format(_dueDate)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Task'),
          ),
        ],
      ),
    );
  }
}
