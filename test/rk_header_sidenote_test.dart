import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_classes_app/widgets/rk_header.dart';

void main() {
  const longClass = '12th Science Evening Batch Section Alpha Extra Long Name';

  Future<void> pump(WidgetTester tester, {String? sideNote, String? extraNote}) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RkHomeHeader(
          greeting: 'Hello,',
          name: 'Vivek',
          roleLabel: 'Student',
          sideNote: sideNote,
          extraNote: extraNote,
        ),
      ),
    ));
  }

  testWidgets('class / stream / medium / batch is shown in full over up to two lines, never cut on one line', (tester) async {
    await pump(tester, sideNote: longClass, extraNote: 'Roll No 7');
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text(longClass));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    final chipRect = tester.getRect(find.text(longClass));
    expect(chipRect.right, lessThanOrEqualTo(360));
  });

  testWidgets('roll number is its own chip, separate from the class chip', (tester) async {
    await pump(tester, sideNote: longClass, extraNote: 'Roll No 7');
    expect(find.text('Roll No 7'), findsOneWidget);
    expect(find.text(longClass), findsOneWidget);
    final rollRect = tester.getRect(find.text('Roll No 7'));
    final classRect = tester.getRect(find.text(longClass));
    // The class chip sits on a line below the roll chip, so the roll does not take space from the class text.
    expect(classRect.top, greaterThan(rollRect.top));
  });

  testWidgets('no roll chip when no roll note is given', (tester) async {
    await pump(tester, sideNote: '8th Hindi / Morning');
    expect(find.textContaining('Roll No'), findsNothing);
    expect(find.text('8th Hindi / Morning'), findsOneWidget);
  });
}
