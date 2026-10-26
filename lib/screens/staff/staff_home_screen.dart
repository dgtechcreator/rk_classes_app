import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/realtime_notification_service.dart';
import '../../core/session.dart';
import '../../models/dashboard.dart';
import '../../services/lookup_service.dart';
import '../../services/staff_dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_home_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/contact_actions.dart';
import '../fees/fees_this_month_screen.dart';
import '../finance/finance_dashboard_screen.dart';
import '../students/student_list_screen.dart';
import '../users/user_list_screen.dart';
import 'coming_soon_screen.dart';
import 'staff_modules_screen.dart';

/// Home tab — a quick "what matters right now" surface (admin KPIs + charts, then a handful of
/// one-tap shortcuts). The full permission-filtered module directory lives in the Modules tab so
/// this screen never has to cram every module into a wall of icons.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key, this.onOpenTasks, this.onOpenModules});
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenModules;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final _service = StaffDashboardService();
  bool _loading = false;
  String? _error;
  StaffDashboardData? _data;
  String? _yearLabel;

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    if (session.isAdmin) {
      _load();
      _loadYear();
    }
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

  /// The year every number on this screen belongs to = the one marked Current in Masters.
  Future<void> _loadYear() async {
    try {
      final years = await LookupService().getYears();
      if (!mounted || years.isEmpty) return;
      final cur = years.firstWhere((y) => y.isCurrent, orElse: () => years.first);
      setState(() => _yearLabel = shortYearLabel(cur.name));
    } on ApiException {
      // the pill just stays hidden
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final unreadCount = context.watch<RealtimeNotificationService>().unreadCount;
    final quickActions = allModules.where((m) => m.isVisibleTo(session)).take(6).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        edgeOffset: MediaQuery.of(context).padding.top + 60,
        onRefresh: session.isAdmin ? () async { await _load(); await _loadYear(); } : () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: AdminHomeHeader(
                name: session.displayName.isEmpty ? session.fullName : session.displayName,
                roleLabel: session.roleName,
                isAdmin: session.isAdmin,
                photoPath: session.profilePicPath,
                unread: unreadCount,
                onBell: widget.onOpenTasks,
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (session.isAdmin) ..._buildAdminDashboard(),
                        if (quickActions.isNotEmpty) ..._buildQuickActions(quickActions),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _quickPalette = [AppColors.info, AppColors.success, AppColors.violet, AppColors.amber, AppColors.danger, AppColors.teal];

  List<Widget> _buildQuickActions(List<ModuleDef> items) {
    return [
      AdminSectionTitle(
        'Quick Actions',
        trailing: widget.onOpenModules == null
            ? null
            : Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: widget.onOpenModules,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Manage', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.primary),
                    ]),
                  ),
                ),
              ),
      ),
      AdminQuickGrid(
        children: [
          for (var i = 0; i < items.length; i++)
            AdminQuickTile(
              icon: items[i].icon,
              label: items[i].label,
              color: _quickPalette[i % _quickPalette.length],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: items[i].screenBuilder ?? (_) => ComingSoonScreen(title: items[i].label, icon: items[i].icon),
              )),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildAdminDashboard() {
    final title = AdminSectionTitle(
      'Overview',
      trailing: _yearLabel == null ? null : Align(alignment: Alignment.centerRight, child: AdminYearPill(label: 'Academic Year $_yearLabel')),
    );
    if (_loading && _data == null) return [title, const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingView())];
    if (_error != null && _data == null) return [title, ErrorView(message: _error!, onRetry: _load)];
    if (_data == null) return const [];
    final s = _data!.stats;
    final money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return [
      title,
      AdminStatGrid(
        children: [
          AdminStatCard(label: 'Total Students', value: '${s.totalStudents}', color: AppColors.info, icon: Icons.groups_rounded, onTap: _openStudents),
          AdminStatCard(label: 'Present Today', value: '${s.presentToday}', color: AppColors.success, icon: Icons.check_circle_outline_rounded, onTap: _openPresentSheet),
          AdminStatCard(label: 'Absent Today', value: '${s.absentToday}', color: AppColors.danger, icon: Icons.cancel_outlined, onTap: _openAbsentSheet),
          AdminStatCard(label: 'Total Staff', value: '${s.totalStaff}', color: AppColors.violet, icon: Icons.groups_2_rounded, onTap: () => _push(const UserListScreen())),
          AdminStatCard(label: 'Fees This Month', value: money.format(s.feesThisMonth), color: AppColors.success, icon: Icons.bar_chart_rounded, onTap: () => _push(const FeesThisMonthScreen())),
          AdminStatCard(label: 'Balance Overall', value: money.format(s.balanceOverall), color: s.balanceOverall > 0 ? AppColors.warning : AppColors.success, icon: Icons.account_balance_wallet_outlined, onTap: () => _push(const FinanceDashboardScreen())),
        ],
      ),
      const SizedBox(height: 16),
      if (s.totalFeesOverall > 0) ...[
        AdminFeeCard(stats: s, onTap: () => _push(const FinanceDashboardScreen())),
        const SizedBox(height: 16),
      ],
      if (s.classStrengths.isNotEmpty) AdminClassCard(stats: s, onTotalTap: _openStudents),
    ];
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _openStudents() => _push(const StudentListScreen());

  Future<void> _openAbsentSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TodayStudentsSheet(title: 'Absent Today', emptyMessage: 'No absent students today.', loader: _service.getAbsentToday, showActions: true),
    );
  }

  Future<void> _openPresentSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TodayStudentsSheet(title: 'Present Today', emptyMessage: 'No attendance marked as present yet today.', loader: _service.getPresentToday, showActions: false),
    );
  }
}

