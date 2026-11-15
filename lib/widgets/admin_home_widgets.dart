import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dashboard.dart';
import '../theme/app_theme.dart';
import 'rk_header.dart';

/// Building blocks of the Home screens (admin / staff / teacher). Compact on purpose - small tiles, thin cards - so more of
/// the Home fits on one screen. The header is the shared [RkHomeHeader].

final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

/// "2026-2027" -> "2026–27" (what the header shows).
String shortYearLabel(String name) {
  final m = RegExp(r'^\s*(\d{4})\s*[-–]\s*(\d{4})\s*$').firstMatch(name);
  if (m == null) return name.trim();
  return '${m.group(1)}–${m.group(2)!.substring(2)}';
}

// ───────────────────────────── header ─────────────────────────────

/// Kept under its old name so every screen that used it gets the new header.
class AdminHomeHeader extends StatelessWidget {
  const AdminHomeHeader({
    super.key,
    required this.name,
    required this.roleLabel,
    this.photoPath,
    this.unread = 0,
    this.onBell,
    this.onAvatarTap,
    this.isAdmin = false,
    this.sideNote,
  });

  final String name;
  final String roleLabel;
  final String? photoPath;
  final int unread;
  final VoidCallback? onBell;
  final VoidCallback? onAvatarTap;
  final bool isAdmin;
  final String? sideNote;

  @override
  Widget build(BuildContext context) =>
      RkHomeHeader(name: name, roleLabel: roleLabel, photoPath: photoPath, unread: unread, onBell: onBell, onAvatarTap: onAvatarTap, isAdmin: isAdmin, sideNote: sideNote);
}

// ───────────────────────────── sections ─────────────────────────────

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.1, color: Color(0xFF0F1B3D))),
          if (trailing != null) ...[const SizedBox(width: 12), Expanded(child: trailing!)] else const Spacer(),
        ],
      ),
    );
  }
}

class AdminYearPill extends StatelessWidget {
  const AdminYearPill({super.key, required this.label, this.icon = Icons.calendar_today_outlined});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))),
      ],
    );
  }
}

BoxDecoration _cardDecoration([double radius = 16]) => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [BoxShadow(color: const Color(0xFF192D82).withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
    );

const _ink = Color(0xFF0F1B3D);
const _muted = Color(0xFF5B6478);

// ───────────────────────────── today's attendance ─────────────────────────────

/// One thin card: how many are present / absent today, with a split bar. Each number opens its list.
class AdminAttendanceStrip extends StatelessWidget {
  const AdminAttendanceStrip({super.key, required this.present, required this.absent, required this.total, this.onPresent, this.onAbsent, this.onTotal});
  final int present, absent, total;
  final VoidCallback? onPresent, onAbsent, onTotal;

  @override
  Widget build(BuildContext context) {
    final t = total <= 0 ? 1 : total;
    final presentPct = (present * 100 / t).clamp(0, 100).toDouble();
    final absentPct = (absent * 100 / t).clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _cardDecoration(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text("Today's Attendance", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFD8F5E8), borderRadius: BorderRadius.circular(999)),
              child: Text('${presentPct.round()}% present', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0B6B45))),
            ),
          ]),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 7,
              child: Row(children: [
                Expanded(flex: (presentPct * 10).round().clamp(0, 1000), child: Container(color: const Color(0xFF12B76A))),
                if (presentPct > 0 && absentPct > 0) const SizedBox(width: 2),
                Expanded(flex: (absentPct * 10).round().clamp(0, 1000), child: Container(color: const Color(0xFFF04438))),
                Expanded(flex: ((100 - presentPct - absentPct) * 10).round().clamp(0, 1000), child: Container(color: const Color(0xFFE6EAF4))),
              ]),
            ),
          ),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: _num(const Color(0xFF12B76A), '$present', 'Present', onPresent)),
            Expanded(child: _num(const Color(0xFFF04438), '$absent', 'Absent', onAbsent)),
            Expanded(child: _num(const Color(0xFF2447D6), '$total', 'Total', onTotal)),
          ]),
        ],
      ),
    );
  }

  Widget _num(Color dot, String v, String label, VoidCallback? onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink, height: 1.1)),
            const SizedBox(width: 5),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted))),
          ]),
        ),
      );
}

// ───────────────────────────── stat tiles ─────────────────────────────

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({super.key, required this.icon, required this.color, required this.value, required this.label, this.onTap});
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: _cardDecoration(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.1, color: _ink))),
                      const SizedBox(height: 2),
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted, height: 1.15))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two columns on a phone, three on a tablet; every tile keeps the same (small) height so rows line up.
class AdminStatGrid extends StatelessWidget {
  const AdminStatGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 3 : 2;
      const extent = 52.0;
      return GridView.count(
        // Not primary: a primary grid adds the status-bar inset as top padding, which showed as a big empty gap.
        primary: false,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: (c.maxWidth - (cols - 1) * 8) / cols / extent,
        children: children,
      );
    });
  }
}

// ───────────────────────────── fee collection ─────────────────────────────

