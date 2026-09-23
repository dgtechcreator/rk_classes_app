import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/realtime_notification_service.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'staff_modules_screen.dart';

/// A real account tab — matches the "Profile" pattern nearly every top consumer/education app has
/// (avatar, role, quick facts, settings-shaped rows, sign-out at the bottom) instead of burying
/// logout as a stray icon in the dashboard app bar.
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
    final initial = session.fullName.trim().isNotEmpty ? session.fullName.trim()[0].toUpperCase() : '?';
    final grantedGroups = groupOrder.where((g) {
      final mods = allModules.where((m) => m.group == g).toList();
      return mods.any((m) => m.permKey == null || session.hasPerm(m.permKey!));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(gradient: AppGradients.primarySheen, shape: BoxShape.circle).copyWith(boxShadow: AppShadows.header),
                      alignment: Alignment.center,
                      child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 14),
                    Text(session.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.isAdmin ? AppColors.violetSoft : AppColors.infoSoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        session.roleName.isEmpty ? 'Staff' : session.roleName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: session.isAdmin ? AppColors.violet : AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _sectionCard([
                    _infoRow(Icons.person_outline_rounded, 'Username', session.username),
                    _divider(),
                    _infoRow(Icons.badge_outlined, 'Role', session.roleName.isEmpty ? '-' : session.roleName),
                  ]),
                  const SizedBox(height: 18),
                  const _Label('Access'),
                  const SizedBox(height: 10),
                  _sectionCard([
                    if (grantedGroups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('No module access granted yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      )
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
                  ]),
                  const SizedBox(height: 18),
                  const _Label('App'),
                  const SizedBox(height: 10),
                  _sectionCard([
                    _infoRow(Icons.info_outline_rounded, 'Version', '1.0.0'),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                      label: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1));

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary))),
        Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary));
}
