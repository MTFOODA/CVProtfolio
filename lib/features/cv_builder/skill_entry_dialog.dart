import '../../core/design/app_icons.dart';
import '../../core/utils/input_validation.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../core/design/skill_icons.dart';
import '../../core/domain/profile_models.dart';
import '../../core/render/section_titles.dart';
import '../../core/utils/utils.dart';

class SkillEntryDialog extends StatefulWidget {
  const SkillEntryDialog({
    super.key,
    this.initial,
    required this.existingSkills,
    required this.onSave,
  });
  final SkillEntry? initial;
  final List<String> existingSkills;
  final Future<void> Function(SkillEntry) onSave;
  @override
  State<SkillEntryDialog> createState() => _SkillEntryDialogState();
}

class _SkillEntryDialogState extends State<SkillEntryDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late int _level = (widget.initial?.proficiency ?? 1).clamp(1, 4);
  late String _icon = widget.initial?.iconId ?? 'general';
  late bool _manualIcon = widget.initial != null;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    final validation = InputValidation.text(name, required: true, max: 100);
    if (validation != null ||
        widget.existingSkills.any(
          (s) => s.trim().toLowerCase() == name.toLowerCase(),
        )) {
      setState(
        () => _error = validation != null
            ? context.tr(validation)
            : context.ui('This skill already exists.'),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(
        (widget.initial ?? SkillEntry(id: newId())).copyWith(
          name: name,
          proficiency: _level,
          iconId: _icon,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save this skill. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: UiText(widget.initial == null ? 'Add skill' : 'Edit skill'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: _busy,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  onChanged: (value) => setState(() {
                    if (!_manualIcon) {
                      _icon = exactSkillIcon(value)?.id ?? 'general';
                    }
                  }),
                  decoration: InputDecoration(
                    labelText: context.ui('Skill name'),
                  ),
                ),
                if (_name.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in matchingSkillIcons(
                          _name.text,
                        ).take(6))
                          ActionChip(
                            avatar: SkillIconView(option.id, size: 18),
                            label: Text(option.label),
                            onPressed: () => setState(() {
                              _name.text = option.label;
                              _icon = option.id;
                              _manualIcon = true;
                            }),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _level,
                  decoration: InputDecoration(
                    labelText: context.ui('Proficiency'),
                  ),
                  items: [
                    for (var i = 1; i <= 4; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          proficiencyLabel(
                            i,
                            languageCode: context.languageCode,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _level = v ?? 1),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDialog<String>(
                      context: context,
                      builder: (_) => SkillIconPicker(selected: _icon),
                    );
                    if (mounted && selected != null) {
                      setState(() {
                        _icon = selected;
                        _manualIcon = true;
                      });
                    }
                  },
                  icon: SkillIconView(_icon),
                  label: UiText('Icon: ${skillIcon(_icon).label}'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: UiText(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const UiText('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: UiText(_busy ? 'Saving...' : 'Save'),
        ),
      ],
    ),
  );
}

class SkillIconPicker extends StatefulWidget {
  const SkillIconPicker({super.key, required this.selected});
  final String selected;
  @override
  State<SkillIconPicker> createState() => _SkillIconPickerState();
}

class _SkillIconPickerState extends State<SkillIconPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final options = matchingSkillIcons(_query);
    return AlertDialog(
      title: const UiText('Choose a skill icon'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: context.ui('Search icons'),
                prefixIcon: Icon(AppIcons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: options.isEmpty
                  ? const Center(child: UiText('No matching icons'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 115,
                            mainAxisExtent: 100,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = option.id == widget.selected;
                        return Semantics(
                          selected: selected,
                          button: true,
                          label: context.ui(option.label),
                          child: Material(
                            color: selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, option.id),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SkillIconView(option.id),
                                    const SizedBox(height: 6),
                                    UiText(
                                      option.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const UiText('Cancel'),
        ),
      ],
    );
  }
}
