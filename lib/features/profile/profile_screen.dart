import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';

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
  final _links = TextEditingController();

  UserProfile? _existing;
  bool _loading = true;
  bool _saving = false;

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
    super.dispose();
  }

  Future<void> _load() async {
    final user = ref.read(sessionProvider2).value;
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
      _links.text = details.links.join('\n');
      _loading = false;
    });
  }

  Future<void> _save() async {
    final user = ref.read(sessionProvider2).value;
    if (user == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final details = ProfileDetails(
      fullName: _fullName.text.trim(),
      professionalTitle: _title.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      location: _location.text.trim(),
      website: _website.text.trim(),
      summary: _summary.text.trim(),
      links: _links.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );

    final profile = (_existing ?? UserProfile(id: user.id)).copyWith(
      details: details,
      updatedAtIso: DateTime.now().toIso8601String(),
    );

    try {
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
              icon: const Icon(Icons.save_outlined),
              onPressed: _saving ? null : _save,
              tooltip: context.tr('save'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _field(context, 'fullName', _fullName),
                  _field(context, 'professionalTitle', _title),
                  _field(context, 'email', _email, validator: _validateEmail),
                  _field(context, 'phone', _phone),
                  _field(context, 'location', _location),
                  _field(context, 'website', _website),
                  Text(
                    context.tr('summary'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _summary,
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
                  TextFormField(
                    controller: _links,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'https://…'),
                  ),
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
        validator: validator,
        decoration: InputDecoration(labelText: context.tr(labelKey)),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    return ok ? null : context.tr('errorGeneric');
  }
}
