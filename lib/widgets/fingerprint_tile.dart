import 'package:flutter/material.dart';

import '../core/biometric_login.dart';
import '../theme/app_theme.dart';

/// Profile row for fingerprint sign-in. It can be switched OFF here; it is switched ON at sign-in (that is when the app has the password).
class FingerprintTile extends StatefulWidget {
  const FingerprintTile({super.key, required this.kind, this.flush = false});

  /// Inside a card: no side padding, and a thin line above the row (only drawn when the row itself is shown).
  final bool flush;

  /// "staff" or "parent".
  final String kind;

  @override
  State<FingerprintTile> createState() => _FingerprintTileState();
}

class _FingerprintTileState extends State<FingerprintTile> {
  bool _available = false, _on = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await BiometricLogin.available();
    final on = a && await BiometricLogin.isEnabled(widget.kind);
    if (mounted) setState(() { _available = a; _on = on; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final tile = SwitchListTile(
      contentPadding: widget.flush ? EdgeInsets.zero : null,
      secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
      title: const Text('Fingerprint login', style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        _on ? 'On - touch the sensor on the login screen' : 'Off - to turn it on, sign out and sign in with your password, then choose "Turn on"',
        style: const TextStyle(fontSize: 12),
      ),
      value: _on,
      onChanged: _on
          ? (v) async {
              if (!v) {
                await BiometricLogin.disable(widget.kind);
                if (mounted) setState(() => _on = false);
              }
            }
          : null,
    );
    if (!widget.flush) return tile;
    return Column(children: [const Padding(padding: EdgeInsets.only(top: 4, bottom: 4), child: Divider(height: 1, color: Color(0xFFE9EDF6))), tile]);
  }
}
