import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/parent_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';

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

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<Session>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: GreetingHeader(greeting: 'Profile', name: session.parentName.isEmpty ? 'Parent' : session.parentName, subtitle: session.phone, leadingIcon: Icons.person),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 14),
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
                              child: _sending
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Send Message'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(Icons.logout, color: AppColors.danger),
                        label: const Text('Logout', style: TextStyle(color: AppColors.danger)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
