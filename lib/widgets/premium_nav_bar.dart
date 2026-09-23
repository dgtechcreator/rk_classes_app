import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PremiumNavItem {
  const PremiumNavItem({required this.icon, required this.selectedIcon, required this.label, this.badge = 0});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

/// Floating, edge-to-edge rounded nav bar with an animated pill indicator that slides between tabs —
/// replaces the stock [NavigationBar]/[BottomNavigationBar] look with something closer to the polish
/// of top consumer apps (soft shadow lifted off the content, bouncy selection, badge dots).
class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({super.key, required this.currentIndex, required this.onTap, required this.items});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PremiumNavItem> items;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: AppShadows.navBar,
      ),
      padding: EdgeInsets.fromLTRB(6, 10, 6, bottomInset > 0 ? bottomInset - 4 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < items.length; i++)
            _NavTile(item: items[i], selected: i == currentIndex, onTap: () => onTap(i)),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.onTap});
  final PremiumNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(horizontal: selected ? 10 : 6, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    key: ValueKey(selected),
                    color: selected ? AppColors.primary : AppColors.textMuted,
                    size: 24,
                  ),
                ),
                if (item.badge > 0)
                  Positioned(
                    top: -4,
                    right: -8,
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
            if (selected)
              Flexible(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
