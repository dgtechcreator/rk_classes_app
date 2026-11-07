import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class _ParentAccount {
  _ParentAccount(this.parentId, this.phone, this.password, this.fullName, this.isActive, this.lastLogin);
  final int parentId;
  final String phone;
  final String password;
  final String fullName;
  final bool isActive;
  final DateTime? lastLogin;

  factory _ParentAccount.fromJson(Map<String, dynamic> j) => _ParentAccount(
        (j['parentId'] as num?)?.toInt() ?? 0,
        j['phone']?.toString() ?? '',
        j['password']?.toString() ?? '',
        j['fullName']?.toString() ?? '',
        j['isActive'] != false,
        DateTime.tryParse(j['lastLogin']?.toString() ?? ''),
      );
}

/// Parent login accounts for the admin - the same list as the website's "Parent Accounts" page: the login id (the
/// parent's phone number) and password, with one-tap copy so they can be sent to a parent.
class ParentAccountsScreen extends StatefulWidget {
  const ParentAccountsScreen({super.key});

  @override
  State<ParentAccountsScreen> createState() => _ParentAccountsScreenState();
}

class _ParentAccountsScreenState extends State<ParentAccountsScreen> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<_ParentAccount> _all = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.get('/api/parent-accounts');
      final list = ((res.data as Map)['accounts'] as List? ?? []).map((e) => _ParentAccount.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) setState(() { _all = list; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  List<_ParentAccount> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((a) => a.phone.contains(q) || a.fullName.toLowerCase().contains(q)).toList();
  }

  Future<void> _copy(String what, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showSnack(context, '$what copied.');
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return Scaffold(
      appBar: AppBar(title: Text('Parent Accounts (${_all.length})')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(hintText: 'Search by name or phone', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                      ),
                      const SizedBox(height: 10),
                      if (list.isEmpty)
                        const EmptyState(message: 'No parent accounts found.', icon: Icons.people_outline)
                      else
                        for (final a in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: _card(a)),
                    ],
                  ),
                ),
    );
  }

  Widget _card(_ParentAccount a) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(a.fullName.isEmpty ? 'Parent' : a.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: a.isActive ? AppColors.successSoft : AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(a.isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: a.isActive ? AppColors.success : AppColors.danger)),
              ),
              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 6),
          _credRow('Login ID (phone)', a.phone, () => _copy('Phone', a.phone)),
          _credRow('Password', a.password, () => _copy('Password', a.password)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(a.lastLogin == null ? 'Never logged in' : 'Last login ${DateFormat('dd MMM yyyy, h:mm a').format(a.lastLogin!)}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ),
              TextButton.icon(
                onPressed: () => _copy('Login details', 'RK Classes app login\nID: ${a.phone}\nPassword: ${a.password}'),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy both', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _credRow(String label, String value, VoidCallback onCopy) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 118, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            Expanded(child: SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFeatures: [FontFeature.tabularFigures()]))),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.copy_rounded, size: 17), onPressed: onCopy, tooltip: 'Copy'),
          ],
        ),
      );
}
