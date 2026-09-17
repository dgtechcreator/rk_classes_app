import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Placeholder for staff modules not yet built in the mobile app — the JWT API for every module already
/// exists (SchoolMS.Web/Controllers/Api/*), so wiring a real screen here is additive follow-up work,
/// not a backend gap.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text('$title — coming soon', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('This module is fully live on the RK Classes web portal and its API is ready — the mobile screen is next up.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
