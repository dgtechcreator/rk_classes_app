import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dashboard.dart';
import '../theme/app_theme.dart';
import 'profile_avatar.dart';

/// Building blocks of the admin / staff Home screen. Every colour comes from [AppColors] / [AppGradients] (nothing is
/// hard-coded here except the semantic stat colours), so switching the brand colour later is a one-file change in
/// theme/app_theme.dart.

final _money = NumberFormat.currency(symbol: '₹');
final _moneyShort = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

/// Full "₹3,010,303.00" like the design; whole rupees only on very narrow phones so the figures stay readable.
NumberFormat _moneyFor(BuildContext context) => MediaQuery.of(context).size.width < 350 ? _moneyShort : _money;

/// "2026-2027" -> "2026–27" (what the header pill shows).
String shortYearLabel(String name) {
  final m = RegExp(r'^\s*(\d{4})\s*[-–]\s*(\d{4})\s*$').firstMatch(name);
  if (m == null) return name.trim();
  return '${m.group(1)}–${m.group(2)!.substring(2)}';
}

// ───────────────────────────── header ─────────────────────────────

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
  });

  final String name;
  final String roleLabel;
  final String? photoPath;
  final int unread;
  final VoidCallback? onBell;
  final VoidCallback? onAvatarTap;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    final showArt = width >= 360;
    final showTagline = width >= 392;
    // keep the name clear of the artwork / bell on the right
    final rightClear = showTagline ? 194.0 : (showArt ? 128.0 : 58.0);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, top + 14, 16, 22),
        decoration: BoxDecoration(gradient: AppGradients.primarySheen, boxShadow: AppShadows.header),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // soft decorative discs
            Positioned(top: -80, right: -50, child: _disc(190, 0.07)),
            Positioned(bottom: -70, left: -40, child: _disc(150, 0.05)),
            Positioned(top: 30, right: 120, child: _disc(60, 0.05)),
            Padding(
              padding: EdgeInsets.only(right: rightClear),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2)),
                      child: (photoPath ?? '').isNotEmpty
                          ? ProfileAvatar(name: name, photoPath: photoPath, size: 52)
                          : Container(
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
                              child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Welcome back,', maxLines: 1, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.1)),
                        ),
                        const SizedBox(height: 2),
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.15)),
                        if (roleLabel.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isAdmin) ...[
                                  const Icon(Icons.workspace_premium_rounded, size: 15, color: Color(0xFFFFD66B)),
                                  const SizedBox(width: 5),
                                ],
                                Flexible(
                                  child: Text(roleLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showArt)
              Positioned(
                right: showTagline ? 102 : 40,
                top: 0,
                bottom: 0,
                child: const Center(child: SizedBox(width: 80, height: 70, child: CustomPaint(painter: _CapAndBooksPainter()))),
              ),
            if (showTagline)
              Positioned(
                right: 2,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Empowering\nBrighter Futures',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, height: 1.25, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 6),
                    Container(width: 26, height: 3, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3))),
                  ],
                ),
              ),
            Positioned(
              top: -2,
              right: -2,
              child: _Bell(unread: unread, onTap: onBell),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _disc(double size, double alpha) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white.withValues(alpha: alpha), shape: BoxShape.circle));
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread, this.onTap});
  final int unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notifications',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
              if (unread > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.6)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small graduation cap resting on a stack of books, drawn with the theme's own colours.
class _CapAndBooksPainter extends CustomPainter {
  const _CapAndBooksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // books (bottom -> top)
    final books = [
      (0.00, 0.88, Colors.white.withValues(alpha: 0.30)),
      (0.05, 0.80, Colors.white.withValues(alpha: 0.42)),
      (0.02, 0.84, Colors.white.withValues(alpha: 0.55)),
    ];
    var y = h - 12;
    for (final b in books) {
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(w * b.$1, y - 11, w * b.$2, 12), const Radius.circular(3));
      canvas.drawRRect(rect.shift(const Offset(0, 3)), shadow);
      canvas.drawRRect(rect, Paint()..color = b.$3);
      // page edge
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(rect.left + 5, rect.top + 3, rect.width - 10, 6), const Radius.circular(2)),
        Paint()..color = Colors.white.withValues(alpha: 0.78),
      );
      y -= 11;
    }

    // cap
    final cx = w * 0.46, cy = y - 8;
    final dark = Color.lerp(AppColors.primaryDark, Colors.black, 0.35)!;
    final band = Path()
      ..moveTo(cx - w * 0.22, cy + 2)
      ..lineTo(cx - w * 0.22, cy + 15)
      ..quadraticBezierTo(cx, cy + 25, cx + w * 0.22, cy + 15)
      ..lineTo(cx + w * 0.22, cy + 2)
      ..close();
    canvas.drawPath(band.shift(const Offset(0, 3)), shadow);
    canvas.drawPath(band, Paint()..color = dark);
    final board = Path()
      ..moveTo(cx - w * 0.46, cy)
      ..lineTo(cx, cy - 17)
      ..lineTo(cx + w * 0.46, cy)
      ..lineTo(cx, cy + 14)
      ..close();
    canvas.drawPath(board.shift(const Offset(0, 3)), shadow);
    canvas.drawPath(board, Paint()..color = Color.lerp(dark, Colors.white, 0.10)!);
    // tassel
    final gold = Paint()..color = const Color(0xFFFFC857)..strokeWidth = 1.8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 1), Offset(cx + w * 0.34, cy + 2), gold);
    canvas.drawLine(Offset(cx + w * 0.34, cy + 2), Offset(cx + w * 0.34, cy + 16), gold);
    canvas.drawCircle(Offset(cx + w * 0.34, cy + 18), 3, Paint()..color = const Color(0xFFFFC857));
    canvas.drawCircle(Offset(cx, cy - 1), 2.2, Paint()..color = const Color(0xFFFFC857));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ───────────────────────────── sections ─────────────────────────────

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
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
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)))),
      ],
    );
  }
}

