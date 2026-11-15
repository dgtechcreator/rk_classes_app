import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_classes_app/widgets/child_info_pills.dart';

void main() {
  Future<void> pumpIn(WidgetTester tester, double width, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ));
  }

  testWidgets('roll pill shows the roll number', (tester) async {
    await pumpIn(tester, 280, const ChildInfoPills(classLabel: '10th English Morning', rollNo: '7'));
    expect(find.text('Roll No 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank roll shows a dash, not an empty pill', (tester) async {
    await pumpIn(tester, 280, const ChildInfoPills(classLabel: '8th Hindi', rollNo: '  '));
    expect(find.text('Roll No —'), findsOneWidget);
  });

  testWidgets('long class name is cut with ellipsis, roll pill stays inside a narrow card', (tester) async {
    const longClass = '12th Science Evening Batch Section Alpha Extra Long Name';
    await pumpIn(tester, 200, const ChildInfoPills(classLabel: longClass, rollNo: '12'));
    expect(tester.takeException(), isNull);
    final roll = tester.getRect(find.text('Roll No 12'));
    final card = tester.getRect(find.byType(SizedBox).first);
    expect(roll.right, lessThanOrEqualTo(card.right + 0.5));
    final classText = tester.widget<Text>(find.text(longClass));
    expect(classText.overflow, TextOverflow.ellipsis);
    expect(classText.maxLines, 2);
  });

  testWidgets('no pills when the class label is empty, roll still shown', (tester) async {
    await pumpIn(tester, 280, const ChildInfoPills(classLabel: '', rollNo: '3'));
    expect(find.text('Roll No 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
