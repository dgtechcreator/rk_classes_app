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
  const StaffHomeScreen({super.key, this.onOpenTasks});
  final VoidCallback? onOpenTasks;

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

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final unreadCount = context.watch<RealtimeNotificationService>().unreadCount;
    final quickActions = allModules.where((m) => m.isVisibleTo(session)).take(6).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: session.isAdmin ? _load : () async {},
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: GreetingHeader(
                  greeting: 'Welcome back,',
                  //name: session.fullName.split(' ').first,
                  name: session.fullName,
                  subtitle: session.roleName,
                  leadingIcon: Icons.badge_outlined,
                  actions: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                          tooltip: 'Notifications',
                          onPressed: widget.onOpenTasks,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 6, right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: Text('$unreadCount', style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (session.isAdmin) ..._buildAdminDashboard(),
                    if (quickActions.isNotEmpty) ..._buildQuickActions(quickActions),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuickActions(List<ModuleDef> items) {
    return [
      const SectionHeader(title: 'Quick Actions'),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 80),
        itemBuilder: (_, i) {
          final m = items[i];
          return QuickActionTile(
            icon: m.icon,
            label: m.label,
            color: groupColor(m.group),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: m.screenBuilder ?? (_) => ComingSoonScreen(title: m.label, icon: m.icon),
            )),
          );
        },
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
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 56),
        children: [
          SlimStatCard(label: 'Total Students', value: '${s.totalStudents}', color: AppColors.info, icon: Icons.groups,
              onTap: _openStudents),
          SlimStatCard(label: 'Present Today', value: '${s.presentToday}', color: AppColors.success, icon: Icons.check_circle_outline,
              onTap: s.presentToday > 0 ? _openPresentSheet : null),
          SlimStatCard(label: 'Absent Today', value: '${s.absentToday}', color: AppColors.danger, icon: Icons.cancel_outlined,
              onTap: s.absentToday > 0 ? _openAbsentSheet : null),
          SlimStatCard(label: 'Total Staff', value: '${s.totalStaff}', color: AppColors.info, icon: Icons.badge,
              onTap: () => _push(const UserListScreen())),
          SlimStatCard(label: 'Fees This Month', value: NumberFormat.currency(symbol: '₹').format(s.feesThisMonth), color: AppColors.success, icon: Icons.trending_up,
              onTap: () => _push(const FeesThisMonthScreen())),
          SlimStatCard(label: 'Balance Overall', value: NumberFormat.currency(symbol: '₹').format(s.balanceOverall), color: s.balanceOverall > 0 ? AppColors.warning : AppColors.success, icon: Icons.account_balance_wallet_outlined,
              onTap: () => _push(const FinanceDashboardScreen())),
        ],
      ),
      const SizedBox(height: 14),
      if (s.classStrengths.isNotEmpty) ...[_buildClassChart(s), const SizedBox(height: 14)],
      if (s.totalFeesOverall > 0) ...[_buildFeeCollectionCard(s), const SizedBox(height: 14)],
    ];
  }

  /// "Students by Class" — one row per class with its medium split as small pills
  /// ("English 77" "Hindi 37") and the class total on the right. No bars, so 8 classes
  /// stay in roughly one screen of space.
  Widget _buildClassChart(DashboardStats s) {
    final total = s.classStrengths.fold<int>(0, (a, b) => a + b.studentCount);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Students by Class', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text('Total $total', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.info)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < s.classStrengths.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 0.6, color: AppColors.borderNeutral),
            _classRow(s.classStrengths[i]),
          ],
        ],
      ),
    );
  }

  Widget _classRow(ClassStrength c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(c.className.trim(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.5)),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 5,
              children: c.sections.isEmpty
                  ? [_mediumPill('Students', c.studentCount, AppColors.textSecondary, AppColors.background)]
                  : [
                      for (final sec in c.sections)
                        _mediumPill(_mediumLabel(sec.sectionName), sec.studentCount, _mediumColor(sec.sectionName), _mediumColor(sec.sectionName).withValues(alpha: 0.11)),
                    ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${c.studentCount}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _mediumPill(String label, int count, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label  ', style: TextStyle(fontSize: 11.5, color: fg, fontWeight: FontWeight.w500)),
          TextSpan(text: '$count', style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Color _mediumColor(String section) {
    final l = section.toLowerCase();
    if (l.contains('semi')) return AppColors.teal;
    if (l.contains('english')) return AppColors.info;
    if (l.contains('hindi')) return AppColors.warning;
    return AppColors.violet; // streams: Commerce / Science / …
  }

  Widget _buildFeeCollectionCard(DashboardStats s) {
    final pct = s.totalFeesOverall == 0 ? 0.0 : (s.totalCollectedOverall / s.totalFeesOverall).clamp(0.0, 1.0);
    final fmt = NumberFormat.currency(symbol: '₹');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fee Collection (Overall)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          const SizedBox(height: 10),
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

  /// Sections double as Medium (English / Hindi / Semi-English) and, for 11th-12th, as streams
  /// (Commerce / Science) — shown as stored, just with stray spaces around hyphens tidied.
  String _mediumLabel(String section) {
    final name = section.trim().replaceAll(RegExp(r'\s*-\s*'), '-');
    return name.isEmpty ? 'Other' : name;
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
