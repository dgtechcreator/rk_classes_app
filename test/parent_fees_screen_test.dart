import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rk_classes_app/core/parent_data_controller.dart';
import 'package:rk_classes_app/models/fee_structure.dart';
import 'package:rk_classes_app/models/student.dart';
import 'package:rk_classes_app/screens/parent/parent_fees_screen.dart';
import 'package:rk_classes_app/theme/app_theme.dart';

void main() {
  testWidgets('parent fees screen shows net total, paid, balance and a receipt per payment', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final student = Student(studentId: 1, admissionNo: 'RKC-1', fullName: 'Test Child', className: '10th', sectionName: 'English');
    FeePayment pay(int id, double amt) => FeePayment(
          paymentId: id, receiptNo: 'RKC-2026-00$id', amount: amt, discount: 0, lateFine: 0, netAmount: amt,
          paymentDate: DateTime(2026, 8, id), paymentMode: 'Cash',
        );
    final ctrl = ParentDataController()
      ..loading = false
      ..children = [student]
      ..selected = student
      ..data = ParentDashboardData(
        student: student,
        attendanceDetail: const [],
        marks: const [],
        feeHistory: [pay(1, 10000), pay(2, 3000)],
        totalPaid: 13000,
        actualFee: 25000,
        balance: 11500,
        discount: 1500,
        additionalCharges: 1000,
        dueDate: DateTime(2026, 10, 20),
        feeStructures: [
          FeeStructure(structureId: 1, academicYearId: 1, classId: 1, sectionId: 1, feeTypeId: 1, feeTypeName: 'Annual Fee', amount: 25000, dueDay: 20, isMonthly: false),
        ],
      );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChangeNotifierProvider.value(value: ctrl, child: const ParentFeesScreen()),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('₹24,500'), findsOneWidget); // 25,000 + 1,000 charges - 1,500 discount
    expect(find.text('₹13,000'), findsOneWidget);
    expect(find.text('₹11,500'), findsWidgets);
    expect(find.text('Receipt'), findsNWidgets(2));
    expect(find.textContaining('Discount'), findsWidgets);
  });
}
