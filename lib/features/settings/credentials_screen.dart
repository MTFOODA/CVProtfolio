import '../../core/design/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/domain/profile_models.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/contact_links.dart';
import '../../core/utils/utils.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/app_page_body.dart';
import '../../core/widgets/form_validation.dart';

/// Uses the existing profile schema. A wizard may supply its isolated draft;
/// global Settings instead updates the live profile through the repository.
class CredentialsScreen extends ConsumerStatefulWidget {
  const CredentialsScreen({
    super.key,
    required this.courses,
    this.initialProfile,
    this.onSave,
  });
  final bool courses;
  final UserProfile? initialProfile;
  final Future<void> Function(UserProfile)? onSave;
  @override
  ConsumerState<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends ConsumerState<CredentialsScreen> {
  late UserProfile? _draft = widget.initialProfile;
  bool _busy = false;

  Future<bool> _change(UserProfile Function(UserProfile) update) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final owner = _draft?.id ?? ref.read(sessionProvider2).value?.id;
      if (owner == null || owner != ref.read(sessionProvider2).value?.id) {
        throw StateError('Account changed');
      }
      final current =
          _draft ??
          await ref.read(backendProvider).loadProfile(owner) ??
          UserProfile(id: owner);
      if (!mounted || owner != ref.read(sessionProvider2).value?.id) {
        return false;
      }
      final updated = update(current)
          .copyWith(updatedAtIso: DateTime.now().toIso8601String());
      if (widget.onSave != null) {
        await widget.onSave!(updated);
        _draft = updated;
      } else {
        await ref.read(backendProvider).saveProfile(updated);
        ref.invalidate(profileProvider(owner));
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit({
    CertificateEntry? certificate,
    CourseEntry? course,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CredentialDialog(
        courses: widget.courses,
        certificate: certificate,
        course: course,
        onSave: (data) => _change((profile) {
          if (widget.courses) {
            final entry = CourseEntry(
              id: course?.id ?? newId(),
              name: data.name,
              institution: data.issuer,
              dateRange: data.range,
              credentialUrl: data.url,
              visible: course?.visible ?? true,
            );
            return profile.copyWith(
              courses: [
                for (final old in profile.courses)
                  old.id == entry.id
                      ? entry.copyWith(visible: old.visible)
                      : old,
                if (!profile.courses.any((old) => old.id == entry.id)) entry,
              ],
            );
          }
          final entry = CertificateEntry(
            id: certificate?.id ?? newId(),
            name: data.name,
            issuer: data.issuer,
            dateRange: data.range,
            credentialId: data.credentialId,
            credentialUrl: data.url,
            visible: certificate?.visible ?? true,
          );
          return profile.copyWith(
            certificates: [
              for (final old in profile.certificates)
                old.id == entry.id ? entry.copyWith(visible: old.visible) : old,
              if (!profile.certificates.any((old) => old.id == entry.id)) entry,
            ],
          );
        }),
      ),
    );
  }

  Future<void> _remove(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.tr('delete')),
        content: Text(context.tr('credentialDeleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _change(
      (profile) => widget.courses
          ? profile.copyWith(
              courses: profile.courses.where((e) => e.id != id).toList(),
            )
          : profile.copyWith(
              certificates: profile.certificates
                  .where((e) => e.id != id)
                  .toList(),
            ),
    );
  }

  Future<void> _open(String url) async {
    final valid = contactWebUrl(url);
    if (valid == null) return;
    try {
      if (await launchUrl(
        Uri.parse(valid),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(sessionProvider2).value?.id;
    final asyncProfile = _draft != null || owner == null
        ? AsyncValue<UserProfile?>.data(_draft)
        : ref.watch(profileProvider(owner));
    final profile = _draft ?? asyncProfile.value;
    final entries =
        <
          ({
            String id,
            String name,
            String issuer,
            DateRange range,
            String url,
            bool visible,
            VoidCallback edit,
          })
        >[
          if (widget.courses)
            for (final e in profile?.courses ?? <CourseEntry>[])
              (
                id: e.id,
                name: e.name ?? '',
                issuer: e.institution ?? '',
                range: e.dateRange,
                url: e.credentialUrl ?? '',
                visible: e.visible,
                edit: () => _edit(course: e),
              ),
          if (!widget.courses)
            for (final e in profile?.certificates ?? <CertificateEntry>[])
              (
                id: e.id,
                name: e.name,
                issuer: e.issuer ?? '',
                range: e.dateRange,
                url: e.credentialUrl ?? '',
                visible: e.visible,
                edit: () => _edit(certificate: e),
              ),
        ];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(widget.courses ? 'courses' : 'certificates')),
      ),
      body: AppPageBody(
        child: ListView(
          padding: AppSpacing.pagePadding(context),
          children: [
            if (_draft == null && asyncProfile.isLoading)
              const AppSkeleton()
            else if (_draft == null && asyncProfile.hasError)
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(profileProvider(owner!)),
                  child: Text(context.tr('retry')),
                ),
              )
            else ...[
              Text(
                context.tr('credentialsSubtitle'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  key: const ValueKey('add-credential'),
                  onPressed: _busy || owner == null ? null : () => _edit(),
                  icon: const Icon(AppIcons.add),
                  label: Text(context.tr('add')),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    context.tr('emptySection'),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (var i = 0; i < entries.length; i++)
                AppReveal(
                  index: i,
                  child: Card(
                    key: ValueKey(entries[i].id),
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              widget.courses
                                  ? AppIcons.courses
                                  : AppIcons.certificate,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(entries[i].name),
                            subtitle: Text(
                              [
                                entries[i].issuer,
                                entries[i].range.format(
                                  languageCode: context.languageCode,
                                ),
                              ].where((e) => e.isNotEmpty).join(' · '),
                            ),
                          ),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                tooltip: context.tr('edit'),
                                onPressed: _busy ? null : entries[i].edit,
                                icon: const Icon(AppIcons.edit),
                              ),
                              IconButton(
                                tooltip: context.tr('delete'),
                                onPressed: _busy
                                    ? null
                                    : () => _remove(entries[i].id),
                                icon: const Icon(AppIcons.delete),
                              ),
                              if (contactWebUrl(entries[i].url) != null)
                                IconButton(
                                  tooltip: context.tr('website'),
                                  onPressed: () => _open(entries[i].url),
                                  icon: const Icon(AppIcons.link),
                                ),
                              Switch(
                                value: entries[i].visible,
                                onChanged: _busy
                                    ? null
                                    : (value) => _change(
                                        (profile) => widget.courses
                                            ? profile.copyWith(
                                                courses: [
                                                  for (final e
                                                      in profile.courses)
                                                    e.id == entries[i].id
                                                        ? e.copyWith(
                                                            visible: value,
                                                          )
                                                        : e,
                                                ],
                                              )
                                            : profile.copyWith(
                                                certificates: [
                                                  for (final e
                                                      in profile.certificates)
                                                    e.id == entries[i].id
                                                        ? e.copyWith(
                                                            visible: value,
                                                          )
                                                        : e,
                                                ],
                                              ),
                                      ),
                              ),
                              Text(context.tr('credentialVisible')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CredentialData {
  const _CredentialData(
    this.name,
    this.issuer,
    this.range,
    this.url,
    this.credentialId,
  );
  final String name, issuer, url, credentialId;
  final DateRange range;
}

class _CredentialDialog extends StatefulWidget {
  const _CredentialDialog({
    required this.courses,
    required this.onSave,
    this.certificate,
    this.course,
  });
  final bool courses;
  final CertificateEntry? certificate;
  final CourseEntry? course;
  final Future<bool> Function(_CredentialData) onSave;
  @override
  State<_CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<_CredentialDialog> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  bool _failed = false;
  late final _name = TextEditingController(
    text: widget.certificate?.name ?? widget.course?.name,
  );
  late final _issuer = TextEditingController(
    text: widget.certificate?.issuer ?? widget.course?.institution,
  );
  late final _url = TextEditingController(
    text: widget.certificate?.credentialUrl ?? widget.course?.credentialUrl,
  );
  late final _id = TextEditingController(
    text: widget.certificate?.credentialId,
  );
  late final _start = TextEditingController(
    text:
        widget.certificate?.dateRange.startIso ??
        widget.course?.dateRange.startIso,
  );
  late final _end = TextEditingController(
    text:
        widget.certificate?.dateRange.endIso ?? widget.course?.dateRange.endIso,
  );
  @override
  void dispose() {
    for (final c in [_name, _issuer, _url, _id, _start, _end]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr(widget.courses ? 'courses' : 'certificates')),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    context.tr('errorGeneric'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.tr('credentialTitle'),
                ),
                validator: (v) =>
                    context.validateText(v, required: true, max: 200),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _issuer,
                decoration: InputDecoration(
                  labelText: context.tr('credentialIssuer'),
                ),
                validator: (v) => context.validateText(v, max: 200),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _start,
                decoration: InputDecoration(labelText: context.tr('startDate')),
                validator: (v) => context.validateText(v, max: 80),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _end,
                decoration: InputDecoration(labelText: context.tr('endDate')),
                validator: (v) => context.validateText(v, max: 80),
              ),
              if (!widget.courses) ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _id,
                  decoration: InputDecoration(
                    labelText: context.tr('credentialId'),
                  ),
                  validator: (v) => context.validateText(v, max: 200),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _url,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: context.tr('website')),
                validator: (v) =>
                    (v ?? '').trim().isEmpty || contactWebUrl(v) != null
                    ? null
                    : context.tr('credentialInvalidUrl'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: Text(context.tr('cancel')),
      ),
      FilledButton(
        onPressed: _saving
            ? null
            : () async {
                if (_form.currentState!.validate()) {
                  setState(() {
                    _saving = true;
                    _failed = false;
                  });
                  final saved = await widget.onSave(
                    _CredentialData(
                      _name.text.trim(),
                      _issuer.text.trim(),
                      DateRange(
                        startIso: _start.text.trim(),
                        endIso: _end.text.trim(),
                        isCurrent:
                            widget.certificate?.dateRange.isCurrent ??
                            widget.course?.dateRange.isCurrent ??
                            false,
                      ),
                      _url.text.trim().isEmpty ? '' : contactWebUrl(_url.text)!,
                      _id.text.trim(),
                    ),
                  );
                  if (!mounted || !context.mounted) return;
                  if (saved) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      _saving = false;
                      _failed = true;
                    });
                  }
                }
              },
        child: Text(context.tr(_saving ? 'saving' : 'save')),
      ),
    ],
  );
}
