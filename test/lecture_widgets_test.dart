import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_classes_app/models/lecture.dart';
import 'package:rk_classes_app/models/toppers.dart';
import 'package:rk_classes_app/widgets/lecture_widgets.dart';
import 'package:rk_classes_app/widgets/toppers_card.dart';

Lecture _lecture({String status = 'Scheduled', bool needsUpdate = false, String? note}) => Lecture(
      lectureId: 1,
      date: DateTime(2026, 10, 7),
      startTime: '10:00',
      endTime: '11:00',
      classId: 9,
      groupLabel: '9th • English • Morning with a very long label to make sure it wraps instead of overflowing',
      subject: 'Maths -1 and a long subject name',
      facultyId: 1,
      teacher: 'Kapil Sir',
      topic: 'Quadratic equations and their applications in word problems',
      status: status,
      statusNote: note,
      isRepeating: true,
      needsUpdate: needsUpdate,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SizedBox(width: 340, child: SingleChildScrollView(child: child))));

void main() {
  test('formatHours trims trailing zeros', () {
    expect(formatHours(2.25), '2.25');
    expect(formatHours(3), '3');
    expect(formatHours(1.5), '1.5');
    expect(formatHours(0), '0');
  });

  testWidgets('LectureCard renders every status without overflow', (tester) async {
    for (final l in [
      _lecture(),
      _lecture(status: 'Completed'),
      _lecture(status: 'Cancelled', note: 'Teacher on leave for the day, back tomorrow'),
      _lecture(needsUpdate: true),
    ]) {
      await tester.pumpWidget(_host(LectureCard(lecture: l)));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(_host(LectureCard(lecture: _lecture(status: 'Cancelled', note: 'x'))));
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.textContaining('Cancelled: x'), findsOneWidget);
  });

  testWidgets('Totals row and month card fit a narrow phone', (tester) async {
    final totals = LectureTotals(total: 12, held: 8, scheduled: 3, cancelled: 1, notUpdated: 2, hoursHeld: 7.25);
    await tester.pumpWidget(_host(LectureTotalsRow(totals, showNotUpdated: true)));
    expect(tester.takeException(), isNull);
    expect(find.text('7.25'), findsOneWidget);

    final month = MonthLectures(
      label: 'October 2026',
      totals: totals,
      byGroup: [LabelCounts(label: '9th • English • Morning', held: 5, scheduled: 1, cancelled: 0)],
      bySubject: [for (var i = 0; i < 8; i++) LabelCounts(label: 'Subject number $i', held: i, scheduled: 1, cancelled: 0)],
    );
    await tester.pumpWidget(_host(MonthCountsCard(month: month, showClasses: true)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ToppersCard shows own rank footer when child is outside top 5', (tester) async {
    final section = TopperSection(
      ranked: 41,
      myRank: 22,
      myPercentage: 50,
      top: [for (var i = 1; i <= 5; i++) TopperRow(rank: i, fullName: 'Student with a rather long full name $i', percentage: 100.0 - i, totalObtained: 20, totalMax: 20, isMe: false)],
    );
    await tester.pumpWidget(_host(ToppersCard(title: 'Class Toppers', subtitle: '9th • English', section: section)));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('rank #22 of 41'), findsOneWidget);
  });
}
