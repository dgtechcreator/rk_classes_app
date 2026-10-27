import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/parent_service.dart';

/// The parent's unread badge. There is no push service behind the app, so this asks the server for the count when the
/// shell opens, whenever the app comes back to the foreground, and once a minute while it is open.
class ParentNotificationController extends ChangeNotifier {
  final _service = ParentService();
  Timer? _timer;
  int unread = 0;

  void start() {
    refresh();
    _timer ??= Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final n = await _service.getUnreadCount();
      if (n != unread) {
        unread = n;
        notifyListeners();
      }
    } catch (_) {
      // keep the last number - a failed poll must never show an error on the home screen
    }
  }

  /// Opening the list clears the badge (the server remembers "seen up to now" per parent account).
  void markAllSeen() {
    if (unread == 0) return;
    unread = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
