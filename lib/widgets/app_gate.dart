import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/maintenance_controller.dart';
import '../theme/app_theme.dart';

/// Sits above the whole Navigator (MaterialApp.builder) so the website's "maintenance mode" switch takes over EVERY
/// screen - login included - and lifts again once the admin turns it off. Re-checks whenever the app comes back to
/// the foreground.
class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<MaintenanceController>().check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<MaintenanceController>().check();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MaintenanceController>();
    return Stack(
      children: [
        widget.child,
        if (m.active) const Positioned.fill(child: _MaintenanceScreen()),
      ],
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MaintenanceController>();
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(14),
                      child: Image.asset('assets/images/rk_logo_icon.png'),
                    ),
                    const SizedBox(height: 24),
                    const Icon(Icons.build_circle_outlined, color: Colors.white, size: 46),
                    const SizedBox(height: 12),
                    const Text('Under maintenance',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text(m.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45)),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: m.checking ? null : m.check,
                      icon: m.checking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      label: Text(m.checking ? 'Checking...' : 'Try again'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        minimumSize: const Size(200, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
