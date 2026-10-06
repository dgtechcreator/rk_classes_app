/// Message Template master row — the text behind the WhatsApp/SMS buttons (absent alert, fee reminder…).
class MessageTemplate {
  MessageTemplate({required this.templateId, required this.category, required this.title, required this.body});

  final int templateId;
  final String category;
  final String title;
  final String body;

  factory MessageTemplate.fromJson(Map<String, dynamic> j) => MessageTemplate(
        templateId: j['templateId'] is int ? j['templateId'] as int : int.tryParse('${j['templateId']}') ?? 0,
        category: (j['category'] ?? 'General').toString(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
      );

  /// Replaces `{student}`, `{class}`, … placeholders; unknown placeholders are left as typed.
  String render(Map<String, String> vars) =>
      body.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars[m.group(1)!.toLowerCase()] ?? m.group(0)!);
}

/// Categories a template can belong to — the Absent list only offers `Absent` templates, etc.
const messageCategories = ['Absent', 'FeeReminder', 'Receipt', 'General'];

String categoryLabel(String c) => c == 'FeeReminder' ? 'Fee Reminder' : c;

/// Placeholders the Masters form tells the admin about.
const templatePlaceholders = ['{student}', '{class}', '{medium}', '{date}', '{school}', '{total}', '{paid}', '{balance}', '{receipt}', '{amount}'];
