import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// White bell with an unread-count badge, for use on the gradient headers.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Notifications, $count unread' : 'Notifications',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 27),
              if (count > 0)
                Positioned(
                  top: 5,
                  right: 3,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.primary, width: 1.6),
                    ),
                    child: Text(count > 99 ? '99+' : '$count',
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, height: 1.1)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
