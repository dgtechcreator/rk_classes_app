import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/parent_data_controller.dart';
import '../../core/parent_notification_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_nav_bar.dart';
import 'parent_attendance_screen.dart';
import 'parent_contact_screen.dart';
import 'parent_fees_screen.dart';
import 'parent_grades_screen.dart';
import 'parent_home_screen.dart';
import 'parent_lectures_screen.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> with WidgetsBindingObserver {
  int _index = 0;
  final _data = ParentDataController();
  final _notifs = ParentNotificationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _data.load();
    _notifs.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _data.dispose();
    _notifs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _notifs.refresh();   // news that arrived while the app was in the background
  }

  static const _screens = [ParentHomeScreen(), ParentAttendanceScreen(), ParentLecturesScreen(), ParentGradesScreen(), ParentFeesScreen(), ParentContactScreen()];

  static const _items = [
    PremiumNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
    PremiumNavItem(icon: Icons.event_available_outlined, selectedIcon: Icons.event_available_rounded, label: 'Attendance'),
    PremiumNavItem(icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book_rounded, label: 'Lectures'),
    PremiumNavItem(icon: Icons.grade_outlined, selectedIcon: Icons.grade_rounded, label: 'Grades'),
    PremiumNavItem(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet_rounded, label: 'Fees'),
    PremiumNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _data),
        ChangeNotifierProvider.value(value: _notifs),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: PremiumBottomNav(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: _items,
        ),
      ),
    );
  }
}
