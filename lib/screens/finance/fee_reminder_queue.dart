import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/contact_launcher.dart';
import '../../models/contact_number.dart';
import '../../models/finance.dart';
import '../../models/message_template.dart';
import '../../services/message_template_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/contact_actions.dart';

/// WhatsApp cannot send to many people at once from a phone (that needs the paid Business API), so this walks
/// through the due students one after another: pick the WhatsApp app and the message once, then each tap opens
/// the next parent's chat with the fee reminder already typed - staff only presses Send in WhatsApp and comes back.
Future<void> showFeeReminderQueue(BuildContext context, List<FinanceStudent> due) async {
  final students = due.where((s) => buildContacts(father: s.fatherPhone, mother: s.motherPhone, student: s.phone).isNotEmpty).toList();
  final noPhone = due.length - students.length;
  if (students.isEmpty) {
    showSnack(context, 'None of the due students has a valid phone number saved.', isError: true);
    return;
  }

  final templates = await MessageTemplateService().forCategory('FeeReminder');
  if (!context.mounted) return;
  final template = await ContactActions.pickTemplate(context, templates);
  if (template == null || !context.mounted) return;
  final app = await ContactActions.pickWhatsAppApp(context);
  if (app == null || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _QueueSheet(students: students, template: template, app: app, noPhone: noPhone),
  );
}

class _QueueSheet extends StatefulWidget {
  const _QueueSheet({required this.students, required this.template, required this.app, required this.noPhone});
  final List<FinanceStudent> students;
  final MessageTemplate template;
  final WhatsAppApp app;
  final int noPhone;

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  int _i = 0;
  int _opened = 0;
  bool _busy = false;

  FinanceStudent get _s => widget.students[_i];
  bool get _done => _i >= widget.students.length;
  List<ContactNumber> get _contacts => buildContacts(father: _s.fatherPhone, mother: _s.motherPhone, student: _s.phone);

  Map<String, String> _vars(FinanceStudent s) => ContactActions.baseVars(student: s.fullName, className: s.className, medium: s.sectionName, extra: {
        'total': ContactActions.money(s.totalFees - s.discount),
        'paid': ContactActions.money(s.collected),
        'balance': ContactActions.money(s.balance < 0 ? 0 : s.balance),
      });

  Future<void> _open() async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    final contact = _contacts.first;   // father first, then mother, then the student's own number
    final ok = await ContactLauncher.whatsapp(contact.whatsappNumber, widget.template.render(_vars(_s)), app: widget.app);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      showSnack(context, 'Could not open WhatsApp. Is it installed?', isError: true);
      return;
    }
    setState(() { _opened++; _i++; _busy = false; });
  }

  void _skip() => setState(() => _i++);

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final total = widget.students.length;
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_done ? 'All done' : 'WhatsApp reminder ${_i + 1} of $total',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: total == 0 ? 1 : _i / total, minHeight: 6, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 18),
          if (_done) ...[
            const Icon(Icons.check_circle, size: 48, color: AppColors.success),
            const SizedBox(height: 8),
            Text('WhatsApp opened for $_opened of $total students.${widget.noPhone > 0 ? '\n${widget.noPhone} more have no valid phone number.' : ''}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ] else ...[
            Text(_s.fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${_s.classLabel} · Due ${money.format(_s.balance)}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('To ${_contacts.first.label}: ${_contacts.first.number}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _open,
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Open WhatsApp & send'),
              style: FilledButton.styleFrom(backgroundColor: whatsappGreen, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 6),
            const Text('Press Send in WhatsApp, then come back here - the next student is ready.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _busy ? null : _skip, child: const Text('Skip'))),
                const SizedBox(width: 10),
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Stop'))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
