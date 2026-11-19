import '../../core/design/app_icons.dart';
import '../../core/widgets/form_validation.dart';

import 'package:flutter/material.dart';

import '../../core/widgets/app_surfaces.dart';

import '../../core/widgets/contact_link_fields.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/core/widgets/app_page_body.dart';

/// Edits the user's professional details, backed by [UserProfile].
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _title = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _website = TextEditingController();
  final _summary = TextEditingController();
  final _links = ContactLinksController();
  final _websiteName = TextEditingController();

  UserProfile? _existing;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _title.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _website.dispose();
    _summary.dispose();
    _links.dispose();
    _websiteName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final user = await ref.read(sessionProvider2.future);
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final profile = await ref.read(backendProvider).loadProfile(user.id);
      if (!mounted) return;
      final details = profile?.details ?? const ProfileDetails();
      setState(() {
        _existing = profile;
        _fullName.text = details.fullName ?? '';
        _title.text = details.professionalTitle ?? '';
        _email.text = details.email ?? '';
        _phone.text = details.phone ?? '';
        _location.text = details.location ?? '';
        _website.text = details.website ?? '';
        _summary.text = details.summary ?? '';
        _links.load(
          details.links.where((url) => url != details.website).toList(),
          details.linkLabels,
        );
        _websiteName.text = details.linkLabels[details.website] ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = context.tr('errorGeneric');
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || _loadError != null) return;
    final user = ref.read(sessionProvider2).value;
    if (user == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final details = (_existing?.details ?? const ProfileDetails()).copyWith(
      fullName: _fullName.text.trim(),
      professionalTitle: _title.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      location: _location.text.trim(),
      website: _website.text.trim(),
      summary: _summary.text.trim(),
      links: _links.urls,
      linkLabels: {
        ..._links.labels,
        if (_website.text.trim().isNotEmpty &&
            _websiteName.text.trim().isNotEmpty)
          _website.text.trim(): _websiteName.text.trim(),
      },
    );

    try {
      // Preserve entries added while the contact form remained open.
      final current =
          await ref.read(backendProvider).loadProfile(user.id) ??
          UserProfile(id: user.id);
      final profile = current.copyWith(
        details: details.copyWith(avatarUrl: current.details.avatarUrl),
        updatedAtIso: DateTime.now().toIso8601String(),
      );
      final saved = await ref.read(backendProvider).saveProfile(profile);
      if (!mounted) return;
      setState(() {
        _existing = saved;
        _saving = false;
      });
      ref.invalidate(profileProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('saved'))));
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('profileDetails')),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            IconButton(
              icon: const Icon(AppIcons.save),
              onPressed: _saving || _loading || _loadError != null
                  ? null
                  : _save,
              tooltip: context.tr('save'),
            ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  TextButton(
                    onPressed: _load,
                    child: Text(context.tr('retry')),
                  ),
                ],
              ),
            )
          : AppPageBody(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: AppSpacing.pagePadding(context),
                  children: [
                    _field(
                      context,
                      'fullName',
                      _fullName,
                      validator: context.validateName,
                    ),
                    _field(
                      context,
                      'professionalTitle',
                      _title,
                      validator: (v) => context.validateText(v, max: 160),
                    ),
                    _field(
                      context,
                      'email',
                      _email,
                      validator: context.validateEmail,
                    ),
                    _field(
                      context,
                      'phone',
                      _phone,
                      validator: context.validatePhone,
                    ),
                    _field(
                      context,
                      'location',
                      _location,
                      validator: context.validateText,
                    ),
                    ContactLinkFields(
                      label: context.tr('website'),
                      url: _website,
                      displayName: _websiteName,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.tr('summary'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _summary,
                      validator: context.validateText,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.tr('summary'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.tr('links'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ContactLinksEditor(controller: _links),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? context.tr('saving') : context.tr('save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(
    BuildContext context,
    String labelKey,
    TextEditingController controller, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        textDirection: {'phone', 'email'}.contains(labelKey)
            ? TextDirection.ltr
            : null,
        keyboardType: labelKey == 'phone'
            ? TextInputType.phone
            : labelKey == 'email'
            ? TextInputType.emailAddress
            : TextInputType.text,
        validator: validator,
        decoration: InputDecoration(labelText: context.tr(labelKey)),
      ),
    );
  }
}
