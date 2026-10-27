import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One thing that happened to a child (marked absent, marks entered, fee received, lecture scheduled...),
/// as listed by GET /api/parent/notifications.
class StudentActivity {
  StudentActivity({
    required this.activityId,
    required this.studentId,
    required this.studentName,
    required this.kind,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isUnread,
    this.className,
  });

  final int activityId;
  final int studentId;
  final String studentName;
  final String? className;
  final String kind;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isUnread;

  ActivityLook get look => ActivityLook.of(kind);

  factory StudentActivity.fromJson(Map<String, dynamic> j) => StudentActivity(
        activityId: (j['activityId'] as num?)?.toInt() ?? 0,
        studentId: (j['studentId'] as num?)?.toInt() ?? 0,
        studentName: j['studentName']?.toString() ?? '',
        className: j['className']?.toString(),
        kind: j['kind']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
        isUnread: j['isUnread'] == true,
      );
}

/// The four groups a parent can filter by.
enum ActivityGroup { attendance, marks, fees, lectures, notes }

extension ActivityGroupLabel on ActivityGroup {
  String get label => switch (this) {
        ActivityGroup.attendance => 'Attendance',
        ActivityGroup.marks => 'Marks',
        ActivityGroup.fees => 'Fees',
        ActivityGroup.lectures => 'Lectures',
        ActivityGroup.notes => 'Notes',
      };
}

/// Icon + colours of a notification kind (same kinds as SchoolMS.Domain.ActivityType on the server).
class ActivityLook {
  const ActivityLook(this.icon, this.color, this.soft, this.group);
  final IconData icon;
  final Color color;
  final Color soft;
  final ActivityGroup group;

  static ActivityLook of(String kind) => switch (kind) {
        'absent' => const ActivityLook(Icons.person_off_rounded, AppColors.danger, AppColors.dangerSoft, ActivityGroup.attendance),
        'late' => const ActivityLook(Icons.schedule_rounded, AppColors.warning, AppColors.warningSoft, ActivityGroup.attendance),
        'present' => const ActivityLook(Icons.check_circle_rounded, AppColors.success, AppColors.successSoft, ActivityGroup.attendance),
        'marks' => const ActivityLook(Icons.star_rounded, AppColors.violet, AppColors.violetSoft, ActivityGroup.marks),
        'fee' => const ActivityLook(Icons.currency_rupee_rounded, AppColors.success, AppColors.successSoft, ActivityGroup.fees),
        'notes' => const ActivityLook(Icons.description_rounded, AppColors.info, AppColors.infoSoft, ActivityGroup.notes),
        'practice' => const ActivityLook(Icons.edit_note_rounded, AppColors.warning, AppColors.warningSoft, ActivityGroup.notes),
        'lecture' => const ActivityLook(Icons.co_present_rounded, AppColors.info, AppColors.infoSoft, ActivityGroup.lectures),
        'lecture_update' => const ActivityLook(Icons.edit_calendar_rounded, AppColors.teal, AppColors.tealSoft, ActivityGroup.lectures),
        'lecture_cancel' => const ActivityLook(Icons.event_busy_rounded, AppColors.danger, AppColors.dangerSoft, ActivityGroup.lectures),
        'lecture_done' => const ActivityLook(Icons.task_alt_rounded, AppColors.success, AppColors.successSoft, ActivityGroup.lectures),
        _ => const ActivityLook(Icons.notifications_rounded, AppColors.textSecondary, AppColors.borderNeutral, ActivityGroup.attendance),
      };
}
