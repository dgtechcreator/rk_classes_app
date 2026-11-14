import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/realtime_notification_service.dart';
import '../../core/session.dart';
import '../../models/student_activity.dart';
import '../../models/task_notification.dart';
import '../../services/task_service.dart';
import '../teacher_attendance/my_attendance_log_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'send_notification_screen.dart';
/// Icon and colours of a staff notification by its type (also used by the Home card).
ActivityLook notificationLook(String type) => switch (type) {
  'Lecture' => ActivityLook.of('lecture'),
  'FeesDue' => ActivityLook.of('fee'),
  'Attendance' => ActivityLook.of('absent'),
  'TeacherAttendance' => ActivityLook.of('absent'),
  'Announcement' => ActivityLook.of('notice'),
  _ => const ActivityLook(Icons.notifications_rounded, AppColors.info, AppColors.infoSoft, ActivityGroup.attendance),
};

/// Notifications (first tab) and Tasks (second tab).
/// - A notification stays UNREAD (tinted, blue dot, bold) until the user taps it or taps "Mark all read" - opening the tab
///   does not read anything. The badge on the bottom bar / bell counts only the unread notifications.
/// - The "+" button is context aware: on Notifications the admin gets "Send" (a message to everybody / a group / chosen people),
///   on Tasks everybody gets "add a task".
class TasksNotificationsScreen extends StatefulWidget {
  /// [active] is false while the screen sits hidden in the bottom-tab stack: it still loads, and reloads when the tab opens.
  const TasksNotificationsScreen({
    super.key,
    this.active = true,
    this.initialTab = 0,
  });
  final bool active;
  final int initialTab;

  @override
  State<TasksNotificationsScreen> createState() =>
      _TasksNotificationsScreenState();
}

