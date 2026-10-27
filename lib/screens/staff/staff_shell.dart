import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/realtime_notification_service.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_nav_bar.dart';
import '../auth/login_screen.dart';
import 'cr_home_screen.dart';
import 'staff_home_screen.dart';
import 'staff_modules_screen.dart';
import 'staff_profile_screen.dart';
import 'tasks_notifications_screen.dart';

/// Staff shell with a real bottom-tab structure: Home (dashboard + quick actions), Modules (the full
/// permission-filtered directory), Tasks (notifications, badge-counted), Profile (account + logout).
/// A Class Representative (CR / Monitor) gets a reduced shell: his class home + profile only.
/// Rights are re-read from the server whenever the app comes back to the foreground, so a right the
/// admin changed (or an account that was switched off) takes effect without logging in again.
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<Session>().refreshFromServer();
    }
  }

  void _goToTasks() => setState(() => _index = 2);
  void _goToModules() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    // Account switched off / deleted on the server -> back to the login screen.
    if (session.status == AuthStatus.signedOut && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      });
    }

    if (session.isClassRep) return _crShell();

    final unread = context.watch<RealtimeNotificationService>().unreadCount;
    final screens = [
      StaffHomeScreen(onOpenTasks: _goToTasks, onOpenModules: _goToModules),
      const StaffModulesScreen(),
      TasksNotificationsScreen(active: _index == 2),
      const StaffProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: PremiumBottomNav(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          if (i == 3) context.read<Session>().refreshFromServer();   // latest photo / rights when Profile opens
        },
        items: [
          const PremiumNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
          const PremiumNavItem(icon: Icons.apps_outlined, selectedIcon: Icons.apps_rounded, label: 'Modules'),
          PremiumNavItem(icon: Icons.checklist_outlined, selectedIcon: Icons.checklist_rounded, label: 'Tasks', badge: unread),
          const PremiumNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }

  Widget _crShell() {
    final i = _index > 1 ? 0 : _index;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: i, children: const [CrHomeScreen(), StaffProfileScreen()]),
      bottomNavigationBar: PremiumBottomNav(
        currentIndex: i,
        onTap: (v) {
          setState(() => _index = v);
          if (v == 1) context.read<Session>().refreshFromServer();
        },
        items: const [
          PremiumNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
          PremiumNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}
