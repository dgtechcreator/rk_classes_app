import 'package:flutter_test/flutter_test.dart';
import 'package:rk_classes_app/core/receipt_pdf.dart';
import 'package:rk_classes_app/models/contact_number.dart';
import 'package:rk_classes_app/models/dashboard.dart';
import 'package:rk_classes_app/models/fee_structure.dart';
import 'package:rk_classes_app/models/message_template.dart';
import 'package:rk_classes_app/models/teacher_payment.dart';

void main() {
  contactTests();
  receiptTests();
  classSummaryTests();
  teacherPaymentTests();
  test('template placeholders are replaced, unknown ones kept', () {
    final t = MessageTemplate(templateId: 1, category: 'Absent', title: 't', body: '{student} ({class}) {Date} {unknown}');
    expect(t.render({'student': 'Aman', 'class': '5th', 'date': '06-10-2026'}), 'Aman (5th) 06-10-2026 {unknown}');
  });

  test('absent student contacts are de-duplicated and ordered father, mother, student', () {
    final a = AbsentStudent.fromJson({
      'studentId': 1, 'fullName': 'A', 'admissionNo': '1', 'className': '5th', 'sectionName': 'English Medium',
      'phone': '98765 43210', 'fatherPhone': '9876543210', 'motherPhone': '+91 91234 56789',
    });
    expect(a.contacts.map((c) => c.label), ['Father', 'Mother']);
    expect(a.contacts[0].whatsappNumber, '919876543210');
    expect(a.contacts[1].whatsappNumber, '919123456789');
  });

  test('class strength parses medium split and tolerates its absence', () {
    final withSections = ClassStrength.fromJson({
      'className': '5th', 'studentCount': 50, 'color': '#2563eb',
      'sections': [
        {'sectionName': 'English Medium', 'studentCount': 30},
        {'sectionName': 'Hindi Medium', 'studentCount': 20},
      ],
    });
    expect(withSections.sections.map((s) => '${s.sectionName}:${s.studentCount}'), ['English Medium:30', 'Hindi Medium:20']);
    expect(ClassStrength.fromJson({'className': '6th', 'studentCount': 10}).sections, isEmpty);
  });
}

void contactTests() {
  test('buildContacts drops junk, dedupes across +91/0 formats, keeps father-mother-student order', () {
    final c = buildContacts(father: '0', mother: '+91 98765 43210', student: '09876543210');
    expect(c.length, 1);
    expect(c.first.label, 'Mother');
    expect(c.first.whatsappNumber, '919876543210');
    expect(buildContacts(father: null, mother: '', student: '12345'), isEmpty);
  });
}

void receiptTests() {
  test('amountInWords follows the Indian system like the web receipt', () {
    expect(ReceiptPdf.amountInWords(5000), 'Five Thousand');
    expect(ReceiptPdf.amountInWords(262500), 'Two Lakh Sixty Two Thousand Five Hundred');
    expect(ReceiptPdf.amountInWords(10000000), 'One Crore');
    expect(ReceiptPdf.amountInWords(0), 'Zero');
  });
}

void classSummaryTests() {
  test('class summary percentages: collected and pending always add up to 100', () {
    final s = FeeStructureSummary.fromJson({
      'className': '6th', 'sectionName': 'English', 'studentCount': 13, 'feeHeads': 13,
      'collectedAmt': 38000, 'pendingAmt': 47000, 'totalFees': 91000, 'discount': 6000,
    });
    expect(s.netTotal, 85000);
    expect(s.collectedPct, 45);
    expect(s.pendingPct, 55);
    // no fee structure set yet -> no percentages instead of nonsense
    final none = FeeStructureSummary.fromJson({'className': '11th', 'sectionName': 'Science', 'collectedAmt': 33000, 'discount': 5000});
    expect(none.collectedPct, 0);
    expect(none.pendingPct, 0);
    // an older server sends no totalFees -> flagged so the UI doesn't invent 0%/100%
    expect(FeeStructureSummary.fromJson({'className': '5th', 'collectedAmt': 0, 'pendingAmt': 7000}).hasFinanceFigures, isFalse);
    expect(s.hasFinanceFigures, isTrue);
  });
}

void teacherPaymentTests() {
  test('teacher payment report parses summary, payments and the unlinked case', () {
    final r = TeacherPaymentReport.fromJson({
      'linked': true, 'facultyName': 'NANDANI', 'year': 2026, 'years': [2026, 2025],
      'summary': {
        'count': 2, 'paidCount': 2, 'pendingCount': 0, 'totalAmount': 47000, 'paidAmount': 47000, 'pendingAmount': 0,
        'teachers': [{'facultyId': 15, 'facultyName': 'NANDANI', 'count': 2, 'paidAmount': 47000, 'pendingAmount': 0, 'lastPaidOn': '2026-10-06T17:41:17.93'}],
      },
      'payments': [
        {'teacherPaymentId': 5, 'facultyId': 15, 'facultyName': 'NANDANI', 'paymentType': 'Fixed', 'rate': 20000, 'totalAmount': 20000,
         'paymentMonth': 10, 'paymentYear': 2026, 'isPaid': true, 'paymentDate': '2026-10-06T17:41:17.93'},
      ],
      'allFaculty': [{'facultyId': 15, 'fullName': 'NANDANI '}],
    });
    expect(r.linked, isTrue);
    expect(r.summary.paidAmount, 47000);
    expect(r.summary.teachers.single.lastPaidOn?.day, 6);
    expect(r.payments.single.monthYearLabel, 'October 2026');
    expect(r.faculty.single.name, 'NANDANI');

    final unlinked = TeacherPaymentReport.fromJson({'linked': false, 'message': 'not linked'});
    expect(unlinked.linked, isFalse);
    expect(unlinked.payments, isEmpty);
    expect(unlinked.summary.count, 0);
  });
}
