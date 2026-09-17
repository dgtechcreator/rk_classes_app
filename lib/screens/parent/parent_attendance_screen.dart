import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/parent_data_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ParentAttendanceScreen extends StatelessWidget {
  const ParentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ParentDataController>();
    final d = ctrl.data;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ctrl.loading && d == null
          ? const LoadingView()
          : ctrl.error != null && d == null
              ? ErrorView(message: ctrl.error!, onRetry: ctrl.load)
              : d == null
                  ? const EmptyState(message: 'No children linked to this account yet.', icon: Icons.family_restroom)
                  : RefreshIndicator(
                      onRefresh: ctrl.load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
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
                                  label: 'Present Days',
                                  value: d.attendance == null ? '-' : '${d.attendance!.presentDays}/${d.attendance!.totalDays}',
                                  color: AppColors.info,
                                  icon: Icons.calendar_month,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const SectionHeader(title: 'History'),
                          if (d.attendanceDetail.isEmpty)
                            const EmptyState(message: 'No attendance records yet.', icon: Icons.event_busy)
                          else
                            ...d.attendanceDetail.map((a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ListInfoCard(
                                    title: DateFormat.yMMMEd().format(a.attendanceDate),
                                    subtitle: [a.subject, a.sirName].where((e) => e != null && e.isNotEmpty).join(' • '),
                                    icon: Icons.event_note_outlined,
                                    iconColor: statusColor(a.status),
                                    badgeText: a.status,
                                    badgeColor: statusColor(a.status),
                                  ),
                                )),
                        ],
                      ),
                    ),
    );
  }
}
