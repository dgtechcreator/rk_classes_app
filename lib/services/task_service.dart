import '../core/api_client.dart';
import '../models/task_notification.dart';

class TaskAndNotifications {
  TaskAndNotifications({required this.notifications, required this.tasks, required this.unreadCount, required this.unreadNotifications, required this.pendingTasks});
  final List<AppNotification> notifications;
  final List<TaskItem> tasks;
  /// Old meaning: unread notifications + pending tasks.
  final int unreadCount;
  /// Notifications not read yet (what the bell / tab badge shows).
  final int unreadNotifications;
  final int pendingTasks;
}

class TaskService {
  final _client = ApiClient.instance;

  Future<List<TaskItem>> getTasks() async {
    final res = await _client.get('/api/tasks');
    return (res.data as List).map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TaskAndNotifications> getNotifications() async {
    final res = await _client.get('/api/tasks/notifications');
    final data = res.data as Map<String, dynamic>;
    final notes = (data['notifications'] as List? ?? []).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    return TaskAndNotifications(
      notifications: notes,
      tasks: (data['tasks'] as List? ?? []).map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList(),
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      // an older server has no split: count the unread ones from the list itself
      unreadNotifications: (data['unreadNotifications'] as num?)?.toInt() ?? notes.where((n) => n.isUnread).length,
      pendingTasks: (data['pendingTasks'] as num?)?.toInt() ?? ((data['tasks'] as List?)?.length ?? 0),
    );
  }

  Future<void> createTask({required String title, String? description, int? studentId, required DateTime dueDate, int? assignToUserId}) async {
    final dueDateStr = '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    await _client.post('/api/tasks/create', data: {
      'title': title,
      'description': description ?? '',
      'studentId': studentId,
      'dueDate': dueDateStr,
      'assignToUserId': assignToUserId,
    });
  }

  Future<void> completeTask(int taskId) async => _client.post('/api/tasks/$taskId/complete');
  Future<void> deleteTask(int taskId) async => _client.post('/api/tasks/$taskId/delete');
  Future<void> markAllNotificationsRead() async => _client.post('/api/tasks/notifications/read-all');
  Future<void> markNotificationRead(int notificationId) async => _client.post('/api/tasks/notifications/$notificationId/read');
  Future<void> dismissNotification(int notificationId) async => _client.post('/api/tasks/notifications/$notificationId/dismiss');
}
