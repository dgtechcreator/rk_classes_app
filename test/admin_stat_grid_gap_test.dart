import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_classes_app/widgets/admin_home_widgets.dart';

void main() {
  testWidgets('stat grid starts right below the 10px gap, not pushed down by the status-bar inset', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        // A phone with a status bar: the top inset is what leaked into the grid as extra space.
        data: const MediaQueryData(size: Size(360, 780), padding: EdgeInsets.only(top: 36)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 100, color: Colors.grey),
                const SizedBox(height: 10),
                AdminStatGrid(children: [
                  AdminStatCard(label: 'Faculty', value: '24', color: Colors.purple, icon: Icons.school_rounded, onTap: () {}),
                  AdminStatCard(label: 'Users', value: '13', color: Colors.blue, icon: Icons.person, onTap: () {}),
                ]),
              ],
            ),
          ),
        ),
      ),
    ));

    final gridTop = tester.getTopLeft(find.byType(AdminStatCard).first).dy;
    // Attendance-like box ends at y=100, then 10px gap: the first card must start at y=110, not 146.
    expect(gridTop, closeTo(110, 1));
  });
}
