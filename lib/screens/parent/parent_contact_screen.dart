import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/parent_service.dart';
import '../../widgets/common.dart';

class ParentContactScreen extends StatefulWidget {
  const ParentContactScreen({super.key});

  @override
  State<ParentContactScreen> createState() => _ParentContactScreenState();
}

class _ParentContactScreenState extends State<ParentContactScreen> {
  final _service = ParentService();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    _name.text = session.parentName;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if ([_name, _email, _subject, _message].any((c) => c.text.trim().isEmpty)) {
      showSnack(context, 'Please fill in all fields.', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await _service.sendContactMessage(name: _name.text.trim(), email: _email.text.trim(), subject: _subject.text.trim(), message: _message.text.trim());
      if (!mounted) return;
      showSnack(context, "Message sent! We'll get back to you soon.");
      _subject.clear();
      _message.clear();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Your Name')),
            const SizedBox(height: 14),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 14),
            TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 14),
            TextField(controller: _message, maxLines: 5, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              child: _sending ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }
}
