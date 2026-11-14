import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/parent_data_controller.dart';
import '../../core/session.dart';
import '../../services/parent_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/profile_widgets.dart';
import '../../core/login_role.dart';
import '../../services/photo_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../auth/login_screen.dart';
import '../../widgets/fingerprint_tile.dart';
import '../security/login_activity_screen.dart';
import 'my_details_card.dart';

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
      if (!mounted) return;
      await withLoader(context, () => _service.sendContactMessage(name: _name.text.trim(), email: _email.text.trim(), subject: _subject.text.trim(), message: _message.text.trim()));
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
    final ctrl = context.watch<ParentDataController>();
    final child = ctrl.selected;
    final role = portalRoleLabel(session.phone, ctrl.children);
    final studentLogin = isStudentLogin(session.phone, ctrl.children);
    // a student who signed in with his own number sees his own name, not a "parent"
    final displayName = studentLogin && child != null ? child.fullName : (session.parentName.isEmpty ? (child?.displayName ?? 'Parent') : session.parentName);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ProfileBanner(
            title: 'My Account',
            name: displayName,
            roleLabel: role,
            roleIcon: role == 'Student' ? Icons.school_rounded : Icons.family_restroom_rounded,
            chips: [if (session.phone.isNotEmpty) session.phone],
            hint: child == null ? null : (studentLogin ? 'Tap the photo to view it - tap the camera to change it' : "Student's photo - tap it to view, tap the camera to change"),
            avatar: child == null
                ? ProfileAvatar(name: displayName, size: 112, border: Border.all(color: Colors.white, width: 3))
                : EditableAvatar(
                    name: child.fullName,
                    photoPath: child.profilePicPath,
                    owner: PhotoOwner.child,
                    id: child.studentId,
                    size: 112,
                    border: Border.all(color: Colors.white, width: 3),
                    onChanged: (_) => ctrl.load(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: ProfileFact(icon: Icons.verified_user_rounded, color: const Color(0xFF7C3AED), value: role, label: 'Login type')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: studentLogin && child != null
                        ? ProfileFact(icon: Icons.class_rounded, color: AppColors.info, value: (child.className ?? '-'), label: 'Class')
                        : ProfileFact(icon: Icons.groups_rounded, color: AppColors.info, value: '${ctrl.children.length}', label: ctrl.children.length == 1 ? 'Student' : 'Students'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (_, snap) => ProfileFact(icon: Icons.system_update_rounded, color: AppColors.success, value: snap.data?.version ?? '-', label: 'App version'),
                    ),
                  ),
                ]),
                if (child != null) ...[
                  const SizedBox(height: 12),
                  MyDetailsCard(student: child),
                ],
                if (ctrl.shows('contact')) ...[
                  const SizedBox(height: 12),
                  ProfileCard(
                    title: 'Contact Us',
                    icon: Icons.support_agent_rounded,
                    children: [
                      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Your Name')),
                      const SizedBox(height: 12),
                      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
                      const SizedBox(height: 12),
                      TextField(controller: _message, maxLines: 4, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_sending ? 'Sending...' : 'Send Message'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                ProfileCard(
                  title: 'Security',
                  icon: Icons.lock_rounded,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginActivityScreen())),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          ProfileIconBox(Icons.devices_rounded, AppColors.info),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('My login activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: profileInk)),
                              SizedBox(height: 2),
                              Text('Phones signed in to this account', style: TextStyle(fontSize: 12, color: profileMuted)),
                            ]),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ]),
                      ),
                    ),
                    const FingerprintTile(kind: 'parent', flush: true),
                  ],
                ),
                const SizedBox(height: 14),
                ProfileLogoutButton(onPressed: _confirmLogout),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
