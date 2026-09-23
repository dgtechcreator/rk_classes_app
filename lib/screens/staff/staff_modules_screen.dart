import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
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
import '../attendance/attendance_mark_screen.dart';
import '../users/user_list_screen.dart';
import 'coming_soon_screen.dart';
import 'tasks_notifications_screen.dart';

class ModuleDef {
  const ModuleDef(this.label, this.icon, this.permKey, this.group, {this.screenBuilder});
  final String label;
  final IconData icon;
  final String? permKey; // null = always visible to any staff login
  final String group;
  final WidgetBuilder? screenBuilder; // null = "coming soon" placeholder
}

Color groupColor(String group) {
  switch (group) {
    case 'Academics': return AppColors.info;
    case 'Finance': return AppColors.success;
    case 'Staff': return AppColors.warning;
    case 'Admin': return AppColors.violet;
    default: return AppColors.primary;
  }
}

IconData groupIcon(String group) {
  switch (group) {
    case 'Academics': return Icons.menu_book_rounded;
    case 'Finance': return Icons.account_balance_wallet_rounded;
    case 'Staff': return Icons.badge_rounded;
    case 'Admin': return Icons.shield_rounded;
    default: return Icons.apps_rounded;
  }
}

final allModules = [
  ModuleDef('Students', Icons.groups_outlined, 'student_view', 'Academics', screenBuilder: (_) => const StudentListScreen()),
  ModuleDef('Attendance', Icons.event_available_outlined, 'attendance_entry', 'Academics', screenBuilder: (_) => const AttendanceMarkScreen()),
  ModuleDef('Marks', Icons.grade_outlined, 'marks_entry', 'Academics', screenBuilder: (_) => const MarksEntryScreen()),
  ModuleDef('Fees', Icons.payments_outlined, 'fee_collection', 'Finance', screenBuilder: (_) => const FeeCollectSearchScreen()),
  ModuleDef('Fee Structure', Icons.receipt_long_outlined, 'fee_structure', 'Finance', screenBuilder: (_) => const FeeStructureListScreen()),
  ModuleDef('Expenses', Icons.request_quote_outlined, 'expenses_view', 'Finance', screenBuilder: (_) => const ExpenseListScreen()),
  ModuleDef('Finance', Icons.pie_chart_outline, 'finance_view', 'Finance', screenBuilder: (_) => const FinanceDashboardScreen()),
  ModuleDef('Faculty', Icons.school_outlined, 'faculty_view', 'Staff', screenBuilder: (_) => const FacultyListScreen()),
  ModuleDef('Teacher Attendance', Icons.badge_outlined, 'teacher_attendance', 'Staff', screenBuilder: (_) => const TeacherAttendanceMarkScreen()),
  ModuleDef('Teacher Payment', Icons.currency_rupee, 'teacher_payment', 'Staff', screenBuilder: (_) => const TeacherPaymentListScreen()),
  ModuleDef('Masters', Icons.settings_outlined, 'masters_view', 'Admin', screenBuilder: (_) => const MastersScreen()),
  ModuleDef('Users', Icons.admin_panel_settings_outlined, 'users_view', 'Admin', screenBuilder: (_) => const UserListScreen()),
  ModuleDef('Deleted Records', Icons.restore_from_trash_outlined, 'deleted_records', 'Admin', screenBuilder: (_) => const DeletedRecordsScreen()),
  ModuleDef('Tasks', Icons.checklist_outlined, null, 'Admin', screenBuilder: (_) => const TasksNotificationsScreen()),
];

const groupOrder = ['Academics', 'Finance', 'Staff', 'Admin'];

/// The full, searchable module directory for staff — everything permission-gated that used to live
/// crammed into the Home screen's grid now lives here as its own bottom-nav tab, so Home can stay a
/// quick "what matters right now" surface instead of a 14-icon wall.
class StaffModulesScreen extends StatefulWidget {
  const StaffModulesScreen({super.key});

  @override
  State<StaffModulesScreen> createState() => _StaffModulesScreenState();
}

class _StaffModulesScreenState extends State<StaffModulesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final visible = allModules.where((m) => m.permKey == null || session.hasPerm(m.permKey!)).toList();
    final filtered = _query.isEmpty
        ? visible
        : visible.where((m) => m.label.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Modules', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    const Text('Everything you have access to, in one place.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search modules…',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => setState(() { _searchCtrl.clear(); _query = ''; }),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(message: 'No modules match your search.', icon: Icons.search_off_rounded),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final group in groupOrder) ..._buildGroup(group, filtered),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroup(String group, List<ModuleDef> filtered) {
    final items = filtered.where((m) => m.group == group).toList();
    if (items.isEmpty) return const [];
    final color = groupColor(group);
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(
          children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
              child: Icon(groupIcon(group), size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(group, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.9),
        itemBuilder: (_, i) => _ModuleTile(module: items[i]),
      ),
      const SizedBox(height: 10),
    ];
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});
  final ModuleDef module;

  @override
  Widget build(BuildContext context) {
    return IconTile(
      icon: module.icon,
      label: module.label,
      color: groupColor(module.group),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: module.screenBuilder ?? (_) => ComingSoonScreen(title: module.label, icon: module.icon),
      )),
    );
  }
}