BoxDecoration _cardDecoration([double radius = 20]) => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: AppShadows.card,
    );

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
        decoration: _cardDecoration(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: LayoutBuilder(builder: (context, c) {
            final compact = c.maxWidth < 170;   // small phones: smaller icon, no arrow, so the numbers keep their size
            final box = compact ? 38.0 : 44.0;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: box,
                    height: box,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(compact ? 12 : 14)),
                    child: Icon(icon, color: color, size: compact ? 21 : 24),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.15)),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null && !compact) const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Two columns on a phone, three on a tablet; every card keeps the same height so rows line up.
class AdminStatGrid extends StatelessWidget {
  const AdminStatGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 3 : 2;
      // narrow phones: a little taller so the number never has to shrink
      final extent = c.maxWidth < 340 ? 66.0 : 70.0;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: (c.maxWidth - (cols - 1) * 12) / cols / extent,
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
    final pct = stats.totalFeesOverall <= 0 ? 0.0 : (stats.totalCollectedOverall / stats.totalFeesOverall).clamp(0.0, 1.0);
    final fmt = _moneyFor(context);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: _cardDecoration(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Fee Collection (Overall)', maxLines: 1, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
                    Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.success)),
                    if (MediaQuery.of(context).size.width >= 350) ...[   // very narrow phones keep the title on one line instead
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Text(periodLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.info)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(height: 11, color: AppColors.borderNeutral),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 11,
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _figure(fmt, 'Collected', stats.totalCollectedOverall, AppColors.success)),
                      const VerticalDivider(width: 1, thickness: 1, color: AppColors.borderNeutral),
                      Expanded(child: _figure(fmt, 'Discount', stats.totalDiscountOverall, AppColors.info, pad: true)),
                      const VerticalDivider(width: 1, thickness: 1, color: AppColors.borderNeutral),
                      Expanded(child: _figure(fmt, 'Balance', stats.balanceOverall, AppColors.warning, pad: true)),
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

  Widget _figure(NumberFormat fmt, String label, double v, Color c, {bool pad = false}) {
    return Padding(
      padding: EdgeInsets.only(left: pad ? 12 : 0, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(width: 11, height: 11, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)))),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(fmt.format(v), maxLines: 1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: _cardDecoration(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Students by Class', maxLines: 2, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.15))),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: onTotalTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Total $total', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.info)),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.info),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < stats.classStrengths.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.borderNeutral),
            _ClassRow(c: stats.classStrengths[i]),
          ],
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.c});
  final ClassStrength c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 42,
              child: Align(alignment: Alignment.centerLeft, child: Text(c.className.trim(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.borderNeutral),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                children: c.sections.isEmpty
                    ? [_pill('Students', c.studentCount, AppColors.textSecondary)]
                    : [for (final s in c.sections) _medium(s)],
              ),
            ),
            const SizedBox(width: 8),
            Align(alignment: Alignment.centerRight, child: Text('${c.studentCount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }

  Widget _medium(ClassSectionStrength s) {
    final color = _mediumColor(s.sectionName);
    final pill = _pill(_mediumLabel(s.sectionName), s.studentCount, color);
    if (s.batches.isEmpty) return pill;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pill,
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 3),
          child: Text(s.batches.map((b) => '${b.batchName} ${b.studentCount}').join(' · '),
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.2)),
        ),
      ],
    );
  }

  Widget _pill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$label  ', style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500)),
        TextSpan(text: '$count', style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w800)),
      ])),
    );
  }

  /// Sections double as Medium (English / Hindi / Semi-English) and, for 11th-12th, as streams (Commerce / Science).
  static String _mediumLabel(String section) {
    final name = section.trim().replaceAll(RegExp(r'\s*-\s*'), '-');
    return name.isEmpty ? 'Other' : name;
  }

  static Color _mediumColor(String section) {
    final l = section.toLowerCase();
    if (l.contains('semi')) return AppColors.teal;
    if (l.contains('english')) return AppColors.info;
    if (l.contains('hindi')) return AppColors.warning;
    return AppColors.violet;
  }
}

// ───────────────────────────── quick actions ─────────────────────────────

class AdminQuickTile extends StatelessWidget {
  const AdminQuickTile({super.key, required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// "Lecture Schedule" -> two short lines, so even a narrow tile can show the whole word without cutting it.
  static String _wrap(String l) {
    final t = l.trim();
    final sp = t.indexOf(' ');
    return (sp > 0 && t.length > 9) ? '${t.substring(0, sp)}\n${t.substring(sp + 1)}' : t;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: _cardDecoration(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: LayoutBuilder(builder: (context, c) {
            final roomy = c.maxWidth >= 140;   // tablets: also show the arrow
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: roomy ? 12 : 7, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  SizedBox(width: roomy ? 10 : 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_wrap(label), maxLines: 2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.15)),
                    ),
                  ),
                  if (roomy) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class AdminQuickGrid extends StatelessWidget {
  const AdminQuickGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 4 : (c.maxWidth < 300 ? 2 : 3);
      const gap = 10.0, extent = 58.0;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: math.max(1.4, (c.maxWidth - (cols - 1) * gap) / cols / extent),
        children: children,
      );
    });
  }
}
