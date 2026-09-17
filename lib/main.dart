import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/realtime_notification_service.dart';
import 'core/session.dart';
import 'models/task_notification.dart';
import 'screens/auth/login_screen.dart';
import 'screens/parent/parent_shell.dart';
import 'screens/staff/staff_shell.dart';
import 'theme/app_theme.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shared by the splash-gate restore path and a fresh login — shows a live notification as a toast
/// regardless of which screen is currently on top.
void showLiveNotificationSnack(AppNotification notif) {
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text('${notif.title}: ${notif.message}'),
      backgroundColor: AppColors.primaryDark,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}

void main() {
  runApp(const RkClassesApp());
}

class RkClassesApp extends StatelessWidget {
  const RkClassesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Session()),
        ChangeNotifierProvider(create: (_) => RealtimeNotificationService()),
      ],
      child: MaterialApp(
        title: 'RK Classes',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.light(),
        home: const _SplashGate(),
      ),
    );
  }
}

/// Restores a persisted token/session (if any) before deciding whether to land on Login or the
/// appropriate shell (Staff vs Parent) — mirrors the web app's own session-cookie persistence, just
/// token-based.
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final session = context.read<Session>();
    await session.restore();
    if (!mounted) return;

    if (session.status == AuthStatus.signedIn) {
      if (session.userType == UserType.staff) {
        final realtime = context.read<RealtimeNotificationService>();
        realtime.onNotification = showLiveNotificationSnack;
        unawaited(realtime.connect(ApiClient.instance.token!));
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => session.userType == UserType.parent ? const ParentShell() : const StaffShell()),
      );
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryDark])),
      child: const Center(
        child: Image(image: AssetImage('assets/images/rk_logo_icon.png'), width: 96, height: 96),
      ),
    );
  }
}
