import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/student.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/person_card.dart';
import '../../widgets/profile_avatar.dart';

/// One student's report: attendance pie (present / absent / late), subject-wise marks and the fee position.
/// The same screen serves a parent (own child) and staff who have the "Student 360 View" right - only [loader] differs.
class StudentReportScreen extends StatefulWidget {
  const StudentReportScreen({super.key, required this.loader, this.title = 'Student Report'});
  final Future<ParentDashboardData> Function() loader;
  final String title;

  @override
  State<StudentReportScreen> createState() => _StudentReportScreenState();
}

class _StudentReportScreenState extends State<StudentReportScreen> {
  bool _loading = true;
  String? _error;
  ParentDashboardData? _d;
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _d == null; _error = null; });
    try {
      final d = await widget.loader();
      if (mounted) setState(() { _d = d; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const LoadingView()
          : _error != null && _d == null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                    children: [
                      _header(_d!),
                      const SizedBox(height: 12),
                      _attendanceCard(_d!),
                      const SizedBox(height: 12),
                      _marksCard(_d!),
                      const SizedBox(height: 12),
                      _feesCard(_d!),
                    ],
                  ),
                ),
    );
  }

  BoxDecoration get _card => BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft);

  Widget _title(String t, IconData icon, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: c),
          ),
          const SizedBox(width: 8),
          Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _header(ParentDashboardData d) {
    final s = d.student;
    String clean(String? v) => (v ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Row(
        children: [
          ProfileAvatar(name: s.displayName, photoPath: s.profilePicPath, size: 54, background: AppColors.primarySoft, foreground: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(s.admissionNo, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (clean(s.className).isNotEmpty) PersonPill(clean(s.className), AppColors.info),
                  if (clean(s.sectionName).isNotEmpty) PersonPill(clean(s.sectionName), AppColors.teal),
                  if (clean(s.batchName).isNotEmpty) PersonPill(clean(s.batchName), AppColors.violet),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── attendance ────────────────────────────────────────────────────────────────────────
  Widget _attendanceCard(ParentDashboardData d) {
    final a = d.attendance;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Attendance', Icons.event_available_rounded, AppColors.success),
          if (a == null || a.totalDays == 0)
            const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: Text('No attendance marked yet.', style: TextStyle(color: AppColors.textSecondary))))
          else
            Row(
              children: [
                SizedBox(
                  width: 150, height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 46,
                        sections: [
                          _slice(a.presentDays.toDouble(), AppColors.success),
                          _slice(a.absentDays.toDouble(), AppColors.danger),
                          _slice(a.lateDays.toDouble(), AppColors.warning),
                        ],
                      )),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${a.attendancePct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const Text('present', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _legend('Present', a.presentDays, AppColors.success),
                      _legend('Absent', a.absentDays, AppColors.danger),
                      _legend('Late', a.lateDays, AppColors.warning),
                      const Divider(height: 14),
                      _legend('Total days', a.totalDays, AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  PieChartSectionData _slice(double v, Color c) => PieChartSectionData(value: v <= 0 ? 0.0001 : v, color: c, radius: 22, showTitle: false);

  Widget _legend(String label, int value, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Text('$value', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      );

  // ── marks ────────────────────────────────────────────────────────────────────────────
  Widget _marksCard(ParentDashboardData d) {
    final scored = d.marks.where((m) => m.marksObtained != null && m.maxMarks > 0).toList();
    final bySubject = <String, List<TestMark>>{};
    for (final m in scored) {
      bySubject.putIfAbsent((m.subjectName ?? 'Other').trim(), () => []).add(m);
    }
    final subjects = bySubject.entries.map((e) {
      final got = e.value.fold<double>(0, (s, m) => s + m.marksObtained!);
      final max = e.value.fold<double>(0, (s, m) => s + m.maxMarks);
      return (name: e.key, pct: max <= 0 ? 0.0 : got * 100 / max);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final totalGot = scored.fold<double>(0, (s, m) => s + m.marksObtained!);
    final totalMax = scored.fold<double>(0, (s, m) => s + m.maxMarks);
    final recent = [...scored]..sort((a, b) => (b.testDate ?? DateTime(2000)).compareTo(a.testDate ?? DateTime(2000)));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Marks', Icons.star_rounded, AppColors.violet),
          if (scored.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: Text('No marks entered yet.', style: TextStyle(color: AppColors.textSecondary))))
          else ...[
            Row(children: [
              Expanded(child: StatCard(label: 'Total marks', value: '${totalGot.toStringAsFixed(0)} / ${totalMax.toStringAsFixed(0)}', color: AppColors.violet, icon: Icons.assignment_turned_in_outlined)),
              const SizedBox(width: 8),
              Expanded(child: StatCard(label: 'Overall', value: '${(totalMax <= 0 ? 0 : totalGot * 100 / totalMax).toStringAsFixed(1)}%', color: AppColors.info, icon: Icons.percent_rounded)),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              height: 170,
              child: BarChart(BarChartData(
                maxY: 100,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(drawVerticalLine: false, horizontalInterval: 25),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38, interval: 25)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= subjects.length) return const SizedBox();
                        final n = subjects[i].name;
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(n.length > 6 ? '${n.substring(0, 5)}.' : n, style: const TextStyle(fontSize: 10.5)));
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < subjects.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: subjects[i].pct.clamp(0, 100), width: 18, color: subjects[i].pct >= 35 ? AppColors.violet : AppColors.danger, borderRadius: BorderRadius.circular(5)),
                    ]),
                ],
              )),
            ),
            const SizedBox(height: 10),
            for (final m in recent.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${m.subjectName ?? ''} · ${m.examName ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  Text('${m.marksObtained!.toStringAsFixed(m.marksObtained! % 1 == 0 ? 0 : 1)}/${m.maxMarks}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ]),
              ),
          ],
        ],
      ),
    );
  }

  // ── fees ─────────────────────────────────────────────────────────────────────────────
  Widget _feesCard(ParentDashboardData d) {
    final paid = d.totalPaid, disc = d.discount, bal = d.balance < 0 ? 0.0 : d.balance;
    final any = paid + disc + bal > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Fees', Icons.account_balance_wallet_rounded, AppColors.warning),
          if (!any)
            const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: Text('No fee data yet.', style: TextStyle(color: AppColors.textSecondary))))
          else
            Row(
              children: [
                SizedBox(
                  width: 150, height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 46,
                        sections: [_slice(paid, AppColors.success), _slice(disc, AppColors.info), _slice(bal, AppColors.warning)],
                      )),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${(d.netTotal <= 0 ? 0 : paid * 100 / d.netTotal).clamp(0, 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const Text('paid', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _money3('Paid', paid, AppColors.success),
                      _money3('Discount', disc, AppColors.info),
                      _money3('Balance', bal, AppColors.warning),
                      const Divider(height: 14),
                      _money3('Total fee', d.netTotal, AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          if (d.dueDate != null && bal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Next installment: ${DateFormat('d MMM yyyy').format(d.dueDate!)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _money3(String label, double v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Text(_money.format(v), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
        ]),
      );
}
