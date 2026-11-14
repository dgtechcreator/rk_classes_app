import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PremiumNavItem {
  const PremiumNavItem({required this.icon, required this.selectedIcon, required this.label, this.badge = 0});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

/// Rounded bottom bar: icon with its label underneath, the selected tab sits in a soft pill of the brand colour.
/// Tabs share the width equally, so it works for 2 tabs (class rep) up to 6 (parent) on any screen size.
class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({super.key, required this.currentIndex, required this.onTap, required this.items});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PremiumNavItem> items;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // A floating rounded bar (the Home design): small gap round it, the selected tab in a soft blue pill.
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 6, 14, bottomInset > 0 ? bottomInset + 4 : 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: const Color(0xFF192D82).withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(child: _NavTile(item: items[i], selected: i == currentIndex, compact: items.length > 4, onTap: () => onTap(i))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.compact, required this.onTap});
  final PremiumNavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1B3BB5) : const Color(0xFF5B6478);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE4EAFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? item.selectedIcon : item.icon, color: color, size: compact ? 21 : 22),
                  if (item.badge > 0)
                    Positioned(
                      top: -4,
                      right: -9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 15),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.surface, width: 1.5),
                        ),
                        child: Text(
                          item.badge > 9 ? '9+' : '${item.badge}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: compact ? 9.5 : 10.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
