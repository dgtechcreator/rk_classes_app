import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rk_classes_app/main.dart';

void main() {
  testWidgets('App boots to the splash gate without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const RkClassesApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
