import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/student.dart';

/// Builds the fee-receipt PDF — same content/order as the web receipt (Views/Fees/Receipt.cshtml),
/// laid out on an A5 portrait page. Amounts use "Rs." because the PDF's built-in font has no ₹ glyph.
class ReceiptPdf {
  static const _instituteName = 'RAMJEET KALAVATI EDUCATIONAL INSTITUTE';
  static const _address = [
    'Shop No. 2, Santosh Society, Krishna Nagar,',
    'Near Eden School, Kajupada Pipe Line,',
    'Sakinaka, Mumbai 400072.',
  ];

  static Future<Uint8List> build({
    required FeePayment payment,
    Student? student,
    double remainingBalance = 0,
    DateTime? dueDate,
  }) async {
    final logo = pw.MemoryImage(
      (await rootBundle.load(
        'assets/images/rk_logo_full.png',
      )).buffer.asUint8List(),
    );
    final doc = pw.Document(
      title: 'Fee Receipt ${payment.receiptNo}',
      author: 'RK Classes',
    );

    final d = payment.paymentDate;
    final year = d.month >= 4
        ? '${d.year}-${d.year + 1}'
        : '${d.year - 1}-${d.year}';
    final mode = payment.paymentMode;
    final isCheque = mode == 'Cheque' || mode == 'Demand Draft';
    final isOnline = mode == 'Online Transfer' || mode == 'UPI';
    final ref = (payment.transactionRef ?? '').trim();
    final chequeNo = isCheque && ref.isNotEmpty ? ref : 'NA';
    final onlineRef = isOnline && ref.isNotEmpty ? ref : 'NA';
    final money = NumberFormat('#,##,##0', 'en_IN');

    pw.Widget cell(String label, String value, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 8.5),
              children: [
                pw.TextSpan(
                  text: label,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: bold ? 10 : 8.5,
                  ),
                ),
                pw.TextSpan(text: value),
              ],
            ),
          ),
        );

    pw.TableRow row(List<pw.Widget> cells) => pw.TableRow(children: cells);

    // Stacked tables (the pdf Table has no colspan); `top: false` drops the shared edge to avoid a doubled line.
    pw.Widget table(
      List<pw.TableRow> rows, {
      required Map<int, pw.TableColumnWidth> cols,
      bool top = true,
    }) => pw.Table(
      border: pw.TableBorder(
        top: top ? const pw.BorderSide(width: 0.6) : pw.BorderSide.none,
        bottom: const pw.BorderSide(width: 0.6),
        left: const pw.BorderSide(width: 0.6),
        right: const pw.BorderSide(width: 0.6),
        horizontalInside: const pw.BorderSide(width: 0.6),
        verticalInside: const pw.BorderSide(width: 0.6),
      ),
      columnWidths: cols,
      children: rows,
    );

    final contact = [student?.fatherPhone, student?.motherPhone, student?.phone]
        .whereType<String>()
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '-');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(18),
        build: (_) => pw.Align(
          alignment: pw.Alignment.topCenter,
          child: pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "Kapil Sir's",
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'SINCE : 2002',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(width: 1),
                      top: pw.BorderSide(width: 0.5),
                    ),
                  ),
                  child: pw.Text(
                    _instituteName,
                    style: pw.TextStyle(
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.7)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 16,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(width: 0.7)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                height: 46,
                                child: pw.Image(
                                  logo,
                                  fit: pw.BoxFit.contain,
                                  alignment: pw.Alignment.centerLeft,
                                ),
                              ),
                              pw.SizedBox(height: 5),
                              for (final l in _address)
                                pw.Text(
                                  l,
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                              pw.Text(
                                'E-Mail: rkclasseskapilsir2002@gmail.com',
                                style: const pw.TextStyle(fontSize: 7.5),
                              ),
                              pw.Text(
                                'Website: www.myrkclasses.com',
                                style: const pw.TextStyle(fontSize: 7.5),
                              ),
                              pw.Text(
                                'Mobile No: 9870375795 / 8108499214',
                                style: const pw.TextStyle(fontSize: 7.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 10,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                (payment.studentName ??
                                        student?.fullName ??
                                        '-')
                                    .toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Address: ${student?.address?.trim().isNotEmpty == true ? student!.address!.trim() : '-'}',
                                style: const pw.TextStyle(fontSize: 7.5),
                              ),
                              pw.Text(
                                'Contact No.: $contact',
                                style: const pw.TextStyle(fontSize: 7.5),
                              ),
                              pw.Text(
                                'E-Mail: ${student?.email?.trim().isNotEmpty == true ? student!.email!.trim() : '-'}',
                                style: const pw.TextStyle(fontSize: 7.5),
                              ),
                              pw.Text(
                                'Admission No: ${payment.admissionNo ?? student?.admissionNo ?? '-'}',
                                style: const pw.TextStyle(fontSize: 7.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                table(
                  [
                    row([
                      cell('Fees Receipt ($year)', '', bold: true),
                      cell(
                        'Receipt Date: ',
                        DateFormat('dd-MM-yyyy').format(d),
                      ),
                      cell('Receipt No.: ', payment.receiptNo),
                    ]),
                    row([
                      cell(
                        'Course:- ',
                        payment.className?.trim().isNotEmpty == true
                            ? payment.className!.trim()
                            : '-',
                      ),
                      cell(
                        'Stream / Medium:- ',
                        payment.sectionName?.trim().isNotEmpty == true
                            ? payment.sectionName!.trim()
                            : '-',
                      ),
                      cell(
                        'Batch:- ',
                        payment.batchName?.trim().isNotEmpty == true
                            ? payment.batchName!.trim()
                            : '-',
                      ),
                    ]),
                  ],
                  cols: const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(3.2),
                    2: pw.FlexColumnWidth(2.8),
                  },
                ),
                table(
                  [
                    row([
                      cell(
                        'Amount received:- ',
                        'Rs. ${money.format(payment.netAmount)}/-',
                        bold: true,
                      ),
                    ]),
                    row([
                      cell(
                        'Amount received (in words):- ',
                        '${amountInWords(payment.netAmount)} Only/-',
                      ),
                    ]),
                  ],
                  cols: const {0: pw.FlexColumnWidth(1)},
                  top: false,
                ),
                table(
                  [
                    row([
                      cell('Payment Mode:- ', mode),
                      cell(
                        'Month: ',
                        payment.month?.trim().isNotEmpty == true
                            ? payment.month!.trim()
                            : '-',
                      ),
                      cell('Cheque No.: ', chequeNo),
                    ]),
                    row([
                      cell('Online Tranx. No.:- ', onlineRef),
                      cell(
                        'Late fine: ',
                        payment.lateFine > 0
                            ? 'Rs. ${money.format(payment.lateFine)}'
                            : 'Nil',
                      ),
                      cell('', ''),
                    ]),
                    row([
                      cell(
                        'Due Date:- ',
                        (remainingBalance > 0 && dueDate != null)
                            ? DateFormat('dd-MM-yyyy').format(dueDate)
                            : 'Nil',
                      ),
                      cell(
                        'Due fees:- ',
                        remainingBalance > 0
                            ? 'Rs. ${money.format(remainingBalance)}'
                            : 'Nil',
                      ),
                      cell(
                        'Collected by: ',
                        payment.collectorName?.trim().isNotEmpty == true
                            ? payment.collectorName!.trim()
                            : '-',
                      ),
                    ]),
                  ],
                  cols: const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(3.2),
                    2: pw.FlexColumnWidth(2.8),
                  },
                  top: false,
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Term and Conditions:',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      for (final t in const [
                        '1) This receipt of fees is an acknowledgement of the payment made to RK Classes.',
                        '2) Present this receipt of fees whenever demanded.',
                        '3) Fees once paid is neither refundable nor transferable under any circumstances.',
                        '4) This is a computer generated voucher, signature is not required.',
                      ])
                        pw.Text(
                          t,
                          style: const pw.TextStyle(
                            fontSize: 7.3,
                            lineSpacing: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return doc.save();
  }

  /// Indian-system amount in words, mirroring the web receipt helper.
  static String amountInWords(num number) {
    var n = number.floor();
    if (n == 0) return 'Zero';
    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];
    final b = StringBuffer();
    void part(int div, String name) {
      if (n >= div) {
        b.write('${amountInWords(n ~/ div)} $name ');
        n %= div;
      }
    }

    part(10000000, 'Crore');
    part(100000, 'Lakh');
    part(1000, 'Thousand');
    if (n >= 100) {
      b.write('${ones[n ~/ 100]} Hundred ');
      n %= 100;
    }
    if (n >= 20) {
      b.write('${tens[n ~/ 10]} ');
      n %= 10;
    }
    if (n > 0) b.write('${ones[n]} ');
    return b.toString().trim();
  }
}
