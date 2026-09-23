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
    final quickActions = allModules.where((m) => m.permKey == null || session.hasPerm(m.permKey!)).take(6).toList();

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
                  name: session.fullName.split(' ').first,
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
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
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
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
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
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
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
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
              backgroundColor: AppColors.background,
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
