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
    'Overview',
    'Objectives',
    'Project scope',
    'My role',
    'Responsibilities',
    'Achievements',
    'Key results',
    'Business impact',
    'Deliverables',
    'Features',
    'Architecture',
    'Design patterns',
    'State management',
    'User interface',
    'User experience',
    'Accessibility',
    'Responsive design',
    'Technologies',
    'Tools',
    'Platforms',
    'APIs',
    'Integrations',
    'Database',
    'Data modeling',
    'Authentication',
    'Authorization',
    'Security',
    'Privacy',
    'Payments',
    'Notifications',
    'Real-time updates',
    'Offline support',
    'Caching',
    'Error handling',
    'Testing',
    'Quality assurance',
    'Performance',
    'Scalability',
    'CI/CD',
    'Deployment',
    'Monitoring',
    'Maintenance',
    'Documentation',
    'Research',
    'Data analysis',
    'Automation',
    'Operations',
    'Customer support',
    'Sales and growth',
    'Marketing',
    'Budget management',
    'Risk management',
    'Collaboration',
    'Stakeholder management',
    'Leadership',
    'Mentoring',
    'Training',
    'Process improvements',
    'Challenges',
    'Solutions',
    'Key learnings',
  ];
  final _text = TextEditingController();
  final _heading = TextEditingController();
  final _recentHeadings = <String>{};
  String? _error;
  String? _headingError;
  int? _editing;

  @override
  void dispose() {
    _text.dispose();
    _heading.dispose();
    super.dispose();
  }

  /// Save also commits a typed item so closing the dialog cannot drop it.
  bool commitPending({bool required = false}) {
    if (_text.text.trim().isEmpty &&
        !required &&
        _editing == null &&
        _heading.text.trim().isEmpty) {
      return true;
    }
    final error = context.validateText(_text.text, required: true);
    final headingError = context.validateText(_heading.text, max: 100);
    if (error != null || headingError != null) {
      setState(() {
        _error = error;
        _headingError = headingError;
      });
      return false;
    }
    final item = DescriptionItem(
      text: _text.text.trim(),
      label: _heading.text.trim(),
    );
    final items = [...widget.items];
    if (_editing case final int index) {
      items[index] = item;
    } else {
      items.add(item);
    }
    if (item.label.isNotEmpty) _recentHeadings.add(item.label);
    widget.onChanged(items);
    setState(_reset);
    return true;
  }

  void _reset() {
    _text.clear();
    _heading.clear();
    _editing = null;
    _error = null;
    _headingError = null;
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
                    _heading.text = item.label;
                    _error = null;
                    _headingError = null;
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
        DropdownMenu<String>(
          key: const ValueKey('description-heading'),
          controller: _heading,
          expandedInsets: EdgeInsets.zero,
          menuHeight: 300,
          requestFocusOnTap: true,
          enableFilter: true,
          label: UiText('Basic entry (optional)'),
          hintText: context.ui('Choose or type a heading'),
          helperText: context.ui(
            'Type your own heading or search the suggestions.',
          ),
          errorText: _headingError,
          inputDecorationTheme: const InputDecorationThemeData(
            helperMaxLines: 3,
          ),
          dropdownMenuEntries: [
            DropdownMenuEntry(value: '', label: context.ui('No heading')),
            for (final label in <String>{
              ..._labels,
              ..._recentHeadings,
              for (final item in widget.items)
                if (item.label.trim().isNotEmpty) item.label.trim(),
            })
              DropdownMenuEntry(value: label, label: label),
          ],
          onSelected: (value) {
            // Selecting the empty option must leave an empty saved heading,
            // rather than persisting its translated display label.
            if (value == '') _heading.clear();
            setState(() => _headingError = null);
          },
        ),
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
