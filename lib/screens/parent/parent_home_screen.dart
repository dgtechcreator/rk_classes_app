import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/parent_data_controller.dart';
import '../../core/session.dart';
import '../../models/student.dart';
import '../../theme/app_theme.dart';
import '../../theme/subject_visuals.dart';
import '../../widgets/attendance_ring.dart';
import '../../widgets/common.dart';
import '../fees/receipt_screen.dart';
import 'parent_fees_screen.dart';
import 'parent_grades_screen.dart';

/// Pushed routes sit outside the shell's provider, so hand the controller to them explicitly.
Future<T?> _pushWithController<T>(BuildContext context, Widget page) {
  final ctrl = context.read<ParentDataController>();
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: ctrl, child: page)));
}

class ParentHomeScreen extends StatelessWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parentName = context.watch<Session>().parentName;
    final ctrl = context.watch<ParentDataController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: ctrl.load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: GreetingHeader(
                  greeting: 'Hello,',
                  name: parentName.isEmpty ? 'Parent' : parentName.split(' ').first,
                  leadingIcon: Icons.family_restroom,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: _buildBody(context, ctrl),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ParentDataController ctrl) {
    if (ctrl.loading && ctrl.data == null) return const Padding(padding: EdgeInsets.only(top: 40), child: LoadingView());
    if (ctrl.error != null && ctrl.data == null) {
      return Padding(padding: const EdgeInsets.only(top: 24), child: ErrorView(message: ctrl.error!, onRetry: ctrl.load));
    }
    if (ctrl.children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: EmptyState(message: 'No children linked to this account yet.', icon: Icons.family_restroom),
      );
    }

    final d = ctrl.data;
    final subjects = <String>{
      for (final m in d?.marks ?? []) if ((m.subjectName ?? '').isNotEmpty) m.subjectName!,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChildCard(ctrl: ctrl),
        if (d != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: AppShadows.card),
            child: Row(
              children: [
                AttendanceRing(
                  percent: d.attendance?.attendancePct ?? 0,
                  color: (d.attendance?.attendancePct ?? 0) >= 75 ? AppColors.success : AppColors.warning,
                  label: 'Attendance',
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniStatRow(Icons.event_available_rounded, AppColors.info,
                          d.attendance == null ? '-' : '${d.attendance!.presentDays}/${d.attendance!.totalDays}', 'Present Days'),
                      const SizedBox(height: 14),
                      _miniStatRow(Icons.account_balance_wallet_outlined, d.balance > 0 ? AppColors.danger : AppColors.success,
                          NumberFormat.compactCurrency(symbol: '₹').format(d.balance), 'Balance Due'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Subjects'),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: subjects.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (_, i) {
                  final name = subjects.elementAt(i);
                  final v = subjectVisual(name);
                  return SubjectQuickTile(
                    icon: v.icon,
                    color: v.color,
                    label: name,
                    onTap: () => _pushWithController(context, ParentGradesScreen(initialSubject: name)),
                  );
                },
              ),
            ),
          ],
          if (d.marks.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Recent Grades',
              action: TextButton(
                onPressed: () => _pushWithController(context, const ParentGradesScreen()),
                child: const Text('View all'),
              ),
            ),
            ...d.marks.take(3).map((m) {
              final pct = m.marksObtained == null ? null : (m.marksObtained! / m.maxMarks * 100);
              final v = subjectVisual(m.subjectName);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListInfoCard(
                  title: m.subjectName ?? 'Subject',
                  subtitle: m.examName,
                  icon: v.icon,
                  iconColor: v.color,
                  badgeText: m.marksObtained == null ? 'Absent' : 'Grade: ${m.marksObtained!.toStringAsFixed(0)}/${m.maxMarks}',
                  badgeColor: pct == null ? AppColors.danger : (pct >= 35 ? AppColors.success : AppColors.danger),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Fees',
            action: TextButton(
              onPressed: () => _pushWithController(context, const ParentFeesScreen(standalone: true)),
              child: const Text('Details'),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
            child: Row(
              children: [
                _feeFigure('Total', d.netTotal, AppColors.textPrimary),
                _feeFigure('Paid', d.totalPaid, AppColors.success),
                _feeFigure('Balance', d.balance, d.balance > 0.5 ? AppColors.danger : AppColors.success),
              ],
            ),
          ),
          if (d.feeHistory.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...d.feeHistory.take(3).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
                    child: ListTile(
                      dense: true,
                      onTap: () => ReceiptScreen.openForParent(context, p, student: ctrl.selected ?? d.student),
                      leading: const CircleAvatar(radius: 18, backgroundColor: AppColors.successSoft, child: Icon(Icons.payments_outlined, color: AppColors.success, size: 18)),
                      title: Text(NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(p.netAmount), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${DateFormat('dd MMM yyyy').format(p.paymentDate)} · ${p.paymentMode}'),
                      trailing: const Icon(Icons.receipt_long_outlined, color: AppColors.info),
                    ),
                  ),
                )),
          ],
        ],
      ],
    );
  }

  Widget _feeFigure(String label, double v, Color c) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
            ),
          ],
        ),
      );

  Widget _miniStatRow(IconData icon, Color color, String value, String label) {
    return Row(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.ctrl});
  final ParentDataController ctrl;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.selected;
    if (s == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Text('YOUR CHILD', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text(s.classLabel, style: const TextStyle(color: AppColors.info, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              if (ctrl.children.length > 1)
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () => _pickChild(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                    child: const Icon(Icons.swap_horiz, color: AppColors.primary, size: 20),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickChild(BuildContext context) async {
    final chosen = await showModalBottomSheet<Student>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Switch Child', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...ctrl.children.map((c) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Text(c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(c.fullName),
                  subtitle: Text(c.classLabel),
                  trailing: c.studentId == ctrl.selected?.studentId ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () => Navigator.pop(context, c),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) ctrl.selectChild(chosen);
  }
}
