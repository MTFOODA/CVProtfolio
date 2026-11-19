import 'package:flutter/material.dart';

import '../domain/profile_models.dart';
import '../l10n/app_strings.dart';
import '../l10n/ui_text.dart';
import 'form_validation.dart';

/// The same item editor is used for project and employment descriptions.
class DescriptionItemsEditor extends StatefulWidget {
  const DescriptionItemsEditor({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<DescriptionItem> items;
  final ValueChanged<List<DescriptionItem>> onChanged;

  @override
  State<DescriptionItemsEditor> createState() => DescriptionItemsEditorState();
}

class DescriptionItemsEditorState extends State<DescriptionItemsEditor> {
  static const _labels = [
    'Architecture',
    'State management',
    'Features',
    'Responsibilities',
    'Achievements',
    'Technologies',
    'APIs',
    'Database',
    'Testing',
    'Performance',
  ];
  final _text = TextEditingController();
  final _customLabel = TextEditingController();
  String _label = '';
  String? _error;
  int? _editing;

  @override
  void dispose() {
    _text.dispose();
    _customLabel.dispose();
    super.dispose();
  }

  /// Save also commits a typed item so closing the dialog cannot drop it.
  bool commitPending({bool required = false}) {
    if (_text.text.trim().isEmpty &&
        !required &&
        _editing == null &&
        _label.isEmpty &&
        _customLabel.text.trim().isEmpty) {
      return true;
    }
    final error =
        context.validateText(_text.text, required: true) ??
        (_label == 'custom'
            ? context.validateText(_customLabel.text, required: true, max: 100)
            : null);
    if (error != null) {
      setState(() => _error = error);
      return false;
    }
    final item = DescriptionItem(
      text: _text.text.trim(),
      label: _label == 'custom' ? _customLabel.text.trim() : _label,
    );
    final items = [...widget.items];
    if (_editing case final int index) {
      items[index] = item;
    } else {
      items.add(item);
    }
    widget.onChanged(items);
    setState(_reset);
    return true;
  }

  void _reset() {
    _text.clear();
    _customLabel.clear();
    _label = '';
    _editing = null;
    _error = null;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const UiText('Description items'),
        const SizedBox(height: 12),
        for (var i = 0; i < widget.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: DescriptionItemText(item: widget.items[i])),
                IconButton(
                  tooltip: context.ui('Edit item'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => setState(() {
                    final item = widget.items[i];
                    _editing = i;
                    _text.text = item.text;
                    _label = item.label.isEmpty || _labels.contains(item.label)
                        ? item.label
                        : 'custom';
                    _customLabel.text = _label == 'custom' ? item.label : '';
                    _error = null;
                  }),
                ),
                IconButton(
                  tooltip: context.ui('Remove item'),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    widget.onChanged([...widget.items]..removeAt(i));
                    setState(() {
                      if (_editing == i) {
                        _reset();
                      } else if (_editing != null && _editing! > i) {
                        _editing = _editing! - 1;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        DropdownButtonFormField<String>(
          key: ValueKey('description-label-$_label'),
          initialValue: _label,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.ui('Basic entry (optional)'),
          ),
          items: [
            DropdownMenuItem(value: '', child: UiText('No heading')),
            for (final label in _labels)
              DropdownMenuItem(value: label, child: Text(label)),
            DropdownMenuItem(value: 'custom', child: UiText('Custom heading')),
          ],
          onChanged: (value) => setState(() => _label = value ?? ''),
        ),
        if (_label == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customLabel,
            decoration: InputDecoration(
              labelText: context.ui('Custom heading'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: context.ui('Entry text'),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => commitPending(required: true),
          icon: Icon(_editing == null ? Icons.add : Icons.check),
          label: UiText(_editing == null ? 'Add item' : 'Update item'),
        ),
        if (_editing != null)
          TextButton(
            onPressed: () => setState(_reset),
            child: const UiText('Cancel'),
          ),
      ],
    ),
  );
}

class DescriptionItemText extends StatelessWidget {
  const DescriptionItemText({super.key, required this.item, this.style});
  final DescriptionItem item;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: '\u2022 '),
        if (item.label.trim().isNotEmpty)
          TextSpan(
            text: '${item.label.trim()}: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        TextSpan(text: item.text),
      ],
    ),
    style: style,
  );
}
