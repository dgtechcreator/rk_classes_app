int _asInt(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
int? _asIntN(dynamic v) => v == null ? null : _asInt(v);
String _asString(dynamic v) => v?.toString() ?? '';
String? _asStringN(dynamic v) => v?.toString();
DateTime? _asDateN(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class AppNotification {
  AppNotification({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    required this.status,
    required this.createdAt,
    this.action,
    this.referenceId,
  });

  final int notificationId;
  final String title;
  final String message;
  final String type;
  final String status;
  final DateTime createdAt;
  final String? action;
  final int? referenceId;

  bool get isUnread => status == 'Unread';

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        notificationId: _asInt(j['notificationId']),
        title: _asString(j['title']),
        message: _asString(j['message']),
        type: j['type'] == null ? 'Task' : _asString(j['type']),
        status: j['status'] == null ? 'Unread' : _asString(j['status']),
        createdAt: _asDateN(j['createdAt']) ?? DateTime.now(),
        action: _asStringN(j['action']),
        referenceId: _asIntN(j['referenceId']),
      );
}

class TaskItem {
  TaskItem({
    required this.taskId,
    required this.title,
    this.description,
    this.studentId,
    this.studentName,
    required this.priority,
    required this.category,
    required this.dueDate,
    required this.isCompleted,
    required this.status,
  });

  final int taskId;
  final String title;
  final String? description;
  final int? studentId;
  final String? studentName;
  final String priority;
  final String category;
  final DateTime dueDate;
  final bool isCompleted;
  final String status;

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        taskId: _asInt(j['taskId']),
        title: _asString(j['title']),
        description: _asStringN(j['description']),
        studentId: _asIntN(j['studentId']),
        studentName: _asStringN(j['studentName']),
        priority: j['priority'] == null ? 'Medium' : _asString(j['priority']),
        category: j['category'] == null ? 'General' : _asString(j['category']),
        dueDate: _asDateN(j['dueDate']) ?? DateTime.now(),
        isCompleted: j['isCompleted'] == true,
        status: j['status'] == null ? 'Pending' : _asString(j['status']),
      );
}
