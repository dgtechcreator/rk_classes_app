import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/parent_data_controller.dart';
import '../../core/session.dart';
import '../../models/student.dart';
import '../../theme/app_theme.dart';
import '../../theme/subject_visuals.dart';
import '../../widgets/common.dart';
import 'parent_grades_screen.dart';

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
                child: Transform.translate(
                  offset: const Offset(0, -12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildBody(context, ctrl),
                  ),
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
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Attendance',
                  value: d.attendance == null ? '-' : '${d.attendance!.attendancePct.toStringAsFixed(0)}%',
                  color: AppColors.success,
                  icon: Icons.event_available,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Balance Due',
                  value: NumberFormat.compactCurrency(symbol: '₹').format(d.balance),
                  color: d.balance > 0 ? AppColors.danger : AppColors.success,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
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
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ParentGradesScreen(initialSubject: name))),
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
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentGradesScreen())),
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
          if (d.feeHistory.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Recent Fee Payments'),
            ...d.feeHistory.take(3).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListInfoCard(
                    title: p.feeTypeName ?? 'Fee Payment',
                    subtitle: '${DateFormat.yMMMd().format(p.paymentDate)} • ${p.paymentMode}',
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.success,
                    badgeText: NumberFormat.simpleCurrency(name: 'INR').format(p.netAmount),
                    badgeColor: AppColors.success,
                  ),
                )),
          ],
        ],
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
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
                Text(s.classLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (ctrl.children.length > 1)
            IconButton(icon: const Icon(Icons.swap_horiz, color: AppColors.primary), onPressed: () => _pickChild(context)),
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