/// Bottom sheet listing today's absent / present students. Call + WhatsApp actions are only offered
/// for the absent list (that's where a parent needs to be contacted).
class _TodayStudentsSheet extends StatefulWidget {
  const _TodayStudentsSheet({required this.title, required this.emptyMessage, required this.loader, required this.showActions});
  final String title;
  final String emptyMessage;
  final Future<List<AbsentStudent>> Function() loader;
  final bool showActions;

  @override
  State<_TodayStudentsSheet> createState() => _TodayStudentsSheetState();
}

class _TodayStudentsSheetState extends State<_TodayStudentsSheet> {
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
      final students = await widget.loader();
      if (mounted) setState(() { _students = students; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _call(AbsentStudent a) =>
      ContactActions.call(context, name: a.fullName, contacts: a.contacts);

  Future<void> _whatsapp(AbsentStudent a) => ContactActions.whatsapp(
        context,
        name: a.fullName,
        contacts: a.contacts,
        category: 'Absent',
        vars: ContactActions.baseVars(student: a.fullName, className: a.className, medium: a.sectionName),
      );

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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_loading || _error != null ? widget.title : '${widget.title} (${_students.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Expanded(
                child: _loading
                    ? const LoadingView()
                    : _error != null
                        ? ErrorView(message: _error!, onRetry: _load)
                        : _students.isEmpty
                            ? EmptyState(message: widget.emptyMessage, icon: Icons.check_circle_outline)
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _students.length,
                                itemBuilder: (_, i) {
                                  final a = _students[i];
                                  final hasPhone = a.contacts.isNotEmpty;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.only(left: 16, right: 2),
                                    horizontalTitleGap: 12,
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primarySoft,
                                      child: Text(a.fullName.isNotEmpty ? a.fullName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(a.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: Text('${a.admissionNo} • ${a.className.trim()} ${a.sectionName}'),
                                    trailing: !widget.showActions ? null : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: hasPhone ? 'Call' : 'No phone number',
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.call_rounded),
                                          color: AppColors.info,
                                          onPressed: hasPhone ? () => _call(a) : null,
                                        ),
                                        IconButton(
                                          tooltip: hasPhone ? 'WhatsApp' : 'No phone number',
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.chat_rounded),
                                          color: whatsappGreen,
                                          onPressed: hasPhone ? () => _whatsapp(a) : null,
                                        ),
                                      ],
                                    ),
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
