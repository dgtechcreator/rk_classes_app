import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Drop-in for [DropdownButtonFormField]: a short list stays the normal dropdown; a longer one (teachers, students,
/// classes ...) opens a full-height sheet with a search box, so one name is found by typing instead of scrolling.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    this.initialValue,
    this.value,
    required this.items,
    required this.onChanged,
    this.decoration,
    this.isExpanded = true,
    this.validator,
    this.alwaysSearch = false,
  });

  /// Teacher / student pickers: always get the search box, even when the list is still short.
  final bool alwaysSearch;
  final T? initialValue;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration? decoration;
  final bool isExpanded;
  final FormFieldValidator<T>? validator;

  /// From this many entries on, the dropdown gets a search box.
  static const int searchFrom = 7;

  @override
  Widget build(BuildContext context) {
    final current = value ?? initialValue;
    if (items.length < searchFrom && !alwaysSearch) {
      return DropdownButtonFormField<T>(
        key: ValueKey('dd-${current.hashCode}-${items.length}'),
        initialValue: current,
        items: items,
        onChanged: onChanged,
        decoration: decoration ?? const InputDecoration(),
        isExpanded: isExpanded,
        validator: validator,
      );
    }
    return _SearchableField<T>(initialValue: current, items: items, onChanged: onChanged, decoration: decoration, validator: validator);
  }
}

class _Picked<T> {
  _Picked(this.value);
  final T? value;
}

String _labelOf<T>(DropdownMenuItem<T> i) {
  final c = i.child;
  if (c is Text) return c.data ?? c.textSpan?.toPlainText() ?? '${i.value}';
  return '${i.value ?? ''}';
}

class _SearchableField<T> extends FormField<T> {
  _SearchableField({
    required T? initialValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    InputDecoration? decoration,
    super.validator,
  }) : super(
          initialValue: initialValue,
          builder: (state) {
            DropdownMenuItem<T>? selected;
            for (final i in items) {
              if (i.value == state.value) { selected = i; break; }
            }
            final deco = (decoration ?? const InputDecoration()).copyWith(
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
            );
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: onChanged == null
                  ? null
                  : () async {
                      final picked = await showModalBottomSheet<_Picked<T>>(
                        context: state.context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (_) => _PickerSheet<T>(items: items, current: state.value, title: decoration?.labelText),
                      );
                      if (picked == null) return;
                      state.didChange(picked.value);
                      onChanged(picked.value);
                    },
              child: InputDecorator(
                decoration: deco,
                isEmpty: selected == null,
                child: Text(
                  selected == null ? '' : _labelOf(selected),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );

  @override
  FormFieldState<T> createState() => _SearchableFieldState<T>();
}

// The field shows whatever value the screen passes in (the screens keep the value in their own state).
class _SearchableFieldState<T> extends FormFieldState<T> {
  @override
  void didUpdateWidget(covariant FormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) setValue(widget.initialValue);
  }
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({required this.items, required this.current, this.title});
  final List<DropdownMenuItem<T>> items;
  final T? current;
  final String? title;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = _q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final shown = widget.items.where((i) {
      final l = _labelOf(i).toLowerCase();
      return words.every(l.contains);
    }).toList();
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            if ((widget.title ?? '').isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 4), child: Align(alignment: Alignment.centerLeft, child: Text(widget.title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _q.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _search.clear(); setState(() => _q = ''); }),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(child: Text('Nothing matches', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final it = shown[i];
                        final sel = it.value == widget.current;
                        return ListTile(
                          dense: true,
                          selected: sel,
                          title: Text(_labelOf(it)),
                          trailing: sel ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                          onTap: () => Navigator.of(context).pop(_Picked<T>(it.value)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
