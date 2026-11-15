import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Class and Roll No pills under a child's name on the parent / student home card.
/// Stacked one per line, each cut with "..." instead of overflowing, so a long class name
/// (e.g. "10th English Morning") never pushes the roll pill out of the card.
class ChildInfoPills extends StatelessWidget {
  const ChildInfoPills({super.key, required this.classLabel, this.rollNo});
  final String classLabel;
  final String? rollNo;

  @override
  Widget build(BuildContext context) {
    final roll = (rollNo ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Class / stream / medium / batch gets up to two lines so nothing is cut; the roll is its own line below.
        if (classLabel.trim().isNotEmpty) _pill(classLabel.trim(), AppColors.infoSoft, AppColors.info, maxLines: 2),
        if (classLabel.trim().isNotEmpty) const SizedBox(height: 4),
        _pill('Roll No ${roll.isEmpty ? '—' : roll}', AppColors.primarySoft, AppColors.primary),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg, {int maxLines = 1}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
}
