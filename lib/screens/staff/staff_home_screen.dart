import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/realtime_notification_service.dart';
import '../../core/session.dart';
import '../../models/dashboard.dart';
import '../../services/staff_dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../attendance/attendance_mark_screen.dart';
import '../auth/login_screen.dart';
import '../deleted/deleted_records_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../faculty/faculty_list_screen.dart';
import '../fee_structure/fee_structure_list_screen.dart';
import '../fees/fee_collect_search_screen.dart';
import '../finance/finance_dashboard_screen.dart';
import '../marks/marks_entry_screen.dart';
import '../masters/masters_screen.dart';
import '../students/student_list_screen.dart';
import '../teacher_attendance/teacher_attendance_mark_screen.dart';
import '../teacher_payment/teacher_payment_list_screen.dart';
import '../users/user_list_screen.dart';
import 'coming_soon_screen.dart';
import 'tasks_notifications_screen.dart';

class _ModuleDef {
  const _ModuleDef(this.label, this.icon, this.permKey, this.group, {this.screenBuilder});
  final String label;
  final IconData icon;
  final String? permKey; // null = always visible to any staff login
  final String group;
  final WidgetBuilder? screenBuilder; // null = "coming soon" placeholder
}

Color _groupColor(String group) {
  switch (group) {
    case 'Academics': return AppColors.info;
    case 'Finance': return AppColors.success;
    case 'Staff': return AppColors.warning;
    case 'Admin': return AppColors.primary;
    default: return AppColors.primary;
  }
}

final _modules = [
  _ModuleDef('Students', Icons.groups_outlined, 'student_view', 'Academics', screenBuilder: (_) => const StudentListScreen()),
  _ModuleDef('Attendance', Icons.event_available_outlined, 'attendance_entry', 'Academics', screenBuilder: (_) => const AttendanceMarkScreen()),
  _ModuleDef('Marks', Icons.grade_outlined, 'marks_entry', 'Academics', screenBuilder: (_) => const MarksEntryScreen()),
  _ModuleDef('Fees', Icons.payments_outlined, 'fee_collection', 'Finance', screenBuilder: (_) => const FeeCollectSearchScreen()),
  _ModuleDef('Fee Structure', Icons.receipt_long_outlined, 'fee_structure', 'Finance', screenBuilder: (_) => const FeeStructureListScreen()),
  _ModuleDef('Expenses', Icons.request_quote_outlined, 'expenses_view', 'Finance', screenBuilder: (_) => const ExpenseListScreen()),
  _ModuleDef('Finance', Icons.pie_chart_outline, 'finance_view', 'Finance', screenBuilder: (_) => const FinanceDashboardScreen()),
  _ModuleDef('Faculty', Icons.school_outlined, 'faculty_view', 'Staff', screenBuilder: (_) => const FacultyListScreen()),
  _ModuleDef('Teacher Attendance', Icons.badge_outlined, 'teacher_attendance', 'Staff', screenBuilder: (_) => const TeacherAttendanceMarkScreen()),
  _ModuleDef('Teacher Payment', Icons.currency_rupee, 'teacher_payment', 'Staff', screenBuilder: (_) => const TeacherPaymentListScreen()),
  _ModuleDef('Masters', Icons.settings_outlined, 'masters_view', 'Admin', screenBuilder: (_) => const MastersScreen()),
  _ModuleDef('Users', Icons.admin_panel_settings_outlined, 'users_view', 'Admin', screenBuilder: (_) => const UserListScreen()),
  _ModuleDef('Deleted Records', Icons.restore_from_trash_outlined, 'deleted_records', 'Admin', screenBuilder: (_) => const DeletedRecordsScreen()),
  _ModuleDef('Tasks', Icons.checklist_outlined, null, 'Admin', screenBuilder: (_) => const TasksNotificationsScreen()),
];

