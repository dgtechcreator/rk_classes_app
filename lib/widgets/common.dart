import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.color, this.icon, this.onTap});

  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
                  child: Icon(icon, size: 17, color: color),
                ),
              const Spacer(),
              if (onTap != null)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_outward_rounded, size: 12, color: color.withValues(alpha: 0.75)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(AppRadius.lg), onTap: onTap, child: card);
  }
}

Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'present':
    case 'paid':
    case 'active':
    case 'completed':
      return AppColors.success;
    case 'pending':
    case 'late':
    case 'partial':
      return AppColors.warning;
    case 'absent':
    case 'overdue':
    case 'cancelled':
    case 'inactive':
      return AppColors.danger;
    default:
      return AppColors.info;
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ?action,
        ],
      ),
    );
  }
}

/// Rounded icon-tile with a bordered card body — used for dense grids of actionable items
/// (the staff module grid). For a lighter, card-less variant see [SubjectQuickTile].
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.label, required this.color, this.onTap, this.badge});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -4, right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Plain circular icon + label, no card background — for a short, light-touch quick-nav row
/// (e.g. a parent's "Subjects" strip) where a handful of items don't need card separation.
class SubjectQuickTile extends StatelessWidget {
  const SubjectQuickTile({super.key, required this.icon, required this.color, required this.label, this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Rounded white card with a leading title/subtitle/badge and a colored icon square on the
/// trailing edge — the app's standard "list row" look (grades, attendance, fee history, etc.),
/// replacing plain `Card(child: ListTile(...))` wherever a more visual row is wanted.
class ListInfoCard extends StatelessWidget {
  const ListInfoCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.badgeText,
    this.badgeColor,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (badgeText != null && badgeText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: (badgeColor ?? AppColors.info).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(badgeText!, style: TextStyle(color: badgeColor ?? AppColors.info, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: card);
  }
}

/// Horizontal day-picker strip (an "All" pill plus one cell per date) — used to narrow a list down
/// to one day, e.g. filtering a grades/attendance list by test date.
class DateStrip extends StatelessWidget {
  const DateStrip({super.key, required this.dates, required this.selected, required this.onSelected});
  final List<DateTime> dates;
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _cell(label: 'All', sub: '', selected: selected == null, onTap: () => onSelected(null));
          }
          final d = dates[i - 1];
          final isSelected = selected != null && selected!.year == d.year && selected!.month == d.month && selected!.day == d.day;
          return _cell(label: '${d.day}', sub: DateFormat.E().format(d), selected: isSelected, onTap: () => onSelected(d));
        },
      ),
    );
  }

  Widget _cell({required String label, required String sub, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: selected ? Colors.white : AppColors.textPrimary)),
            if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Rounded-bottom gradient banner (brand primary → primaryDark) for a shell's Home screen — the
/// "Hello, {name}" header pattern shared by the parent and staff dashboards. Carries a subtle
/// decorative circle motif (common in top-tier consumer app headers) instead of a flat gradient
/// slab, and a bigger initials avatar so the header reads as a genuine "home" moment, not a title bar.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.greeting, required this.name, this.subtitle, this.leadingIcon = Icons.person_outline, this.actions = const []});
  final String greeting;
  final String name;
  final String? subtitle;
  final IconData leadingIcon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 10, 22),
        decoration: const BoxDecoration(gradient: AppGradients.primarySheen).copyWith(boxShadow: AppShadows.header),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -46,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              bottom: -60,
              right: 60,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.1)),
                      const SizedBox(height: 2),
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.pill)),
                          child: Text(subtitle!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Large tappable card used in a Home screen's "Quick Actions" row — bigger touch target and more
/// visual weight than [IconTile], for the handful of shortcuts worth surfacing above the fold.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({super.key, required this.icon, required this.label, required this.color, this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.85), color]),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Plain (non-gradient) title block for a bottom-nav tab root that isn't the Home/Profile tab —
/// keeps sizing/spacing consistent with the gradient [GreetingHeader] screens without the heavier
/// treatment, so every tab root reads as part of the same shell instead of a pushed sub-page.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.danger : AppColors.primaryDark,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
