import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../attendance/attendance_mark_screen.dart';
import '../marks/marks_entry_screen.dart';
import '../teacher_attendance/teacher_attendance_mark_screen.dart';
import '../teacher_attendance/teacher_attendance_summary_screen.dart';

/// Home of a Class Representative (CR / Monitor): his class and the two things he may do - mark the class's
/// student attendance and add teacher attendance (subject + topic). Everything else is blocked on the server.
class CrHomeScreen extends StatelessWidget {
  const CrHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Hello, ${s.fullName.split(' ').first}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Class Representative', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.white, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your class', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(s.crLabel.isEmpty ? '—' : s.crLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (s.hasPerm('attendance_entry'))
              _action(context, Icons.event_available_outlined, 'Student Attendance', 'Mark present / absent for your class',
                  () => const AttendanceMarkScreen()),
            if (s.hasPerm('marks_entry'))
              _action(context, Icons.grade_outlined, 'Test Marks', 'Enter test marks of your class',
                  () => const MarksEntryScreen()),
            if (s.hasPerm('teacher_attendance')) ...[
              _action(context, Icons.badge_outlined, 'Teacher Attendance', 'Add teacher, subject and topic taught',
                  () => const TeacherAttendanceMarkScreen()),
              _action(context, Icons.history_outlined, 'My Entries', 'Teacher attendance entries you added',
                  () => const TeacherAttendanceSummaryScreen()),
            ],
            if (!s.hasPerm('attendance_entry') && !s.hasPerm('teacher_attendance') && !s.hasPerm('marks_entry'))
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('Your access is switched off. Please contact the admin.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 8),
            Text('You can work on today and the last ${s.crEditDays} days.',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String title, String subtitle, Widget Function() screen) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(icon, color: AppColors.primary)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen())),
      ),
    );
  }
}
