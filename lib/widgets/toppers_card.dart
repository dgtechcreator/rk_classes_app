import 'package:flutter/material.dart';

import '../models/toppers.dart';
import '../theme/app_theme.dart';

/// Top 5 card: gold / silver / bronze medals for ranks 1-3, the parent's own child highlighted, and a
/// footer with the child's rank when they are outside the top five.
class ToppersCard extends StatelessWidget {
  const ToppersCard({super.key, required this.title, this.subtitle, required this.section});
  final String title;
  final String? subtitle;
  final TopperSection section;

  static const _gold = Color(0xFFF59E0B);
  static const _silver = Color(0xFF94A3B8);
  static const _bronze = Color(0xFFB45309);

  Color _medal(int rank) => rank == 1 ? _gold : rank == 2 ? _silver : rank == 3 ? _bronze : AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: _gold, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 30),
              child: Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          if (section.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No marks recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            for (final t in section.top) _row(t),
          if (!section.isEmpty && !section.meInTop && section.myRank != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_circle_outlined, size: 18, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your child: rank #${section.myRank} of ${section.ranked}'
                      '${section.myPercentage != null ? ' (${section.myPercentage!.toStringAsFixed(1)}%)' : ''}',
                      style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(TopperRow t) {
    final medal = _medal(t.rank);
    final marks = '${_fmt(t.totalObtained)}/${_fmt(t.totalMax)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.isMe ? AppColors.successSoft : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: t.isMe ? AppColors.success.withValues(alpha: 0.5) : AppColors.borderNeutral),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: medal.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Text('${t.rank}', style: TextStyle(color: medal, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (t.isMe) const Text('Your child', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${t.percentage.toStringAsFixed(t.percentage == t.percentage.roundToDouble() ? 0 : 1)}%',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(marks, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
