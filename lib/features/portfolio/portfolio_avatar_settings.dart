import 'package:flutter/material.dart';

import '../../core/domain/document_entity.dart';
import '../../core/domain/document_models.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import 'portfolio_widgets.dart';

class PortfolioAvatarSettings extends StatefulWidget {
  const PortfolioAvatarSettings({
    super.key,
    required this.document,
    required this.busy,
    required this.onSave,
    this.onUpload,
    this.legacyAvatar,
  });
  final CvDocument document;
  final bool busy;
  final ValueChanged<CvDocument> onSave;
  final VoidCallback? onUpload;
  final String? legacyAvatar;
  @override
  State<PortfolioAvatarSettings> createState() =>
      _PortfolioAvatarSettingsState();
}

class _PortfolioAvatarSettingsState extends State<PortfolioAvatarSettings> {
  double? _size;
  @override
  void didUpdateWidget(PortfolioAvatarSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id ||
        oldWidget.document.design.portfolioAvatar.size !=
            widget.document.design.portfolioAvatar.size) {
      _size = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.document.design.portfolioAvatar;
    final size = _size ?? avatar.resolvedSize;
    final path = avatar.path ?? widget.legacyAvatar;
    void saveAvatar(PortfolioAvatarConfig updated) => widget.onSave(
      widget.document.copyWith(
        design: widget.document.design.copyWith(portfolioAvatar: updated),
      ),
    );
    return PortfolioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('portfolioPhoto'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(context.tr('portfolioPhotoHint')),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: SizedBox(
              width: size,
              height: size,
              child: ClipOval(
                child: PortfolioImage(
                  source: avatar.visible ? path : null,
                  ownerId: widget.document.ownerId,
                  decodeWidth: 432,
                  fallback: ColoredBox(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Icon(Icons.person_outline, size: size * .45),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('portfolio-photo-upload'),
                onPressed: widget.busy ? null : widget.onUpload,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(context.tr('uploadPhoto')),
              ),
              if (path?.isNotEmpty == true)
                TextButton(
                  onPressed: widget.busy
                      ? null
                      : () => saveAvatar(avatar.copyWith(path: () => '')),
                  child: Text(context.tr('removePhoto')),
                ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('showPortfolioPhoto')),
            value: avatar.visible,
            onChanged: widget.busy
                ? null
                : (value) => saveAvatar(avatar.copyWith(visible: value)),
          ),
          Text('${context.tr('portfolioPhotoSize')}: ${size.round()} px'),
          Slider(
            key: const ValueKey('portfolio-photo-size'),
            min: 64,
            max: 144,
            divisions: 10,
            value: size,
            label: '${size.round()} px',
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _size = value),
            onChangeEnd: widget.busy
                ? null
                : (value) => saveAvatar(avatar.copyWith(size: value)),
          ),
        ],
      ),
    );
  }
}
