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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.violet.withValues(alpha: 0.85), AppColors.violet],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Icon(icon, size: 42, color: Colors.white),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: AppColors.violetSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: const Text('COMING SOON', style: TextStyle(color: AppColors.violet, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'This module is fully live on the RK Classes web portal — its mobile screen is next up.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
