import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/message_template.dart';
import '../../services/message_template_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Masters → Templates. The WhatsApp texts the app sends (absent alert, fee reminder…) live here, so
/// wording changes never need an app update.
class MessageTemplatesTab extends StatefulWidget {
  const MessageTemplatesTab({super.key});

  @override
  State<MessageTemplatesTab> createState() => _MessageTemplatesTabState();
}

class _MessageTemplatesTabState extends State<MessageTemplatesTab> {
  final _service = MessageTemplateService();
  bool _loading = true;
  String? _error;
  List<MessageTemplate> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _service.getAll();
      if (mounted) setState(() { _items = items; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _openForm({MessageTemplate? item}) async {
    final titleCtrl = TextEditingController(text: item?.title ?? '');
    final bodyCtrl = TextEditingController(text: item?.body ?? '');
    var category = item?.category ?? messageCategories.first;
    if (!messageCategories.contains(category)) category = 'General';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item == null ? 'Add Template' : 'Edit Template', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Used for'),
                  items: [for (final c in messageCategories) DropdownMenuItem(value: c, child: Text(categoryLabel(c)))],
                  onChanged: (v) => setSheetState(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *')),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: 'Message *', alignLabelWithHint: true),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Insert:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    for (final p in templatePlaceholders)
                      ActionChip(
                        label: Text(p, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final sel = bodyCtrl.selection;
                          final at = sel.isValid ? sel.start : bodyCtrl.text.length;
                          bodyCtrl.value = TextEditingValue(
                            text: bodyCtrl.text.replaceRange(at, sel.isValid ? sel.end : at, p),
                            selection: TextSelection.collapsed(offset: at + p.length),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
              ],
            ),
          ),
        ),
      ),
    );
    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    titleCtrl.dispose();
    bodyCtrl.dispose();
    if (saved != true || !mounted) return;
    if (title.isEmpty || body.isEmpty) { showSnack(context, 'Title and message are required.', isError: true); return; }
    try {
      await _service.save(id: item?.templateId ?? 0, category: category, title: title, body: body);
      if (mounted) { showSnack(context, item == null ? 'Template added.' : 'Template updated.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _confirmDelete(MessageTemplate item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete template "${item.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(item.templateId);
      if (mounted) { showSnack(context, 'Deleted.'); _load(); }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const EmptyState(message: 'No message templates yet.', icon: Icons.chat_bubble_outline)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final t = _items[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.violetSoft, borderRadius: BorderRadius.circular(10)),
                                        child: Text(categoryLabel(t.category), style: const TextStyle(fontSize: 11, color: AppColors.violet, fontWeight: FontWeight.w600)),
                                      ),
                                      IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(item: t)),
                                      IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger), onPressed: () => _confirmDelete(t)),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Text(t.body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
