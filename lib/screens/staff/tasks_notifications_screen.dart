import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/realtime_notification_service.dart';
import '../../models/task_notification.dart';
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class TasksNotificationsScreen extends StatefulWidget {
  const TasksNotificationsScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getNotifications();
      setState(() { _notifications = data.notifications; _tasks = data.tasks; _loading = false; });
      if (mounted) context.read<RealtimeNotificationService>().markAllReadLocally();
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
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
        bottom: TabBar(controller: _tabController, labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSecondary, tabs: const [
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
          return Card(
            color: n.isUnread ? AppColors.primarySoft : AppColors.surface,
            child: ListTile(
              title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${n.message}\n${DateFormat.yMMMd().add_jm().format(n.createdAt)}'),
              isThreeLine: true,
              onTap: () => _markRead(n),
              trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _dismiss(n)),
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
