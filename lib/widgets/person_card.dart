import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'profile_avatar.dart';

/// One row of a people list (students, faculty...): avatar, name, a small grey line and coloured pills.
/// Same look as the Users list so every list page lines up.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.name,
    required this.onTap,
    this.photoPath,
    this.line,
    this.pills = const [],
    this.trailing,
  });

  final String name;
  final String? photoPath;
  final String? line;
  final List<PersonPill> pills;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                ProfileAvatar(name: name, photoPath: photoPath, size: 44, background: AppColors.primarySoft, foreground: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.2)),
                      if ((line ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(line!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                      if (pills.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(spacing: 6, runSpacing: 4, children: pills),
                      ],
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PersonPill extends StatelessWidget {
  const PersonPill(this.text, this.color, {super.key});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}
