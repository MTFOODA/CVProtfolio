import '../design/app_icons.dart';

import 'package:flutter/material.dart';

import '../domain/profile_models.dart';
import '../l10n/app_strings.dart';
import '../theme/app_tokens.dart';

/// Preserves historical/free-form values while offering a real date picker.
class DateRangeFields extends StatefulWidget {
  const DateRangeFields({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final DateRange value;
  final ValueChanged<DateRange> onChanged;
  @override
  State<DateRangeFields> createState() => _DateRangeFieldsState();
}

class _DateRangeFieldsState extends State<DateRangeFields> {
  late final _start = TextEditingController(text: widget.value.startIso);
  late final _end = TextEditingController(text: widget.value.endIso);
  late bool _current = widget.value.isCurrent;
  void _change() => widget.onChanged(
    DateRange(
      startIso: _start.text.trim(),
      endIso: _end.text.trim(),
      isCurrent: _current,
    ),
  );
  Future<void> _pick(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(controller.text);
    final date = await showDatePicker(
      context: context,
      initialDate:
          initial != null &&
              initial.year >= 1900 &&
              initial.year <= now.year + 20
          ? initial
          : now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (!mounted || date == null) return;
    controller.text = date.toIso8601String().split('T').first;
    _change();
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextFormField(
        controller: _start,
        onChanged: (_) => _change(),
        decoration: InputDecoration(
          labelText: context.tr('startDate'),
          suffixIcon: IconButton(
            tooltip: context.tr('startDate'),
            onPressed: () => _pick(_start),
            icon: const Icon(AppIcons.calendar),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _end,
        enabled: !_current,
        onChanged: (_) => _change(),
        validator: (value) {
          final a = DateTime.tryParse(_start.text.trim());
          final b = DateTime.tryParse(value?.trim() ?? '');
          return !_current && a != null && b != null && b.isBefore(a)
              ? context.tr('endBeforeStart')
              : null;
        },
        decoration: InputDecoration(
          labelText: context.tr('endDate'),
          suffixIcon: IconButton(
            tooltip: context.tr('endDate'),
            onPressed: _current ? null : () => _pick(_end),
            icon: const Icon(AppIcons.calendar),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr('ongoing')),
        value: _current,
        onChanged: (value) {
          setState(() => _current = value ?? false);
          _change();
        },
      ),
    ],
  );
}
