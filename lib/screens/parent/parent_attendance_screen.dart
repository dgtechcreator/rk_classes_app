import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/parent_data_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/attendance_ring.dart';
import '../../widgets/common.dart';

class ParentAttendanceScreen extends StatelessWidget {
  const ParentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ParentDataController>();
    final d = ctrl.data;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TabHeader(title: 'Attendance', subtitle: 'Day-by-day attendance record'),
            Expanded(
              child: ctrl.loading && d == null
                  ? const LoadingView()
                  : ctrl.error != null && d == null
                      ? ErrorView(message: ctrl.error!, onRetry: ctrl.load)
                      : d == null
                          ? const EmptyState(message: 'No children linked to this account yet.', icon: Icons.family_restroom)
                          : RefreshIndicator(
                              onRefresh: ctrl.load,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: AppShadows.card),
                                    child: Row(
                                      children: [
                                        AttendanceRing(
                                          percent: d.attendance?.attendancePct ?? 0,
                                          color: (d.attendance?.attendancePct ?? 0) >= 75 ? AppColors.success : AppColors.warning,
                                          label: 'Overall',
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 34, height: 34,
                                                    decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.13), shape: BoxShape.circle),
                                                    child: const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.info),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(d.attendance == null ? '-' : '${d.attendance!.presentDays}/${d.attendance!.totalDays}',
                                                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                                                      const Text('Present Days', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}
