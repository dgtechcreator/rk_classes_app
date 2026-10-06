import '../core/api_client.dart';
import '../models/message_template.dart';

class MessageTemplateService {
  final _client = ApiClient.instance;

  Future<List<MessageTemplate>> getAll() async {
    final res = await _client.get('/api/masters/message-templates');
    return (res.data as List).map((e) => MessageTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> save({required int id, required String category, required String title, required String body}) =>
      _client.post('/api/masters/message-templates/save', data: {
        'templateId': id, 'category': category, 'title': title, 'body': body, 'isActive': true,
      });

  Future<void> delete(int id) => _client.post('/api/masters/message-templates/$id/delete');

  /// Templates for one category. Falls back to a built-in default when the server has none (or the
  /// templates endpoint isn't deployed yet), so the WhatsApp button always has something to send.
  Future<List<MessageTemplate>> forCategory(String category) async {
    try {
      final all = await getAll();
      final list = all.where((t) => t.category.toLowerCase() == category.toLowerCase()).toList();
      if (list.isNotEmpty) return list;
    } on ApiException {
      // fall through to default
    }
    return [_defaults[category] ?? _defaults['General']!];
  }

  static final _defaults = {
    'Absent': MessageTemplate(
      templateId: 0, category: 'Absent', title: 'Absent Alert',
      body: 'Dear Parent, {student} ({class}) was absent today ({date}). Please send the reason for absence. - {school}',
    ),
    'FeeReminder': MessageTemplate(
      templateId: 0, category: 'FeeReminder', title: 'Fee Reminder',
      body: 'Dear Parent, this is a gentle reminder regarding the fees of {student} ({class}). Total fees: Rs {total}, paid: Rs {paid}, balance due: Rs {balance}. Kindly clear the balance at the earliest. - {school}',
    ),
    'Receipt': MessageTemplate(
      templateId: 0, category: 'Receipt', title: 'Fee Receipt',
      body: 'Dear Parent, thank you. Please find attached the fee receipt {receipt} of Rs {amount} for {student} ({class}). - {school}',
    ),
    'General': MessageTemplate(
      templateId: 0, category: 'General', title: 'General Notice',
      body: 'Dear Parent, a message regarding {student} ({class}) from {school}.',
    ),
  };
}
