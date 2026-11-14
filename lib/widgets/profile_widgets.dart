import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'rk_header.dart';

/// Building blocks of the Profile tab (staff and parent): the blue banner with the big photo, the three quick facts and
/// the white cards with icon rows.

const profileInk = Color(0xFF0F1B3D);
const profileMuted = Color(0xFF5B6478);

BoxDecoration profileCardDecoration() => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: const Color(0xFF192D82).withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3))],
    );

/// Blue banner: [title], the [avatar] (already styled by the caller, e.g. an EditableAvatar) in a gold ring, the [name],
/// a gold [roleLabel] chip and optional extra white chips.
class ProfileBanner extends StatelessWidget {
  const ProfileBanner({super.key, required this.title, required this.avatar, required this.name, required this.roleLabel, this.roleIcon = Icons.verified_user_rounded, this.chips = const [], this.hint});
  final String title;
  final Widget avatar;
  final String name;
  final String roleLabel;
  final IconData roleIcon;
  final List<String> chips;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, top + 18, 16, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [RkHeaderColors.c1, RkHeaderColors.c2, RkHeaderColors.c3], stops: [0, 0.55, 1]),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(right: -50, top: -60, child: Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)))),
            Positioned(left: -60, bottom: -70, child: Container(width: 170, height: 170, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
            Column(
              children: [
                Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [RkHeaderColors.gold, RkHeaderColors.goldSoft]),
                    boxShadow: [BoxShadow(color: const Color(0xFF081250).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: avatar,
                ),
                const SizedBox(height: 14),
                Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15)),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: RkHeaderColors.gold, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(roleIcon, size: 14, color: RkHeaderColors.goldText),
                        const SizedBox(width: 5),
                        Text(roleLabel, style: const TextStyle(color: RkHeaderColors.goldText, fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    for (final c in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                        child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                if (hint != null) ...[
                  const SizedBox(height: 10),
                  Text(hint!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the three small tiles under the banner.
class ProfileFact extends StatelessWidget {
  const ProfileFact({super.key, required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: profileCardDecoration(),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 7),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: profileInk))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: profileMuted)),
        ],
      ),
    );
  }
}

/// White card with a small title row; [action] sits on the right of the title.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.title, required this.icon, required this.children, this.action});
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: profileCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 7),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: profileInk))),
            if (action != null) action!,
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class ProfileIconBox extends StatelessWidget {
  const ProfileIconBox(this.icon, this.color, {super.key});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 19, color: color),
      );
}

class ProfileDivider extends StatelessWidget {
  const ProfileDivider({super.key});
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(height: 1, color: Color(0xFFE9EDF6)));
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({super.key, required this.icon, required this.label, required this.value, this.warn = false});
  final IconData icon;
  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileIconBox(icon, warn ? AppColors.danger : AppColors.primary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 13.5, color: profileMuted)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: warn ? AppColors.danger : profileInk))),
      ],
    );
  }
}

/// Soft red logout button used at the bottom of every profile.
class ProfileLogoutButton extends StatelessWidget {
  const ProfileLogoutButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
        label: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF1F1),
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
