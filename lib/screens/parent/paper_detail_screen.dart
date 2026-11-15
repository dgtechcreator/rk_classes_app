import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/papers.dart';
import '../../theme/app_theme.dart';

/// One paper: the child's score in a circle, then the Top 5 of that paper (1st gold, 2nd silver, 3rd bronze,
/// 4th and 5th plain). Same numbers as the web parent portal's paper view.
class PaperDetailScreen extends StatelessWidget {
  const PaperDetailScreen({super.key, required this.paper});
  final ExamPaper paper;

  static const _gold = Color(0xFFF59E0B);
  static const _silver = Color(0xFF94A3B8);
  static const _bronze = Color(0xFFEA580C);

  @override
  Widget build(BuildContext context) {
    final p = paper;
    final date = p.testDate == null ? 'No date' : DateFormat('d MMM yyyy').format(p.testDate!);
    final myLine = p.myAbsent
        ? 'Absent in this paper'
        : !p.hasMarks
            ? 'Marks not entered yet'
            : '${_num(p.myMarks!)} out of ${p.maxMarks} (${p.myPercentage?.toStringAsFixed(1) ?? '0'}%)'
                '${p.myRank != null ? ' · Rank #${p.myRank} of ${p.classSize}' : ''}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(p.examName, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.card),
            child: Row(
              children: [
                _circle(),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.examName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('${p.subjectName} · $date', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                      const SizedBox(height: 10),
                      Text(myLine, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('🏆  Top 5 in this paper', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          if (p.top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No marks entered for this paper yet.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            for (final t in p.top) _topRow(t, p.maxMarks),
        ],
      ),
    );
  }

  Widget _circle() {
    final p = paper;
    const size = 124.0;
    if (p.myAbsent || !p.hasMarks) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceAlt),
        child: Text(p.myAbsent ? 'Absent' : 'Not entered', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
      );
    }
    final pct = (p.myPercentage ?? 0).clamp(0, 100) / 100;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: pct.toDouble(),
              strokeWidth: 10,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: _num(p.myMarks!), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                TextSpan(text: '/${p.maxMarks}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ])),
              Text('${(p.myPercentage ?? 0).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topRow(PaperTop t, int max) {
    // Medal colours for ranks 1-3; 4th and 5th use the plain card.
    final medal = t.rank == 1 ? _gold : t.rank == 2 ? _silver : t.rank == 3 ? _bronze : null;
    final bg = t.rank == 1
        ? const Color(0xFFFEF3C7)
        : t.rank == 2
            ? const Color(0xFFF1F5F9)
            : t.rank == 3
                ? const Color(0xFFFFEDD5)
                : AppColors.surface;
    final label = t.rank == 1 ? '🥇' : t.rank == 2 ? '🥈' : t.rank == 3 ? '🥉' : '#${t.rank}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: medal ?? AppColors.border, width: medal != null ? 1.5 : 1),
        boxShadow: t.isMe ? [const BoxShadow(color: AppColors.success, blurRadius: 0, spreadRadius: 0, offset: Offset(-4, 0))] : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: t.rank <= 3 ? 18 : 14, color: medal ?? AppColors.textMuted)),
          ),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: t.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (t.isMe)
                const TextSpan(text: '  (your child)', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
          ),
          Text(t.marks == null ? '—' : '${_num(t.marks!)}/$max', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  /// 10 → "10", 15.5 → "15.5"
  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
