import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/student.dart';
import '../../services/parent_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> with SingleTickerProviderStateMixin {
  final _service = ParentService();
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  List<Student> _children = [];
  Student? _selected;
  ParentDashboardData? _data;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final children = await _service.getChildren();
      final selected = _selected != null && children.any((c) => c.studentId == _selected!.studentId)
          ? children.firstWhere((c) => c.studentId == _selected!.studentId)
          : (children.isNotEmpty ? children.first : null);
      ParentDashboardData? data;
      if (selected != null) data = await _service.getDashboard(selected.studentId);
      setState(() { _children = children; _selected = selected; _data = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _selectChild(Student s) async {
    if (s.studentId == _selected?.studentId) return;
    setState(() { _selected = s; _loading = true; });
    try {
      final data = await _service.getDashboard(s.studentId);
      setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Children'), bottom: _data == null
          ? null
          : TabBar(controller: _tabController, labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSecondary, tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Attendance'),
              Tab(text: 'Marks'),
            ])),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _children.isEmpty
                  ? const EmptyState(message: 'No children linked to this account yet.', icon: Icons.family_restroom)
                  : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        if (_children.length > 1) _buildChildSelector(),
        Expanded(
          child: _data == null
              ? const EmptyState(message: 'Select a child to view details.')
              : TabBarView(controller: _tabController, children: [
                  _buildOverviewTab(_data!),
                  _buildAttendanceTab(_data!),
                  _buildMarksTab(_data!),
                ]),
        ),
      ],
    );
  }

  Widget _buildChildSelector() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = _children[i];
          final selected = c.studentId == _selected?.studentId;
          return ChoiceChip(
            label: Text(c.fullName),
            selected: selected,
            onSelected: (_) => _selectChild(c),
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(ParentDashboardData d) {
    final att = d.attendance;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(radius: 28, backgroundColor: AppColors.primarySoft, child: Text(d.student.fullName.isNotEmpty ? d.student.fullName[0] : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.student.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(d.student.classLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Text('Admission No: ${d.student.admissionNo}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              StatCard(label: 'Attendance', value: att == null ? '-' : '${att.attendancePct.toStringAsFixed(0)}%', color: AppColors.success, icon: Icons.event_available),
              StatCard(label: 'Present Days', value: att == null ? '-' : '${att.presentDays}/${att.totalDays}', color: AppColors.info, icon: Icons.calendar_month),
              StatCard(label: 'Fees Paid', value: NumberFormat.compactCurrency(symbol: '₹').format(d.totalPaid), color: AppColors.success, icon: Icons.payments_outlined),
              StatCard(label: 'Balance Due', value: NumberFormat.compactCurrency(symbol: '₹').format(d.balance), color: d.balance > 0 ? AppColors.danger : AppColors.success, icon: Icons.account_balance_wallet_outlined),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Recent Fee Payments'),
          if (d.feeHistory.isEmpty)
            const EmptyState(message: 'No payments recorded yet.', icon: Icons.receipt_long)
          else
            ...d.feeHistory.take(5).map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(p.feeTypeName ?? 'Fee Payment'),
                    subtitle: Text('${DateFormat.yMMMd().format(p.paymentDate)} • ${p.paymentMode}'),
                    trailing: Text(NumberFormat.simpleCurrency(name: 'INR').format(p.netAmount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab(ParentDashboardData d) {
    if (d.attendanceDetail.isEmpty) return const EmptyState(message: 'No attendance records yet.', icon: Icons.event_busy);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: d.attendanceDetail.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final a = d.attendanceDetail[i];
          return Card(
            child: ListTile(
              title: Text(DateFormat.yMMMEd().format(a.attendanceDate)),
              subtitle: a.subject != null ? Text('${a.subject}${a.sirName != null ? ' • ${a.sirName}' : ''}') : null,
              trailing: StatusBadge(status: a.status),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarksTab(ParentDashboardData d) {
    if (d.marks.isEmpty) return const EmptyState(message: 'No test marks recorded yet.', icon: Icons.grade_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: d.marks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final m = d.marks[i];
          final pct = m.marksObtained == null ? null : (m.marksObtained! / m.maxMarks * 100);
          return Card(
            child: ListTile(
              title: Text(m.subjectName ?? 'Subject'),
              subtitle: Text(m.examName ?? ''),
              trailing: Text(
                m.marksObtained == null ? 'Absent' : '${m.marksObtained!.toStringAsFixed(0)}/${m.maxMarks} (${pct!.toStringAsFixed(0)}%)',
                style: TextStyle(fontWeight: FontWeight.w700, color: pct == null ? AppColors.danger : (pct >= 35 ? AppColors.success : AppColors.danger)),
              ),
            ),
          );
        },
      ),
    );
  }
}