class _TasksNotificationsScreenState extends State<TasksNotificationsScreen>
    with SingleTickerProviderStateMixin {
  final _service = TaskService();
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  List<AppNotification> _notifications = [];
  List<TaskItem> _tasks = [];
  int _liveCount = -1;

  int get _unread => _notifications.where((n) => n.isUnread).length;
  int get _pending => _tasks.where((t) => !t.isCompleted).length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    }); // the "+" button follows the tab
    _load();
  }

  @override
  void didUpdateWidget(covariant TasksNotificationsScreen old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active)
      _load(); // tab just opened: show the latest
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // a notification arrived over SignalR (a lecture given to this teacher...): reload the list
    final live = context
        .watch<RealtimeNotificationService>()
        .notifications
        .length;
    if (_liveCount != -1 && live != _liveCount)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    _liveCount = live;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _notifications.isEmpty && _tasks.isEmpty;
      _error = null;
    });
    try {
      final data = await _service.getNotifications();
      // Tasks tab shows ALL tasks (completed ones stay, faded). data.tasks is only the pending ones.
      final allTasks = await _service.getTasks();
      if (!mounted) return;
      setState(() {
        _notifications = data.notifications;
        _tasks = allTasks;
        _loading = false;
      });
      // keep the bell / bottom-bar badge exactly equal to what this list shows
      context.read<RealtimeNotificationService>().setCounts(
        unread: data.unreadNotifications,
        tasks: data.pendingTasks,
      );
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _error = e.message;
          _loading = false;
        });
    }
  }

  /// Tap on a notification: it turns read at once (list + badge); the server is told in the background.
  Future<void> _markRead(AppNotification n) async {
    if (!n.isUnread) return;
    final live = context.read<RealtimeNotificationService>();
    setState(() => n.status = 'Read');
    live.markReadLocally(n.notificationId);
    try {
      await _service.markNotificationRead(n.notificationId);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => n.status = 'Unread',
      ); // could not save: show it as unread again
      live.refresh();
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _markAllRead() async {
    if (_unread == 0) return;
    final live = context.read<RealtimeNotificationService>();
    setState(() {
      for (final n in _notifications) {
        n.status = 'Read';
      }
    });
    live.markAllReadLocally();
    try {
      await _service.markAllNotificationsRead();
      live.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, isError: true);
      _load();
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
      if (!mounted) return;
      await withLoader(context, () => _service.deleteTask(t.taskId));
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

  Future<void> _openSend() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SendNotificationScreen()));
    if (mounted) _load();
  }

  Widget _tabLabel(String text, int count, {bool alert = true}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          constraints: const BoxConstraints(minWidth: 18),
          decoration: BoxDecoration(
            color: alert ? AppColors.danger : AppColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<Session>().isAdmin;
    final onNotifTab = _tabController.index == 0;
    Widget? fab;
    if (!onNotifTab) {
      fab = FloatingActionButton(
        tooltip: 'Add task',
        onPressed: _openCreateTask,
        child: const Icon(Icons.add),
      );
    } else if (isAdmin) {
      fab = FloatingActionButton.extended(
        onPressed: _openSend,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text(
          'Send',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (onNotifTab && _unread > 0)
            IconButton(
              tooltip: 'Mark all read',
              icon: const Icon(Icons.done_all_rounded),
              onPressed: _markAllRead,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(child: _tabLabel('Notifications', _unread)),
            Tab(child: _tabLabel('Tasks', _pending, alert: false)),
          ],
        ),
      ),
      floatingActionButton: fab,
      body: _loading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : TabBarView(
              controller: _tabController,
              children: [_buildNotificationsTab(isAdmin), _buildTasksTab()],
            ),
    );
  }

  Widget _buildNotificationsTab(bool isAdmin) {
    if (_notifications.isEmpty) {
      return EmptyState(
        message: isAdmin
            ? 'No notifications yet.\nTap Send to message everyone.'
            : 'No notifications yet.',
        icon: Icons.notifications_none,
      );
    }
    final unread = _unread;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _notifications.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    unread > 0 ? '$unread unread' : 'All caught up',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: unread > 0
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (unread > 0)
                  TextButton.icon(
                    onPressed: _markAllRead,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            );
          }
          final n = _notifications[i - 1];
          final look = notificationLook(n.type);
          final isNew = n.isUnread;
          return Material(
            color: isNew ? const Color(0xFFE3EBFF) : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(
                color: isNew
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.borderNeutral,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                _markRead(n);
                // "your entry was deleted / edited": open the log that shows which entry, who did it and when
                if (n.type == 'TeacherAttendance')
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyAttendanceLogScreen(),
                    ),
                  );
              },
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      color: isNew ? AppColors.primary : Colors.transparent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 2, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isNew ? Colors.white : look.soft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                look.icon,
                                color: look.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isNew
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: isNew
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      if (isNew)
                                        Container(
                                          width: 9,
                                          height: 9,
                                          margin: const EdgeInsets.only(
                                            left: 6,
                                            right: 4,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    n.message,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: isNew
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat(
                                      'd MMM, h:mm a',
                                    ).format(n.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Remove',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _dismiss(n),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty)
      return const EmptyState(
        message: 'No tasks yet. Tap + to create one.',
        icon: Icons.checklist_outlined,
      );
    // Open tasks first, completed ones below (they stay in the list, just faded).
    final sorted = [
      ..._tasks,
    ]..sort((a, b) => (a.isCompleted ? 1 : 0).compareTo(b.isCompleted ? 1 : 0));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = sorted[i];
          return Opacity(
            opacity: t.isCompleted ? 0.55 : 1,
            child: Card(
              child: ListTile(
                title: Text(
                  t.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: t.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(
                  '${t.studentName != null ? '${t.studentName} • ' : ''}Due ${DateFormat.yMMMd().format(t.dueDate)}',
                ),
                leading: StatusBadge(status: t.status),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!t.isCompleted)
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.success,
                        ),
                        onPressed: () => _completeTask(t),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.danger,
                      ),
                      onPressed: () => _deleteTask(t),
                    ),
                  ],
                ),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showSnack(context, 'Title is required.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createTask(
        title: _title.text.trim(),
        description: _description.text.trim(),
        dueDate: _dueDate,
      );
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
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: sheetBottomInset(context) + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New Task',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              alignLabelWithHint: true,
            ),
          ),
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
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create Task'),
          ),
        ],
      ),
    );
  }
}
