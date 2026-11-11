import 'package:flutter_test/flutter_test.dart';
import 'package:rk_classes_app/models/finance.dart';

FinanceStudent st(String c, String b, String s, double fees, double col) => FinanceStudent(
    studentId: 1, fullName: 'x', admissionNo: '', className: c, sectionName: s, batchName: b,
    phone: '', fatherPhone: '', motherPhone: '', totalFees: fees, collected: col, discount: 0, balance: fees - col);

void main() {
  test('groups by class, batch and medium in order', () {
    final rows = FinanceAcademicRow.groupStudents([
      st('10th', 'Evening', 'Hindi', 100, 10),
      st('6th', 'Evening', 'English', 100, 50),
      st('6th', 'Morning', 'Hindi', 200, 100),
      st('6th', 'Morning', 'English', 300, 0),
      st('6th', 'Morning', 'English', 100, 100),
    ]);
    expect(rows.map((r) => '${r.className}|${r.batchName}|${r.sectionName}|${r.studentCount}').toList(), [
      '6th|Morning|English|2', '6th|Morning|Hindi|1', '6th|Evening|English|1', '10th|Evening|Hindi|1',
    ]);
    expect(rows.first.totalFees, 400);
    expect(rows.first.balance, 300);
  });
}
