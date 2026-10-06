import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/contact_launcher.dart';
import '../models/contact_number.dart';
import '../models/message_template.dart';
import '../services/message_template_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

const whatsappGreen = Color(0xFF25D366);

/// Shared "Call" / "WhatsApp" behaviour for any screen that lists a student's parents — one number is
/// used directly, several (father / mother / student) are offered in a picker first, and WhatsApp texts
/// come from the Message Template master (see [MessageTemplateService.forCategory]).
class ContactActions {
  /// Standard placeholders every template can use. Pass fee fields via [extra].
  static Map<String, String> baseVars({
    required String student,
    String? className,
    String? medium,
    Map<String, String> extra = const {},
  }) =>
      {
        'student': student,
        'class': (className ?? '').trim(),
        'medium': (medium ?? '').trim(),
        'date': DateFormat('dd-MM-yyyy').format(DateTime.now()),
        'school': 'RK Classes',
        ...extra,
      };

  static String money(double v) =>
      NumberFormat(v == v.roundToDouble() ? '#,##,##0' : '#,##,##0.00', 'en_IN').format(v);

  static Future<void> call(BuildContext context, {required String name, required List<ContactNumber> contacts}) async {
    final contact = await pickContact(context, name, contacts, 'Call');
    if (contact == null || !context.mounted) return;
    final ok = await ContactLauncher.call(contact.number);
    if (!ok && context.mounted) showSnack(context, 'Could not open the dialer.', isError: true);
  }

  static Future<void> whatsapp(
    BuildContext context, {
    required String name,
    required List<ContactNumber> contacts,
    required String category,
    required Map<String, String> vars,
  }) async {
    final contact = await pickContact(context, name, contacts, 'WhatsApp');
    if (contact == null || !context.mounted) return;
    final templates = await MessageTemplateService().forCategory(category);
    if (!context.mounted) return;
    final template = await pickTemplate(context, templates);
    if (template == null || !context.mounted) return;
    final ok = await ContactLauncher.whatsapp(contact.whatsappNumber, template.render(vars));
    if (!ok && context.mounted) showSnack(context, 'Could not open WhatsApp. Is it installed?', isError: true);
  }

  static Future<ContactNumber?> pickContact(BuildContext context, String name, List<ContactNumber> contacts, String action) async {
    if (contacts.isEmpty) {
      showSnack(context, 'No valid phone number saved for $name.', isError: true);
      return null;
    }
    if (contacts.length == 1) return contacts.first;
    return showModalBottomSheet<ContactNumber>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('$action $name', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            for (final c in contacts)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(c.number),
                subtitle: Text(c.label),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
  }

  static Future<MessageTemplate?> pickTemplate(BuildContext context, List<MessageTemplate> templates) async {
    if (templates.length == 1) return templates.first;
    return showModalBottomSheet<MessageTemplate>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Choose message', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in templates)
                      ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(t.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(ctx, t),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
