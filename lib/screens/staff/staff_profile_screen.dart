import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/realtime_notification_service.dart';
import '../../core/session.dart';
import '../../services/photo_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/profile_widgets.dart';
import '../auth/login_screen.dart';
import '../../widgets/fingerprint_tile.dart';
import '../security/login_activity_screen.dart';
import 'staff_modules_screen.dart';

/// A real account tab: a blue banner with a big photo, name and role, three quick facts, then the account, security and
/// access cards and the sign-out button.
class StaffProfileScreen extends StatelessWidget {
  const StaffProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<RealtimeNotificationService>().disconnect();
    if (!context.mounted) return;
    await context.read<Session>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final grantedGroups = groupOrder.where((g) {
      final mods = allModules.where((m) => m.group == g).toList();
      return mods.any((m) => m.permKey == null || session.hasPerm(m.permKey!));
    }).toList();
    final moduleCount = allModules.where((m) => m.isVisibleTo(session)).length;
    final shownName = session.displayName.isEmpty ? session.fullName : session.displayName;
    final role = session.roleName.isEmpty ? 'Staff' : session.roleName;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ProfileBanner(
            title: 'My Profile',
            name: shownName,
            roleLabel: role,
            roleIcon: session.isAdmin ? Icons.shield_rounded : Icons.verified_user_rounded,
            chips: [if (session.username.isNotEmpty) '@${session.username}'],
            hint: 'Tap the photo to view it · tap the camera to change it',
            avatar: EditableAvatar(
              name: session.fullName,
              photoPath: session.profilePicPath,
              owner: PhotoOwner.user,
              id: session.userId,
              size: 112,
              border: Border.all(color: Colors.white, width: 3),
              onChanged: (path) => session.setProfilePic(path),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: ProfileFact(icon: Icons.badge_rounded, color: const Color(0xFF7C3AED), value: role, label: 'Role')),
                  const SizedBox(width: 8),
                  Expanded(child: ProfileFact(icon: Icons.apps_rounded, color: AppColors.info, value: '$moduleCount', label: 'Modules')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (_, snap) => ProfileFact(icon: Icons.system_update_rounded, color: AppColors.success, value: snap.data?.version ?? '-', label: 'App version'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                ProfileCard(
                  title: 'Account',
                  icon: Icons.person_rounded,
                  children: [
                    ProfileInfoRow(icon: Icons.badge_outlined, label: 'Full name', value: session.fullName.isEmpty ? '-' : session.fullName),
                    const ProfileDivider(),
                    ProfileInfoRow(icon: Icons.alternate_email_rounded, label: 'Username', value: session.username.isEmpty ? '-' : session.username),
                    const ProfileDivider(),
                    ProfileInfoRow(icon: Icons.verified_user_outlined, label: 'Role', value: role),
                  ],
                ),
                const SizedBox(height: 12),
                ProfileCard(
                  title: 'Security',
                  icon: Icons.lock_rounded,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginActivityScreen())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          const ProfileIconBox(Icons.devices_rounded, AppColors.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(session.isAdmin ? 'Login activity' : 'My login activity', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: profileInk)),
                              const SizedBox(height: 2),
                              Text(session.isAdmin ? 'Phones and browsers everyone signed in from' : 'Phones and browsers signed in to your account', style: const TextStyle(fontSize: 12, color: profileMuted)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ]),
                      ),
                    ),
                    const FingerprintTile(kind: 'staff', flush: true),
                  ],
                ),
                const SizedBox(height: 12),
                ProfileCard(
                  title: 'Your access',
                  icon: Icons.key_rounded,
                  children: [
                    if (grantedGroups.isEmpty)
                      const Text('No module access granted yet.', style: TextStyle(color: profileMuted, fontSize: 13))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: grantedGroups.map((g) {
                          final c = groupColor(g);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppRadius.pill)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(groupIcon(g), size: 14, color: c),
                                const SizedBox(width: 6),
                                Text(g, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ProfileLogoutButton(onPressed: () => _confirmLogout(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
