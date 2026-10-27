import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../services/fees_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/person_card.dart';
import 'fee_pay_screen.dart';
import 'fee_summary_screen.dart';

/// Search a student to collect a fee payment from — mirrors the quick-search box at the top of
/// FeesController.Index. Mobile splits it into its own screen since there's no room for a combined
/// search+summary list on a phone; "History" in the app bar reaches the old summary/history list.
class FeeCollectSearchScreen extends StatefulWidget {
  const FeeCollectSearchScreen({super.key});

  @override
  State<FeeCollectSearchScreen> createState() => _FeeCollectSearchScreenState();
}

class _FeeCollectSearchScreenState extends State<FeeCollectSearchScreen> {
  final _service = FeesService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<StudentQuickResult> _results = [];
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() { _results = []; _searched = false; _error = null; });
      return;
    }
    setState(() { _loading = true; _error = null; _searched = true; });
    try {
      final results = await _service.quickSearchStudents(q);
      if (mounted) setState(() { _results = results; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Fee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Payment History',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeeSummaryScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                labelText: 'Student / father / mother name or admission no.',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: () => _search(_searchCtrl.text));
    if (!_searched) return const EmptyState(message: 'Type at least 2 characters to search for a student.', icon: Icons.search);
    if (_results.isEmpty) return const EmptyState(message: 'No students found.', icon: Icons.person_off_outlined);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = _results[i];
        String clean(String? v) => (v ?? '').trim();
        final cls = clean(s.className), med = clean(s.sectionName);
        return PersonCard(
          name: s.fullName,
          photoPath: s.profilePicPath,
          line: s.admissionNo,
          pills: [
            if (cls.isNotEmpty) PersonPill(cls, AppColors.info),
            if (med.isNotEmpty) PersonPill(med, med.toLowerCase().contains('hindi') ? AppColors.warning : AppColors.teal),
          ],
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeePayScreen(studentId: s.studentId, studentName: s.fullName))),
        );
      },
    );
  }
}
