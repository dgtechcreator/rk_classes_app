import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../models/task_notification.dart';
import '../services/task_service.dart';
import 'api_client.dart';

/// Live push for staff notifications over SignalR (SchoolMS.Web/Hubs/NotificationHub.cs). Falls back
/// gracefully to whatever was last fetched via the REST endpoint (TaskService.getNotifications) if the
/// socket can't connect — nothing here is load-bearing for correctness, only for immediacy.
class RealtimeNotificationService extends ChangeNotifier {
  HubConnection? _connection;
  Timer? _poll;   // safety net when the live connection is down: the count is asked again every 30 s
  /// Notifications not read yet - the number on the bell / the Notifications tab.
  int unreadCount = 0;
  /// Open tasks - shown on the Tasks sub-tab only.
  int pendingTasks = 0;
  final List<AppNotification> notifications = [];

  /// Called for each notification that arrives live, in addition to the state update — screens use
  /// this to show a SnackBar/toast without needing to diff the list themselves.
  void Function(AppNotification)? onNotification;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> connect(String token) async {
    await refresh();
    _poll ??= Timer.periodic(const Duration(seconds: 30), (_) => refresh());

    if (_connection != null) return;
    final url = '${ApiConfig.baseUrl}/hubs/notifications';
    final connection = HubConnectionBuilder()
        .withUrl(url, options: HttpConnectionOptions(accessTokenFactory: () async => token))
        .withAutomaticReconnect()
        .build();
    connection.on('notification', _handleIncoming);
    _connection = connection;
    try {
      await connection.start();
    } catch (_) {
      // Best-effort — the badge/list already reflect the last REST fetch; a poll-to-refresh on the
      // Notifications screen still works even with no live connection.
    }
  }

  /// Re-reads the list + unread count from the server (also used after the Tasks tab marked everything read).
  Future<void> refresh() async {
    try {
      final data = await TaskService().getNotifications();
      notifications
        ..clear()
        ..addAll(data.notifications);
      unreadCount = data.unreadNotifications;
      pendingTasks = data.pendingTasks;
      notifyListeners();
    } catch (_) {
      // Leave whatever state we had — a transient failure here shouldn't block connect().
    }
  }

  void _handleIncoming(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty || arguments[0] is! Map) return;
    final raw = Map<String, dynamic>.from(arguments[0] as Map);
    final n = AppNotification.fromJson(raw);
    notifications.insert(0, n);
    unreadCount++;
    notifyListeners();
    onNotification?.call(n);
  }

  /// The numbers the server just returned (called by the Notifications screen after it loaded).
  void setCounts({required int unread, required int tasks}) {
    if (unread == unreadCount && tasks == pendingTasks) return;
    unreadCount = unread < 0 ? 0 : unread;
    pendingTasks = tasks < 0 ? 0 : tasks;
    notifyListeners();
  }

  /// One notification was read: the badge goes down at once.
  void markReadLocally(int notificationId) {
    final i = notifications.indexWhere((n) => n.notificationId == notificationId);
    if (i >= 0) {
      if (!notifications[i].isUnread) return;
      notifications[i].status = 'Read';
    }
    if (unreadCount > 0) unreadCount--;
    notifyListeners();
  }

  /// Everything was marked read: clear the badge at once.
  void markAllReadLocally() {
    for (final n in notifications) { n.status = 'Read'; }
    unreadCount = 0;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _poll?.cancel();
    _poll = null;
    await _connection?.stop();
    _connection = null;
    notifications.clear();
    unreadCount = 0;
    pendingTasks = 0;
    notifyListeners();
  }
}
