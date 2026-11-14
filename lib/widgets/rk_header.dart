import 'package:flutter/material.dart';

import 'profile_avatar.dart';

/// The one Home header of the app - the same blue header for the admin, staff, teachers, class representatives,
/// students and parents: the RK Classes logo + name, the bell, and a big "welcome" block with the person's photo, a large
/// name, the role and a side note (academic year / class). Colours follow the Home design.
class RkHeaderColors {
  static const Color c1 = Color(0xFF2D56E8);
  static const Color c2 = Color(0xFF1E3AB8);
  static const Color c3 = Color(0xFF14267F);
  static const Color gold = Color(0xFFF5B93A);
  static const Color goldSoft = Color(0xFFFFE08A);
  static const Color goldText = Color(0xFF4A3000);
}

class RkHomeHeader extends StatelessWidget {
  const RkHomeHeader({
    super.key,
    required this.name,
    this.roleLabel = '',
    this.greeting = 'Welcome back,',
    this.photoPath,
    this.unread = 0,
    this.onBell,
    this.onAvatarTap,
    this.isAdmin = false,
    this.sideNote,
    this.roleIcon,
  });

  final String name;
  final String roleLabel;
  final String greeting;
  final String? photoPath;
  final int unread;
  /// null = no bell (e.g. a parent whose notifications section is switched off).
  final VoidCallback? onBell;
  /// Default: a photo opens full screen.
  final VoidCallback? onAvatarTap;
  final bool isAdmin;
  /// Small chip next to the role: "AY 2026-27", the child's class ...
  final String? sideNote;
  final IconData? roleIcon;

  static const double avatarSize = 84;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final hasPhoto = (photoPath ?? '').isNotEmpty;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(14, top + 12, 14, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [RkHeaderColors.c1, RkHeaderColors.c2, RkHeaderColors.c3], stops: [0, 0.55, 1]),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _HeaderArtPainter())),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _logoBox(),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('RK Classes', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.1)),
                          SizedBox(height: 2),
                          Text('Since 2002 · If you Believe, You will achieve', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (onBell != null) _bell(),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onAvatarTap ?? (hasPhoto ? () => showPhotoPreview(context, name: name, photoPath: photoPath) : null),
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [RkHeaderColors.gold, RkHeaderColors.goldSoft]),
                            boxShadow: [BoxShadow(color: const Color(0xFF081250).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                          ),
                          child: hasPhoto
                              ? ProfileAvatar(name: name, photoPath: photoPath, size: avatarSize - 6, background: RkHeaderColors.c3, border: Border.all(color: Colors.white, width: 2.5))
                              : Container(
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: RkHeaderColors.c3, border: Border.all(color: Colors.white, width: 2.5)),
                                  alignment: Alignment.center,
                                  child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(greeting, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2)),
                            const SizedBox(height: 2),
                            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (roleLabel.isNotEmpty) _roleChip(),
                                if ((sideNote ?? '').isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                                    child: Text(sideNote!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: RkHeaderColors.gold, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roleIcon ?? (isAdmin ? Icons.shield_rounded : Icons.verified_user_rounded), size: 13, color: RkHeaderColors.goldText),
            const SizedBox(width: 4),
            Flexible(child: Text(roleLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RkHeaderColors.goldText, fontSize: 12, fontWeight: FontWeight.w800))),
          ],
        ),
      );

  Widget _logoBox() => Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: const Color(0xFF081250).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Image.asset('assets/images/rk_logo_icon.png', fit: BoxFit.contain),
      );

  Widget _bell() => Semantics(
        button: true,
        label: 'Notifications',
        child: GestureDetector(
          onTap: onBell,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                if (unread > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFFF3B3B), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 1.8)),
                      child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.1)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  static String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();   // one word: one letter ("Vivek" -> V, not VI)
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Soft decoration of the header: two faint white discs and a few dots.
class _HeaderArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // plain, calm blue: only two soft white discs (no gold glow / rings)
    canvas.drawCircle(Offset(w + 40, -30), 100, Paint()..color = Colors.white.withValues(alpha: 0.07));
    canvas.drawCircle(const Offset(-40, 140), 90, Paint()..color = Colors.white.withValues(alpha: 0.04));
    // a few faint dots
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(Offset(w * 0.46, 22), 1.6, dot);
    canvas.drawCircle(Offset(w * 0.86, 66), 1.6, dot);
    canvas.drawCircle(Offset(w * 0.24, 70), 1.3, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