class AdminFeeCard extends StatelessWidget {
  const AdminFeeCard({super.key, required this.stats, this.periodLabel = 'This Year', this.onTap});
  final DashboardStats stats;
  final String periodLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final net = stats.totalFeesOverall - stats.totalDiscountOverall;   // what will really come in (discount is only information)
    final pct = net <= 0 ? 0.0 : (stats.totalCollectedOverall / net).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF14267F), Color(0xFF1E3AB8)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF192D82).withValues(alpha: 0.22), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(child: Text('Fee Collection (Overall)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                    child: Text(periodLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Text('${(pct * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Stack(children: [
                        Container(height: 9, color: Colors.white.withValues(alpha: 0.2)),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(height: 9, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF34D399), Color(0xFFF5B93A)]))),
                        ),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.2)))),
                  child: Row(children: [
                    Expanded(child: _figure('Total', net, Colors.white, Colors.white)),
                    Expanded(child: _figure('Collected', stats.totalCollectedOverall, const Color(0xFF34D399), Colors.white)),
                    Expanded(child: _figure('Balance', stats.balanceOverall, const Color(0xFFFF8A80), RkHeaderColors.gold)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _figure(String label, double v, Color dot, Color valueColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 10.5, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(_money.format(v), maxLines: 1, style: TextStyle(color: valueColor, fontSize: 12.5, fontWeight: FontWeight.w800))),
        ],
      );
}

// ───────────────────────────── students by class ─────────────────────────────

class AdminClassCard extends StatelessWidget {
  const AdminClassCard({super.key, required this.stats, this.onTotalTap});
  final DashboardStats stats;
  final VoidCallback? onTotalTap;

  @override
  Widget build(BuildContext context) {
    final total = stats.classStrengths.fold<int>(0, (a, b) => a + b.studentCount);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      decoration: _cardDecoration(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Students by Class', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink))),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: onTotalTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
                  decoration: BoxDecoration(color: const Color(0xFFE4EAFF), borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Total $total', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1B3BB5))),
                    const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF1B3BB5)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < stats.classStrengths.length; i++) _ClassRow(c: stats.classStrengths[i], first: i == 0),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.c, required this.first});
  final ClassStrength c;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: Color(0xFFE9EDF6)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFF0F3FF), borderRadius: BorderRadius.circular(11)),
            child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Text(c.className.trim(), maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1B3BB5))))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 5,
              children: c.sections.isEmpty ? [_chip('Students', c.studentCount, const Color(0xFFE4EAFF), const Color(0xFF1B3BB5))] : [for (final s in c.sections) _medium(s)],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 30, child: Text('${c.studentCount}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink))),
        ],
      ),
    );
  }

  Widget _medium(ClassSectionStrength s) {
    final (bg, fg) = _mediumColors(s.sectionName);
    final pill = _chip(_mediumLabel(s.sectionName), s.studentCount, bg, fg);
    if (s.batches.isEmpty) return pill;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pill,
        Padding(
          padding: const EdgeInsets.only(left: 2, top: 2),
          child: Text(s.batches.map((b) => '${b.batchName} ${b.studentCount}').join(' · '), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _muted, height: 1.25)),
        ),
      ],
    );
  }

  Widget _chip(String label, int count, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$label ', style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
        TextSpan(text: '$count', style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w800)),
      ])),
    );
  }

  /// Sections double as Medium (English / Hindi / Semi-English) and, for 11th-12th, as streams (Commerce / Science).
  static String _mediumLabel(String section) {
    final name = section.trim().replaceAll(RegExp(r'\s*-\s*'), '-');
    return name.isEmpty ? 'Other' : name;
  }

  static (Color, Color) _mediumColors(String section) {
    final l = section.toLowerCase();
    if (l.contains('semi')) return (const Color(0xFFD8F5E8), const Color(0xFF0B6B45));
    if (l.contains('english')) return (const Color(0xFFE4EAFF), const Color(0xFF1B3BB5));
    if (l.contains('hindi')) return (const Color(0xFFFFEBD2), const Color(0xFF9A4A00));
    if (l.contains('science')) return (const Color(0xFFD5F3F6), const Color(0xFF0A6672));
    return (const Color(0xFFEBE2FF), const Color(0xFF5B2BC4));
  }
}

// ───────────────────────────── quick actions ─────────────────────────────

class AdminQuickTile extends StatelessWidget {
  const AdminQuickTile({super.key, required this.icon, required this.label, required this.color, required this.onTap, this.flat = false});
  /// Inside a card: a soft tint instead of its own white card.
  final bool flat;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: flat ? BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16)) : _cardDecoration(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 9),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(label.trim(), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2, color: _ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three small tiles in a row (4 on a tablet).
class AdminQuickGrid extends StatelessWidget {
  const AdminQuickGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 4 : 3;
      const gap = 8.0, extent = 82.0;
      return GridView.count(
        // Not primary: a primary grid adds the status-bar inset as top padding, which showed as a big empty gap.
        primary: false,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: math.max(0.9, (c.maxWidth - (cols - 1) * gap) / cols / extent),
        children: children,
      );
    });
  }
}

/// A white card with a title (and an optional action on the right) around [child]: the shape every block on the Home uses.
class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.title, required this.child, this.icon, this.action, this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12)});
  final String title;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: _cardDecoration(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Row(children: [
              if (icon != null) ...[Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 6)],
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink))),
              if (action != null) action!,
            ]),
          ),
          child,
        ],
      ),
    );
  }
}
