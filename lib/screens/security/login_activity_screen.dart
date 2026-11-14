import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/login_activity_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Privacy / security: which phones and browsers an account was signed in from. Everyone sees their own history;
/// the admin gets a second tab with everybody's (staff, teachers, students / parents) and can search it.
class LoginActivityScreen extends StatelessWidget {
  const LoginActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.read<Session>().isAdmin;
    if (!admin) {
      return Scaffold(appBar: AppBar(title: const Text('Login Activity')), body: const _Feed(everyone: false));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Login Activity'),
          bottom: const TabBar(tabs: [Tab(text: 'My activity'), Tab(text: 'Everyone')]),
        ),
        body: const TabBarView(children: [_Feed(everyone: false), _Feed(everyone: true)]),
      ),
    );
  }
}

class _Feed extends StatefulWidget {
  const _Feed({required this.everyone});
  final bool everyone;

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> with AutomaticKeepAliveClientMixin {
  final _service = LoginActivityService();
  final _search = TextEditingController();
  Timer? _debounce;
  LoginActivityData? _data;
  bool _loading = true;
  String? _error;
  String? _type;     // staff | parent
  String? _result;   // failed

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = _data == null; _error = null; });
    try {
      final d = widget.everyone ? await _service.all(type: _type, q: _search.text, result: _result) : await _service.mine();
      if (mounted) setState(() { _data = d; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _showDevices(LoginEntry e) async {
    if (e.accountId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FutureBuilder<LoginActivityData>(
        future: _service.all(account: '${e.accountType}:${e.accountId}'),
        builder: (ctx, snap) {
          final bottom = MediaQuery.of(ctx).padding.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Devices used by ${e.who}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                if (!snap.hasData && !snap.hasError) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                else if (snap.hasError) const Text('Could not load the devices.')
                else if (snap.data!.devices.isEmpty) const Text('No successful sign-in recorded yet.')
                else ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
                  child: ListView(shrinkWrap: true, children: [for (final d in snap.data!.devices) _deviceTile(d)]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _deviceTile(LoginDevice d) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(radius: 18, backgroundColor: AppColors.primarySoft, child: Icon(d.isApp ? Icons.smartphone_rounded : Icons.language_rounded, size: 18, color: AppColors.primary)),
        title: Text(d.device, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        subtitle: Text('${d.logins} sign-in${d.logins == 1 ? '' : 's'} · last ${DateFormat('dd MMM, h:mm a').format(d.lastUsed)}${d.lastIp == null ? '' : ' · ${d.lastIp}'}', style: const TextStyle(fontSize: 11.5)),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = _data;
    return Column(
      children: [
        if (widget.everyone) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: const InputDecoration(hintText: 'Search name, phone / username, device, IP', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('All', _type == null && _result == null, () { _type = null; _result = null; _load(); }),
                _chip('Staff / Teachers', _type == 'staff', () { _type = _type == 'staff' ? null : 'staff'; _load(); }),
                _chip('Students / Parents', _type == 'parent', () { _type = _type == 'parent' ? null : 'parent'; _load(); }),
                _chip('Failed only', _result == 'failed', () { _result = _result == 'failed' ? null : 'failed'; _load(); }),
              ],
            ),
          ),
        ],
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null && data == null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (!widget.everyone && data != null && data.devices.isNotEmpty) ...[
                            const SectionHeader(title: 'Devices signed in to your account'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
                              child: Column(children: [for (final d in data.devices) _deviceTile(d)]),
                            ),
                            const SizedBox(height: 12),
                            const Text('See a device you do not know? Change your password and tell the admin.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 14),
                            const SectionHeader(title: 'Recent sign-ins'),
                          ],
                          if (data == null || data.entries.isEmpty)
                            const EmptyState(message: 'No login activity found.', icon: Icons.fingerprint_rounded)
                          else
                            for (final e in data.entries) _entryTile(e),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  Widget _entryTile(LoginEntry e) {
    final okColor = e.success ? AppColors.success : AppColors.danger;
    final role = (e.roleName ?? '').isEmpty ? (e.accountType == 'parent' ? 'Student / Parent' : 'Staff') : e.roleName!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: ListTile(
        dense: true,
        onTap: widget.everyone && e.accountId != null ? () => _showDevices(e) : null,
        leading: CircleAvatar(radius: 18, backgroundColor: e.success ? AppColors.successSoft : AppColors.dangerSoft, child: Icon(e.isApp ? Icons.smartphone_rounded : Icons.language_rounded, size: 18, color: okColor)),
        title: Text(widget.everyone ? e.who : (e.device ?? 'Unknown device'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(
          [
            if (widget.everyone) '$role · ${e.loginName}',
            if (widget.everyone) (e.device ?? 'Unknown device'),
            DateFormat('dd MMM yyyy, h:mm a').format(e.loggedAt),
            if (e.appVersion != null && e.appVersion!.isNotEmpty) 'v${e.appVersion}',
            if (e.ip != null && e.ip!.isNotEmpty) e.ip!,
          ].join('\n'),
          style: const TextStyle(fontSize: 11.5, height: 1.35),
        ),
        isThreeLine: widget.everyone,
        trailing: Text(e.success ? 'Success' : 'Failed', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: okColor)),
      ),
    );
  }
}
