import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/domain/enums.dart';
import '../../core/l10n/app_strings.dart';
import 'portfolio_controller.dart';

class PortfolioCvPicker extends ConsumerWidget {
  const PortfolioCvPicker({super.key, this.busy = false});
  final bool busy;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(sessionProvider2).value?.id;
    if (owner == null) return const SizedBox.shrink();
    final cvs =
        ref
            .watch(documentsProvider(owner))
            .value
            ?.where((d) => d.type == DocumentType.cv)
            .toList() ??
        [];
    if (cvs.isEmpty) return const SizedBox.shrink();
    final selected = ref.watch(portfolioProvider).value?.design.sourceCvId;
    final current =
        cvs.where((cv) => cv.id == selected).firstOrNull ?? cvs.first;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('portfolio-cv:${current.id}'),
        initialValue: current.id,
        isExpanded: true,
        decoration: InputDecoration(labelText: context.tr('portfolioForCv')),
        items: [
          for (final cv in cvs)
            DropdownMenuItem(
              value: cv.id,
              child: Text(
                cv.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: busy
            ? null
            : (value) {
                if (value != null) {
                  ref.read(portfolioCvIdProvider.notifier).select(value);
                }
              },
      ),
    );
  }
}
