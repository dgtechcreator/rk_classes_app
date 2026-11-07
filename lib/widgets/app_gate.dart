import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
        if (m.updateAvailable && !m.active && (m.forceUpdate || !m.updateDismissed))
          Positioned.fill(child: _UpdateOverlay(controller: m)),
        if (m.active) const Positioned.fill(child: _MaintenanceScreen()),
      ],
    );
  }
}

/// "New version available": a card over the app (compulsory = full screen, cannot be closed). Installed from Google Play:
/// the button opens Google's own update screen (or the Play Store page). Otherwise it downloads the APK from the server.
class _UpdateOverlay extends StatelessWidget {
  const _UpdateOverlay({required this.controller});
  final MaintenanceController controller;

  Future<void> _download(BuildContext context) async {
    final ok = await controller.startUpdate((url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Could not open the update page.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final force = controller.forceUpdate;
    final msg = (controller.updateMessage ?? '').trim().isNotEmpty
        ? controller.updateMessage!.trim()
        : (controller.playUpdate ? 'A new version of RK Classes is available on Google Play.' : '');
    final card = Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: AppShadows.card),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.system_update_rounded, size: 44, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
              controller.latestVersion == null ? 'Update available' : 'Update available · v${controller.latestVersion}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (msg.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _download(context),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Update now'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            if (!force) TextButton(onPressed: controller.dismissUpdate, child: const Text('Later')),
            if (force)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('This update is required to keep using the app.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
    return PopScope(
      canPop: !force,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: card,
      ),
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
