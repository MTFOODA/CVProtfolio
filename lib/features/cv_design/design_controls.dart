import '../../core/design/app_icons.dart';
import '../../core/theme/app_tokens.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../core/design/cv_design_options.dart';
import '../../core/domain/document_models.dart';

class CvDesignControls extends StatelessWidget {
  const CvDesignControls({
    super.key,
    required this.design,
    required this.onChanged,
  });
  final DocumentDesign design;
  final ValueChanged<DocumentDesign> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = design.typography;
    final p = design.presentation;
    void presentation(PresentationConfig value) =>
        onChanged(design.copyWith(presentation: value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignCard(
          title: 'Date & Location Position',
          children: [
            DesignChoices<String>(
              value: p.dateLocationPosition,
              options: const {'right': 'Right', 'belowTitle': 'Below Title'},
              onChanged: (value) =>
                  presentation(p.copyWith(dateLocationPosition: value)),
            ),
          ],
        ),
        DesignCard(
          title: 'Font',
          children: [
            DesignFontDropdown(
              label: 'Body Font',
              value: t.bodyFont,
              onChanged: (value) => onChanged(
                design.copyWith(
                  typography: t.copyWith(
                    bodyFont: value,
                    nameFont:
                        t.nameFont ??
                        (t.headingFont == t.bodyFont ? 'body' : t.headingFont),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            DesignFontDropdown(
              label: 'Name Font',
              value:
                  t.nameFont ??
                  (t.headingFont == t.bodyFont ? 'body' : t.headingFont),
              allowSame: true,
              onChanged: (value) => onChanged(
                design.copyWith(typography: t.copyWith(nameFont: value)),
              ),
            ),
          ],
        ),
        DesignCard(
          title: 'Header',
          children: [
            OutlinedButton.icon(
              icon: const Icon(AppIcons.viewColumn),
              label: const UiText('Use compact header'),
              onPressed: () => presentation(
                p.copyWith(
                  headerStyle: 'left',
                  identityArrangement: 'inline',
                  contactArrangement: 'grid',
                  showContactLabels: false,
                  showContactIcons: true,
                  contactIconStyle: 'plain',
                  contactIconSize: 11,
                ),
              ),
            ),
            const DesignLabel('Name & Professional Title'),
            DesignChoices<String>(
              value: p.identityArrangement,
              options: const {'stacked': 'Stacked', 'inline': 'Side by side'},
              onChanged: (value) =>
                  presentation(p.copyWith(identityArrangement: value)),
            ),
            const DesignLabel('Text Alignment'),
            DesignChoices<String>(
              value: p.headerStyle == 'center' ? 'center' : 'left',
              options: const {'left': 'Left', 'center': 'Center'},
              onChanged: (value) =>
                  presentation(p.copyWith(headerStyle: value)),
            ),
            const DesignLabel('Details Arrangement'),
            DesignChoices<String>(
              value: p.resolvedContactArrangement,
              options: const {
                'compact': 'Compact',
                'oneRow': 'One row',
                'twoRows': 'Two rows',
                'multiRow': 'Multi-row',
                'grid': 'Grid',
              },
              onChanged: (value) =>
                  presentation(p.copyWith(contactArrangement: value)),
            ),
            UiText(
              'Rows wrap when necessary to keep long details readable.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const DesignLabel('Contact Details Display'),
            DesignChoices<bool>(
              value: p.showContactIcons,
              options: const {true: 'Show Icons', false: 'No Icons'},
              onChanged: (value) =>
                  presentation(p.copyWith(showContactIcons: value)),
            ),
            ContactIconSizeControl(
              size: p.resolvedContactIconSize(t.bodyFontSize),
              enabled: p.showContactIcons,
              onChanged: (value) =>
                  presentation(p.copyWith(contactIconSize: value.clamp(8, 24))),
            ),
            const DesignLabel('Icon Style'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final style in const [
                  'plain',
                  'circle',
                  'rounded',
                  'square',
                ])
                  Semantics(
                    selected: p.contactIconStyle == style,
                    button: true,
                    label: context.tr(
                      'contactIconStyleDescription',
                      args: {'style': context.ui(style)},
                    ),
                    child: IconButton.outlined(
                      tooltip: context.tr(
                        'contactIconStyleDescription',
                        args: {'style': context.ui(style)},
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: p.contactIconStyle == style
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surface,
                      ),
                      onPressed: p.showContactIcons
                          ? () => presentation(
                              p.copyWith(contactIconStyle: style),
                            )
                          : null,
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: style == 'plain'
                              ? null
                              : Theme.of(context).colorScheme.primary
                                    .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(
                            style == 'circle'
                                ? 24
                                : style == 'rounded'
                                ? 5
                                : 0,
                          ),
                        ),
                        child: const Icon(AppIcons.link, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              key: const PageStorageKey('cv-header-advanced'),
              tilePadding: EdgeInsets.zero,
              title: const UiText(
                'Advanced Settings',
                style: TextStyle(fontSize: 13),
              ),
              children: [
                const UiText('Name letter spacing'),
                Slider(
                  value: t.headingLetterSpacing.clamp(0, 2),
                  min: 0,
                  max: 2,
                  divisions: 20,
                  label: t.headingLetterSpacing.toStringAsFixed(1),
                  onChanged: (value) => onChanged(
                    design.copyWith(
                      typography: t.copyWith(headingLetterSpacing: value),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        DesignCard(
          title: 'Font Size',
          children: [
            for (final control in CvDesignValue.values.take(5))
              DesignNumberControl(
                control: control,
                design: design,
                onChanged: onChanged,
              ),
          ],
        ),
        DesignCard(
          title: 'Spacing',
          children: [
            for (final control in CvDesignValue.values.skip(5))
              DesignNumberControl(
                control: control,
                design: design,
                onChanged: onChanged,
              ),
          ],
        ),
      ],
    );
  }
}

class DesignCard extends StatelessWidget {
  const DesignCard({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .035),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(
            title,
            style: TextStyle(
              fontSize: 19,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: AppTypography.semibold,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}

class DesignLabel extends StatelessWidget {
  const DesignLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 10),
    child: UiText(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}

class DesignChoices<T> extends StatelessWidget {
  const DesignChoices({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final option in options.entries)
        ChoiceChip(
          label: UiText(option.value),
          selected: value == option.key,
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          onSelected: (_) => onChanged(option.key),
          showCheckmark: false,
          labelStyle: TextStyle(
            color: value == option.key
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: value == option.key
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        ),
    ],
  );
}

class DesignFontDropdown extends StatelessWidget {
  const DesignFontDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowSame = false,
  });
  final String label;
  final String value;
  final bool allowSame;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      UiText(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        items: [
          if (allowSame)
            const DropdownMenuItem(
              value: 'body',
              child: UiText('Same as body font'),
            ),
          if (!cvFontNames.containsKey(value) && value != 'body')
            DropdownMenuItem(
              value: value,
              enabled: false,
              child: UiText('$value (existing font)'),
            ),
          for (final font in cvFontNames.entries)
            DropdownMenuItem(value: font.key, child: Text(font.value)),
        ],
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    ],
  );
}

class DesignNumberControl extends StatelessWidget {
  const DesignNumberControl({
    super.key,
    required this.control,
    required this.design,
    required this.onChanged,
  });
  final CvDesignValue control;
  final DocumentDesign design;
  final ValueChanged<DocumentDesign> onChanged;
  @override
  Widget build(BuildContext context) {
    final value = control
        .read(design)
        .clamp(control.min, control.max)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: UiText(
                  control.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              UiText(
                control.display(value),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  semanticFormatterCallback: control.display,
                  label: control.display(value),
                  value: value,
                  min: control.min,
                  max: control.max,
                  divisions: ((control.max - control.min) / control.step)
                      .round(),
                  onChanged: (next) => onChanged(control.apply(design, next)),
                ),
              ),
              IconButton.outlined(
                tooltip: context.ui('Decrease ${control.label}'),
                onPressed: value <= control.min
                    ? null
                    : () => onChanged(
                        control.apply(design, value - control.step),
                      ),
                icon: const Icon(AppIcons.remove, size: 18),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: context.ui('Increase ${control.label}'),
                onPressed: value >= control.max
                    ? null
                    : () => onChanged(
                        control.apply(design, value + control.step),
                      ),
                icon: const Icon(AppIcons.add, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ContactIconSizeControl extends StatelessWidget {
  const ContactIconSizeControl({
    super.key,
    required this.size,
    required this.enabled,
    required this.onChanged,
  });
  final double size;
  final bool enabled;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 16),
      Row(
        children: [
          const Expanded(child: UiText('Contact icon size')),
          UiText('${size.toStringAsFixed(0)} pt'),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Slider(
              value: size,
              min: 8,
              max: 24,
              divisions: 16,
              label: '${size.round()} pt',
              onChanged: enabled ? onChanged : null,
            ),
          ),
          IconButton.outlined(
            tooltip: context.ui('Decrease contact icon size'),
            onPressed: enabled && size > 8 ? () => onChanged(size - 1) : null,
            icon: const Icon(AppIcons.remove),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: context.ui('Increase contact icon size'),
            onPressed: enabled && size < 24 ? () => onChanged(size + 1) : null,
            icon: const Icon(AppIcons.add),
          ),
        ],
      ),
    ],
  );
}
