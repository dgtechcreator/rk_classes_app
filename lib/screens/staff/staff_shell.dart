import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/realtime_notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_nav_bar.dart';
import 'staff_home_screen.dart';
import 'staff_modules_screen.dart';
import 'staff_profile_screen.dart';
import 'tasks_notifications_screen.dart';

/// Staff shell with a real bottom-tab structure: Home (dashboard + quick actions), Modules (the full
/// permission-filtered directory), Tasks (notifications, badge-counted), Profile (account + logout).
/// Previously this was just a typedef straight to StaffHomeScreen with no navigation shell at all.
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _index = 0;

  void _goToTasks() => setState(() => _index = 2);

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<RealtimeNotificationService>().unreadCount;
    final screens = [
      StaffHomeScreen(onOpenTasks: _goToTasks),
      const StaffModulesScreen(),
      const TasksNotificationsScreen(),
      const StaffProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: PremiumBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          const PremiumNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
          const PremiumNavItem(icon: Icons.apps_outlined, selectedIcon: Icons.apps_rounded, label: 'Modules'),
          PremiumNavItem(icon: Icons.checklist_outlined, selectedIcon: Icons.checklist_rounded, label: 'Tasks', badge: unread),
          const PremiumNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}
