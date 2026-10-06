import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_classes_app/models/teacher_payment.dart';
import 'package:rk_classes_app/screens/teacher_payment/teacher_payment_summary_screen.dart';
import 'package:rk_classes_app/services/teacher_payment_service.dart';
import 'package:rk_classes_app/theme/app_theme.dart';

class _FakeService implements TeacherPaymentService {
  _FakeService(this.report);
  final TeacherPaymentReport report;
  int calls = 0;

  @override
  Future<TeacherPaymentReport> getSummary({int? year, int month = 0, int? facultyId, String status = 'all'}) async {
    calls++;
    return report;
  }

  @override
  Future<TeacherPaymentReport> getMine({int? year}) async {
    calls++;
    return report;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TeacherPayment _p(int id, int fac, String name, int month, bool paid, double amt) => TeacherPayment(
      teacherPaymentId: id, facultyId: fac, facultyName: name, paymentType: 'Fixed', rate: amt, totalAmount: amt,
      paymentMonth: month, paymentYear: DateTime.now().year, isPaid: paid,
      paymentDate: paid ? DateTime(DateTime.now().year, month, 5) : null, paymentMode: paid ? 'Cash' : null,
    );

void main() {
  testWidgets('filters work instantly and locally: empty month, pending, paid, teacher', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final report = TeacherPaymentReport(
      linked: true,
      summary: TeacherPaymentSummary(),
      payments: [
        _p(1, 10, 'Asha', 8, true, 10000),
        _p(2, 10, 'Asha', 9, false, 12000),
        _p(3, 11, 'Bina', 9, true, 5000),
      ],
      faculty: const [(id: 10, name: 'Asha'), (id: 11, name: 'Bina')],
    );
    final svc = _FakeService(report);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: TeacherPaymentSummaryScreen(service: svc)));
    await tester.pumpAndSettle();
    expect(svc.calls, 1);

    // all three entries, totals computed on the phone
    expect(find.text('Payments (3)'), findsOneWidget);
    expect(find.text('₹27,000'), findsOneWidget); // total

    // Pending chip -> only the pending entry, with NO spinner and NO new request
    await tester.tap(find.text('Pending').first);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Payments (1)'), findsOneWidget);
    expect(svc.calls, 1);

    // Paid chip
    await tester.tap(find.text('Paid').first);
    await tester.pump();
    expect(find.text('Payments (2)'), findsOneWidget);

    // back to All, then pick a month that has no entry -> empty state, not the old rows
    await tester.tap(find.text('All').first);
    await tester.pump();
    await tester.tap(find.text('All months'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('January').last);
    await tester.pumpAndSettle();
    expect(find.text('Payments (0)'), findsOneWidget);
    expect(find.text('No payments for this selection.'), findsOneWidget);
    expect(find.text('Asha'), findsNothing);
    expect(svc.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
