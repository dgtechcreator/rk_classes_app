import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Icon + color for a subject name, keyword-matched since subjects are free-text
/// (SchoolMS.Domain.Subject.SubjectName) rather than a fixed enum on the backend.
class SubjectVisual {
  const SubjectVisual(this.icon, this.color);
  final IconData icon;
  final Color color;
}

SubjectVisual subjectVisual(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.contains('math')) return const SubjectVisual(Icons.calculate_outlined, Color(0xFF2563EB));
  if (n.contains('phys')) return const SubjectVisual(Icons.bolt_outlined, Color(0xFF7C3AED));
  if (n.contains('chem')) return const SubjectVisual(Icons.science_outlined, Color(0xFF059669));
  if (n.contains('bio')) return const SubjectVisual(Icons.biotech_outlined, Color(0xFF0D9488));
  if (n.contains('geo')) return const SubjectVisual(Icons.public_outlined, Color(0xFF0891B2));
  if (n.contains('hist')) return const SubjectVisual(Icons.account_balance_outlined, Color(0xFFB45309));
  if (n.contains('comp') || n.contains(' it') || n.contains('computer')) {
    return const SubjectVisual(Icons.computer_outlined, Color(0xFF4338CA));
  }
  if (n.contains('art') || n.contains('draw')) return const SubjectVisual(Icons.palette_outlined, Color(0xFFDB2777));
  if (n.contains('sport') || n.contains('phy ed') || n.contains('game') || n.contains('yoga')) {
    return const SubjectVisual(Icons.sports_soccer_outlined, Color(0xFFEA580C));
  }
  if (n.contains('eng') || n.contains('lit') || n.contains('hindi') || n.contains('sanskrit') || n.contains('lang')) {
    return const SubjectVisual(Icons.menu_book_outlined, AppColors.primary);
  }
  return const SubjectVisual(Icons.book_outlined, AppColors.info);
}