const _groupOrder = ['Academics', 'Finance', 'Staff', 'Admin'];

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final _service = StaffDashboardService();
  bool _loading = false;
  String? _error;
  StaffDashboardData? _data;

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    if (session.isAdmin) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getDashboard();
      setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<RealtimeNotificationService>().disconnect();
    if (!context.mounted) return;
    await context.read<Session>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final unreadCount = context.watch<RealtimeNotificationService>().unreadCount;
    final visibleModules = _modules.where((m) => m.permKey == null || session.hasPerm(m.permKey!)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${session.fullName.split(' ').first}'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasksNotificationsScreen())),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                    child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: () => _confirmLogout(context)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: session.isAdmin ? _load : () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (session.isAdmin) ..._buildAdminDashboard(),
            for (final group in _groupOrder) ..._buildModuleGroup(group, visibleModules),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModuleGroup(String group, List<_ModuleDef> visibleModules) {
    final items = visibleModules.where((m) => m.group == group).toList();
    if (items.isEmpty) return const [];
    return [
      SectionHeader(title: group),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.9),
        itemBuilder: (_, i) => _ModuleTile(module: items[i]),
      ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _buildAdminDashboard() {
    if (_loading) return const [LoadingView()];
    if (_error != null) return [ErrorView(message: _error!, onRetry: _load)];
    if (_data == null) return const [];
    final s = _data!.stats;
    return [
      const SectionHeader(title: 'Overview'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.7,
        children: [
          StatCard(label: 'Total Students', value: '${s.totalStudents}', color: AppColors.info, icon: Icons.groups),
          StatCard(label: 'Present Today', value: '${s.presentToday}', color: AppColors.success, icon: Icons.check_circle_outline),
          StatCard(label: 'Absent Today', value: '${s.absentToday}', color: AppColors.danger, icon: Icons.cancel_outlined,
              onTap: s.absentToday > 0 ? _openAbsentSheet : null),
          StatCard(label: 'Total Staff', value: '${s.totalStaff}', color: AppColors.info, icon: Icons.badge),
          StatCard(label: 'Fees This Month', value: NumberFormat.compactCurrency(symbol: '₹').format(s.feesThisMonth), color: AppColors.success, icon: Icons.trending_up),
          StatCard(label: 'Balance Overall', value: NumberFormat.compactCurrency(symbol: '₹').format(s.balanceOverall), color: s.balanceOverall > 0 ? AppColors.warning : AppColors.success, icon: Icons.account_balance_wallet_outlined),
        ],
      ),
      const SizedBox(height: 20),
      if (s.classStrengths.isNotEmpty) ...[_buildClassChart(s), const SizedBox(height: 20)],
      if (s.totalFeesOverall > 0) ...[_buildFeeCollectionCard(s), const SizedBox(height: 20)],
    ];
  }

  Widget _buildClassChart(DashboardStats s) {
    final total = s.classStrengths.fold<int>(0, (a, b) => a + b.studentCount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Students by Class', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 140,
                width: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 38,
                    sections: s.classStrengths.map((c) {
                      final pct = total == 0 ? 0.0 : c.studentCount / total * 100;
                      return PieChartSectionData(
                        value: c.studentCount.toDouble(),
                        color: _hexToColor(c.color),
                        radius: 32,
                        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: s.classStrengths.map((c) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: _hexToColor(c.color), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('${c.className.trim()} (${c.studentCount})', style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeeCollectionCard(DashboardStats s) {
    final pct = s.totalFeesOverall == 0 ? 0.0 : (s.totalCollectedOverall / s.totalFeesOverall).clamp(0.0, 1.0);
    final fmt = NumberFormat.compactCurrency(symbol: '₹');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fee Collection (Overall)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct, minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _legendDot(AppColors.success, 'Collected ${fmt.format(s.totalCollectedOverall)}'),
              const SizedBox(width: 16),
              _legendDot(AppColors.warning, 'Balance ${fmt.format(s.balanceOverall)}'),
            ],
          ),
          if (s.totalDiscountOverall > 0) ...[
            const SizedBox(height: 8),
            _legendDot(AppColors.info, 'Discount ${fmt.format(s.totalDiscountOverall)}'),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Color _hexToColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF6D28D9);
  }

  Future<void> _openAbsentSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AbsentTodaySheet(service: _service),
    );
  }
}

class _AbsentTodaySheet extends StatefulWidget {
  const _AbsentTodaySheet({required this.service});
  final StaffDashboardService service;

  @override
  State<_AbsentTodaySheet> createState() => _AbsentTodaySheetState();
}

class _AbsentTodaySheetState extends State<_AbsentTodaySheet> {
  bool _loading = true;
  String? _error;
  List<AbsentStudent> _students = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final students = await widget.service.getAbsentToday();
      if (mounted) setState(() { _students = students; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Absent Today', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Expanded(
                child: _loading
                    ? const LoadingView()
                    : _error != null
                        ? ErrorView(message: _error!, onRetry: _load)
                        : _students.isEmpty
                            ? const EmptyState(message: 'No absent students today.', icon: Icons.check_circle_outline)
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _students.length,
                                itemBuilder: (_, i) {
                                  final a = _students[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primarySoft,
                                      child: Text(a.fullName.isNotEmpty ? a.fullName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(a.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text('${a.admissionNo} • ${a.className.trim()} ${a.sectionName}'),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});
  final _ModuleDef module;

  @override
  Widget build(BuildContext context) {
    final color = _groupColor(module.group);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: module.screenBuilder ?? (_) => ComingSoonScreen(title: module.label, icon: module.icon),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(module.icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(module.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
