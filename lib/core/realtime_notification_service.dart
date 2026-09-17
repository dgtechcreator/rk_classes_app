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
  int unreadCount = 0;
  final List<AppNotification> notifications = [];

  /// Called for each notification that arrives live, in addition to the state update — screens use
  /// this to show a SnackBar/toast without needing to diff the list themselves.
  void Function(AppNotification)? onNotification;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> connect(String token) async {
    await _refreshInitialState();

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

  Future<void> _refreshInitialState() async {
    try {
      final data = await TaskService().getNotifications();
      notifications
        ..clear()
        ..addAll(data.notifications);
      unreadCount = data.unreadCount;
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

  // Clears the badge immediately for responsiveness; the list itself is refetched from the server
  // (AppNotification.status is immutable here) next time the Notifications screen opens.
  void markAllReadLocally() {
    unreadCount = 0;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _connection?.stop();
    _connection = null;
    notifications.clear();
    unreadCount = 0;
    notifyListeners();
  }
}
