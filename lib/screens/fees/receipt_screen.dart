import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/api_client.dart';
import '../../core/receipt_pdf.dart';
import '../../core/receipt_share.dart';
import '../../models/contact_number.dart';
import '../../models/student.dart';
import '../../services/fees_service.dart';
import '../../services/message_template_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/contact_actions.dart';

/// Generates the fee receipt as a PDF on the phone, shows it, and lets staff print it, share it, or
/// send it straight to a parent's WhatsApp chat.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({
    super.key,
    required this.payment,
    this.student,
    this.remainingBalance,
    this.dueDate,
    this.allowSendToParent = true,
  });
  final FeePayment payment;

  /// When the caller already has the student (e.g. the parent app), the staff-only fee lookup is skipped.
  final Student? student;
  final double? remainingBalance;
  final DateTime? dueDate;

  /// Staff can push the PDF to a parent's WhatsApp; a parent just shares / saves their own copy.
  final bool allowSendToParent;

  static Future<void> open(BuildContext context, FeePayment payment) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(payment: payment)));

  /// Parent view: no staff lookups, only Share / Print.
  static Future<void> openForParent(BuildContext context, FeePayment payment, {required Student student, required double balance, DateTime? dueDate}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReceiptScreen(payment: payment, student: student, remainingBalance: balance, dueDate: dueDate, allowSendToParent: false),
      ));

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _pdf;
  FeePayInfo? _info;
  bool _sending = false;

  FeePayment get _p => widget.payment;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Student contact + current dues enrich the receipt; if they can't be fetched the receipt itself
      // is still valid, so that failure is not fatal.
      FeePayInfo? info;
      if (widget.student == null && _p.studentId != null) {
        try {
          info = await FeesService().getPayInfo(_p.studentId!);
        } on ApiException {
          info = null;
        }
      }
      final bytes = await ReceiptPdf.build(
        payment: _p,
        student: widget.student ?? info?.student,
        remainingBalance: widget.remainingBalance ?? info?.balance ?? 0,
        dueDate: _p.dueDate ?? widget.dueDate ?? info?.dueDate,
      );
      if (mounted) setState(() { _info = info; _pdf = bytes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not generate the receipt. Please try again.'; _loading = false; });
    }
  }

  List<ContactNumber> get _contacts {
    final s = _info?.student;
    return buildContacts(father: s?.fatherPhone, mother: s?.motherPhone, student: s?.phone);
  }

  Future<void> _sendToParent() async {
    if (_pdf == null || _sending) return;
    setState(() => _sending = true);
    try {
      final name = _p.studentName ?? _info?.student.fullName ?? 'Student';
      final contact = await ContactActions.pickContact(context, name, _contacts, 'Send receipt to');
      if (contact == null || !mounted) return;
      // WhatsApp ignores a caption when a chat is targeted directly, so the template text is used for the
      // share-sheet fallback; no need to ask which template.
      final template = (await MessageTemplateService().forCategory('Receipt')).first;
      final message = template.render(ContactActions.baseVars(
        student: name,
        className: _p.className,
        medium: _p.sectionName,
        extra: {'receipt': _p.receiptNo, 'amount': ContactActions.money(_p.netAmount)},
      ));
      final file = await ReceiptShare.save(_pdf!, _p.receiptNo);
      await ReceiptShare.sendToWhatsApp(file: file, whatsappNumber: contact.whatsappNumber, message: message);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not send the receipt. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _share() async {
    if (_pdf == null) return;
    try {
      final file = await ReceiptShare.save(_pdf!, _p.receiptNo);
      await ReceiptShare.share(file: file, message: 'Fee receipt ${_p.receiptNo} — RK Classes');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not share the receipt.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt ${_p.receiptNo}'),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: _pdf == null ? null : () => Printing.layoutPdf(name: 'Receipt_${_p.receiptNo}.pdf', onLayout: (_) async => _pdf!),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _generate)
              : Column(
                  children: [
                    Expanded(
                      child: PdfPreview(
                        build: (_) => _pdf!,
                        useActions: false,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        canDebug: false,
                        scrollViewDecoration: const BoxDecoration(color: AppColors.background),
                      ),
                    ),
                    _bottomBar(),
                  ],
                ),
    );
  }

  Widget _bottomBar() {
    final canSend = widget.allowSendToParent && _contacts.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (widget.allowSendToParent) Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: canSend && !_sending ? _sendToParent : null,
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Send to Parent'),
                  style: FilledButton.styleFrom(backgroundColor: whatsappGreen, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)),
                ),
              ),
              if (widget.allowSendToParent) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text(widget.allowSendToParent ? 'Share' : 'Share / Save PDF'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                ),
              ),
            ],
          ),
          if (widget.allowSendToParent && !canSend)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('No valid parent phone number saved — use Share instead.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}
