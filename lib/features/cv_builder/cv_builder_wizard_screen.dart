/// CV Builder Wizard - 8-step form wizard for creating/editing CVs.
library;

import '../../core/design/app_icons.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../core/widgets/form_validation.dart';
import '../../core/widgets/description_items_editor.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/date_range_fields.dart';
import '../../core/widgets/profile_image.dart';
import 'custom_entries_step.dart';
import '../../core/utils/input_validation.dart';
import '../../core/utils/profile_content.dart';
import '../../core/design/templates.dart';

import '../../core/design/skill_icons.dart';
import 'project_entry_dialog.dart';
import 'skill_entry_dialog.dart';

import '../../core/widgets/contact_link_fields.dart';
import '../../core/utils/contact_links.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/core/utils/utils.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';

enum _WizardStep {
  personal,
  experience,
  education,
  projects,
  skills,
  languages,
  customEntries,
  review,
}

class CvBuilderWizardScreen extends ConsumerStatefulWidget {
  final String? documentId;
  const CvBuilderWizardScreen({super.key, this.documentId, this.active = true});
  final bool active;
  @override
  ConsumerState<CvBuilderWizardScreen> createState() =>
      _CvBuilderWizardScreenState();
}

class _CvBuilderWizardScreenState extends ConsumerState<CvBuilderWizardScreen> {
  _WizardStep _currentStep = _WizardStep.personal;
  bool _loading = true;
  bool _saving = false;

  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _websiteController = TextEditingController();
  final _summaryController = TextEditingController();
  final _linkedinName = TextEditingController();
  final _githubName = TextEditingController();
  final _websiteName = TextEditingController();
  final _personalForm = GlobalKey<FormState>();
  Set<String> _editedLinks = {};

  UserProfile? _profile;
  // Keep the original merge baseline until updating the shared profile succeeds.
  // The document write can succeed independently of that second write.
  UserProfile? _profileMergeBaseline;
  bool _profileSyncPending = false;
  CvDocument? _document;
  LocalBackendOrSupabase? _backend;
  Timer? _draftTimer;
  bool _hydrating = true;
  bool _hasDraftChanges = false;
  bool _draftDirty = false;
  bool _leaving = false;
  Future<void> _draftWrites = Future.value();
  String? _loadError;
  String get _draftKey => widget.documentId ?? 'new';
  List<TextEditingController> get _controllers => [
    _nameController,
    _titleController,
    _emailController,
    _phoneController,
    _locationController,
    _linkedinController,
    _githubController,
    _websiteController,
    _summaryController,
    _linkedinName,
    _githubName,
    _websiteName,
  ];

  void _draftChanged() {
    if (_hydrating || _loading || _leaving) return;
    _hasDraftChanges = true;
    _draftDirty = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        await _saveDraft();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('draftSaveFailed'))),
          );
        }
      }
    });
  }

  Future<void> _saveDraft() {
    _draftTimer?.cancel();
    final backend = _backend;
    final profile = _profile;
    if (backend == null || profile == null || _hydrating || !_hasDraftChanges) {
      return Future.value();
    }
    if (!_draftDirty) return _draftWrites;
    _draftDirty = false;
    final draft = CvBuilderDraft(
      profile: _captureProfile(),
      step: _currentStep.index,
      profileSyncPending: _profileSyncPending,
      pendingDocumentId: _profileSyncPending ? _document?.id : null,
      profileMergeBaseline: _profileMergeBaseline,
    );
    final write = _draftWrites
        .catchError((Object _) {})
        .then((_) => backend.saveCvDraft(profile.id, _draftKey, draft));
    _draftWrites = write.catchError((Object error, StackTrace stack) {
      _draftDirty = true;
      Error.throwWithStackTrace(error, stack);
    });
    return _draftWrites;
  }

  Future<void> _home() async {
    if (_saving || _leaving) return;
    setState(() => _saving = true);
    try {
      await _saveDraft();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('draftSaveFailed'))));
      }
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    ref.read(dashboardTabProvider.notifier).select(0);
    context.go('/');
    // The embedded builder remains mounted in the dashboard's IndexedStack.
    if (mounted) {
      setState(() {
        _leaving = false;
        _saving = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_draftChanged);
    }
    _load();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (_hasDraftChanges && !_hydrating && !_saving) {
      unawaited(_saveDraft().catchError((Object _) {}));
    }
    _nameController.dispose();
    _titleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _websiteController.dispose();
    _summaryController.dispose();
    _linkedinName.dispose();
    _githubName.dispose();
    _websiteName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // The dashboard builds this screen (as a tab) before the restored session
    // is necessarily available, so wait for it instead of giving up on the
    // first frame and leaving the wizard on a permanent spinner.
    final user = await ref.read(sessionProvider2.future);
    if (!mounted) return;
    final userId = user?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _backend = ref.read(backendProvider);
    try {
      if (widget.documentId != null) {
        _document = await _backend!.loadDocument(widget.documentId!, userId);
        if (_document == null) throw StateError('Document unavailable');
      }
      final draft = await _backend!.loadCvDraft(userId, _draftKey);
      _profileSyncPending = draft?.profileSyncPending ?? false;
      if (_profileSyncPending && draft?.pendingDocumentId != null) {
        if (widget.documentId != null &&
            widget.documentId != draft!.pendingDocumentId) {
          throw StateError('Draft document mismatch');
        }
        _document = await _backend!.loadDocument(
          draft!.pendingDocumentId!,
          userId,
        );
        if (_document == null) throw StateError('Pending document unavailable');
      }
      _profileMergeBaseline = _profileSyncPending
          ? draft?.profileMergeBaseline
          : widget.documentId == null
          ? null
          : _document!.profileSnapshot ?? await _backend!.loadProfile(userId);
      _profile =
          draft?.profile ??
          (widget.documentId == null
              ? UserProfile(id: userId)
              : _profileMergeBaseline ?? UserProfile(id: userId));
      if (draft != null) {
        _currentStep = _WizardStep
            .values[draft.step.clamp(0, _WizardStep.values.length - 1)];
        _hasDraftChanges = true;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = context.tr('errorGeneric');
          _loading = false;
        });
      }
      return;
    }
    if (_profile != null) {
      final details = _profile!.details;
      _nameController.text = details.fullName ?? '';
      _titleController.text = details.professionalTitle ?? '';
      _emailController.text = details.email ?? '';
      _phoneController.text = details.phone ?? '';
      _locationController.text = details.location ?? '';
      _linkedinController.text =
          details.links
              .where((url) => contactLinkKind(url) == 'LinkedIn')
              .firstOrNull ??
          '';
      _githubController.text =
          details.links
              .where((url) => contactLinkKind(url) == 'GitHub')
              .firstOrNull ??
          '';
      _websiteController.text =
          details.website ??
          details.links
              .where((url) => contactLinkKind(url) == 'Link')
              .firstOrNull ??
          '';
      _linkedinName.text = details.linkLabels[_linkedinController.text] ?? '';
      _githubName.text = details.linkLabels[_githubController.text] ?? '';
      _websiteName.text = details.linkLabels[_websiteController.text] ?? '';
      _editedLinks = {
        _linkedinController.text,
        _githubController.text,
        _websiteController.text,
      }..remove('');
      _summaryController.text = details.summary ?? '';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hydrating = false;
    });
  }

  UserProfile _captureProfile() {
    final userId = _profile!.id;
    final links = <String>[
      ...?_profile?.details.links.where((url) => !_editedLinks.contains(url)),
    ];
    if (_linkedinController.text.trim().isNotEmpty) {
      links.add(_linkedinController.text.trim());
    }
    if (_githubController.text.trim().isNotEmpty) {
      links.add(_githubController.text.trim());
    }
    if (_websiteController.text.trim().isNotEmpty) {
      links.add(_websiteController.text.trim());
    }
    final labels =
        {
          ...?_profile?.details.linkLabels,
          for (final pair in [
            (_linkedinController, _linkedinName),
            (_githubController, _githubName),
            (_websiteController, _websiteName),
          ])
            pair.$1.text.trim(): pair.$2.text.trim(),
        }..removeWhere(
          (url, label) => !links.contains(url) || label.trim().isEmpty,
        );
    final details = ProfileDetails(
      avatarUrl: _profile?.details.avatarUrl,
      linkLabels: labels,
      fullName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
      professionalTitle: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      website: _websiteController.text.trim().isNotEmpty
          ? _websiteController.text.trim()
          : null,
      summary: _summaryController.text.trim().isNotEmpty
          ? _summaryController.text.trim()
          : null,
      links: links,
    );
    final profile = _profile ?? UserProfile(id: userId);
    return profile.copyWith(
      details: details,
      updatedAtIso: DateTime.now().toIso8601String(),
    );
  }

  Future<void> _saveProfile() async {
    _profile = _captureProfile();
    _hasDraftChanges = true;
    _draftDirty = true;
    await _saveDraft();
  }

  Future<void> _saveDocument() async {
    final userId = ref.read(sessionProvider2).value?.id;
    if (userId == null) return;
    final now = DateTime.now().toIso8601String();
    final previousSnapshot = _profileMergeBaseline;
    final details = _profile!.details;
    final invalid =
        InputValidation.name(details.fullName) ??
        InputValidation.text(details.professionalTitle, max: 160) ??
        InputValidation.text(details.summary) ??
        InputValidation.email(details.email) ??
        InputValidation.phone(details.phone);
    if (invalid != null) {
      setState(() => _currentStep = _WizardStep.personal);
      _draftChanged();
      throw FormatException(context.tr(invalid));
    }
    final document =
        _document ??
        CvDocument(
          id: widget.documentId ?? newId(),
          ownerId: userId,
          title: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : 'My CV',
          type: DocumentType.cv,
          isRtl: RegExp(r'[\u0620-\u064A]').hasMatch(_nameController.text),
          design: designForTemplate('minimal', DocumentType.cv).copyWith(
            isRtl: RegExp(r'[\u0620-\u064A]').hasMatch(_nameController.text),
          ),
          createdAtIso: now,
          updatedAtIso: now,
        );
    final saved = await ref
        .read(backendProvider)
        .saveDocument(
          document.copyWith(
            title: _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : document.title,
            updatedAtIso: () => now,
            profileSnapshot: _profile,
            design: withProfileCustomSections(document.design, _profile!),
            version: document.version + 1,
          ),
        );
    if (!mounted) return;
    setState(() => _document = saved);
    // Journal the completed first write before syncing the shared profile.
    // A reopened builder can retry the same document with the original delta.
    _profileSyncPending = true;
    _draftDirty = true;
    await _saveDraft();
    final currentProfile =
        await _backend!.loadProfile(userId) ?? UserProfile(id: userId);
    await _backend!.saveProfile(
      mergeCvIntoProfile(currentProfile, _profile!, previous: previousSnapshot),
    );
    _profileMergeBaseline = _profile;
    _profileSyncPending = false;
    await _draftWrites.catchError((Object _) {});
    await _backend!.deleteCvDraft(userId, _draftKey);
    _hasDraftChanges = false;
    _draftDirty = false;
    ref.invalidate(profileProvider(userId));
    ref.invalidate(documentsProvider);
  }

  void _nextStep() {
    if (_currentStep.index < _WizardStep.values.length - 1) {
      setState(() => _currentStep = _WizardStep.values[_currentStep.index + 1]);
      _draftChanged();
    }
  }

  void _prevStep() {
    if (_currentStep.index > 0) {
      setState(() => _currentStep = _WizardStep.values[_currentStep.index - 1]);
      _draftChanged();
    }
  }

  void _skipToReview() {
    if (!(_personalForm.currentState?.validate() ?? true)) return;
    _profile = _captureProfile();
    setState(() => _currentStep = _WizardStep.review);
    _draftChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: AppLoading());
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              ref.read(dashboardTabProvider.notifier).select(0);
              context.go('/');
            },
            icon: const Icon(AppIcons.back),
          ),
        ),
        body: Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _loadError = null;
              });
              _load();
            },
            child: Text(context.tr('retry')),
          ),
        ),
      );
    }
    return PopScope(
      canPop: !widget.active || _leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.active) _home();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _currentStep == _WizardStep.review
                ? context.tr('stepReview')
                : context.tr('wizard'),
          ),
          leading: IconButton(
            tooltip: context.tr('home'),
            icon: const Icon(AppIcons.back),
            onPressed: _saving ? null : _home,
          ),
          actions: [
            if (_currentStep != _WizardStep.review)
              TextButton(
                onPressed: _skipToReview,
                child: Text(context.tr('skip')),
              ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentStep.index + 1) / _WizardStep.values.length,
                minHeight: 4,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.pagePadding(context),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSpacing.formWidth,
                      ),
                      child: AppContentTransition(
                        identity: _currentStep,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stepLabel(context),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            UiText(
                              _stepSubtitle(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _buildStepContent(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    if (_currentStep != _WizardStep.personal)
                      OutlinedButton(
                        onPressed: _saving ? null : _prevStep,
                        child: Text(context.tr('back')),
                      ),
                    const Spacer(),
                    if (_currentStep != _WizardStep.review)
                      FilledButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                if (!(_personalForm.currentState?.validate() ??
                                    true)) {
                                  return;
                                }
                                final messenger = ScaffoldMessenger.of(context);
                                final errorMessage = context.tr('errorGeneric');
                                setState(() => _saving = true);
                                try {
                                  await _saveProfile();
                                  if (mounted) {
                                    _nextStep();
                                    setState(() => _saving = false);
                                  }
                                } catch (_) {
                                  if (!mounted) return;
                                  setState(() => _saving = false);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(errorMessage)),
                                  );
                                }
                              },
                        child: Text(context.tr('continue')),
                      )
                    else
                      FilledButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                final router = GoRouter.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                final savedMessage = context.tr('wizardSaved');
                                final failedMessage = context.tr(
                                  'errorGeneric',
                                );
                                setState(() => _saving = true);
                                try {
                                  await _saveProfile();
                                  await _saveDocument();
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(savedMessage)),
                                  );
                                  // Open the generated document so the user can
                                  // review it and export PDF/DOCX immediately.
                                  final documentId = _document?.id;
                                  if (widget.documentId == null && mounted) {
                                    _hydrating = true;
                                    _draftTimer?.cancel();
                                    for (final controller in _controllers) {
                                      controller.clear();
                                    }
                                    setState(() {
                                      _document = null;
                                      _profileMergeBaseline = null;
                                      _profileSyncPending = false;
                                      _profile = UserProfile(id: _profile!.id);
                                      _currentStep = _WizardStep.personal;
                                      _editedLinks = {};
                                    });
                                    _hydrating = false;
                                  }
                                  if (documentId != null) {
                                    router.push('/doc/$documentId');
                                  } else {
                                    router.go('/');
                                  }
                                } catch (error) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          error is FormatException
                                              ? error.message
                                              : failedMessage,
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _saving = false);
                                }
                              },
                        child: Text(context.tr('generateCv')),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stepLabel(BuildContext context) {
    switch (_currentStep) {
      case _WizardStep.personal:
        return context.tr('stepPersonal');
      case _WizardStep.experience:
        return context.tr('stepExperience');
      case _WizardStep.education:
        return context.tr('stepEducation');
      case _WizardStep.projects:
        return context.tr('stepProjects');
      case _WizardStep.skills:
        return context.tr('stepSkills');
      case _WizardStep.languages:
        return context.tr('stepLanguages');
      case _WizardStep.customEntries:
        return context.tr('customEntries');
      case _WizardStep.review:
        return context.tr('stepReview');
    }
  }

  String _stepSubtitle() {
    switch (_currentStep) {
      case _WizardStep.experience:
        return 'Add your work history';
      case _WizardStep.education:
        return 'Add your educational background';
      case _WizardStep.projects:
        return 'Showcase your projects';
      case _WizardStep.skills:
        return 'List your skills and proficiency';
      case _WizardStep.languages:
        return 'Add languages you speak';
      case _WizardStep.customEntries:
        return context.tr('customEntriesSubtitle');
      case _WizardStep.review:
        return 'Review all sections before generating';
      default:
        return '';
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case _WizardStep.personal:
        return _buildPersonalInfoStep();
      case _WizardStep.experience:
        return _buildExperienceStep();
      case _WizardStep.education:
        return _buildEducationStep();
      case _WizardStep.projects:
        return _buildProjectsStep();
      case _WizardStep.skills:
        return _buildSkillsStep();
      case _WizardStep.languages:
        return _buildLanguagesStep();
      case _WizardStep.customEntries:
        return CustomEntriesStep(
          profile: _profile!,
          mediaRepository: _backend!,
          onSave: _persistEntries,
        );
      case _WizardStep.review:
        return _buildReviewStep();
    }
  }

  Widget _buildPersonalInfoStep() {
    return Form(
      key: _personalForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            validator: context.validateName,
            decoration: InputDecoration(
              labelText: context.tr('fullName'),
              hintText: context.tr('fullNamePlaceholder'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _titleController,
            validator: (v) => context.validateText(v, max: 160),
            decoration: InputDecoration(
              labelText: context.tr('professionalTitle'),
              hintText: context.ui('Software Engineer'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _emailController,
            validator: context.validateEmail,
            decoration: InputDecoration(
              labelText: context.tr('email'),
              hintText: context.tr('emailPlaceholder'),
            ),
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _phoneController,
            validator: context.validatePhone,
            decoration: InputDecoration(
              labelText: context.tr('phone'),
              hintText: '+1 234 567 8900',
            ),
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _locationController,
            validator: (v) => context.validateText(v, max: 200),
            decoration: InputDecoration(
              labelText: context.tr('location'),
              hintText: context.ui('City, Country'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('links'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ContactLinkFields(
            label: 'LinkedIn',
            url: _linkedinController,
            displayName: _linkedinName,
            hint: 'https://linkedin.com/in/username',
          ),
          const SizedBox(height: AppSpacing.sm),
          ContactLinkFields(
            label: 'GitHub',
            url: _githubController,
            displayName: _githubName,
            hint: 'https://github.com/username',
          ),
          const SizedBox(height: AppSpacing.sm),
          ContactLinkFields(
            label: 'Website',
            url: _websiteController,
            displayName: _websiteName,
            hint: 'https://yourwebsite.com',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('summary'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _summaryController,
            validator: context.validateText,
            maxLines: 4,
            decoration: InputDecoration(hintText: context.tr('summary')),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceStep() {
    // The empty fallback must be typed: `?? []` would infer List<dynamic>, and
    // a dynamic `exp` cannot resolve the DateRange formatting extension.
    final experiences = _profile?.experiences ?? const <ExperienceEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (experiences.isEmpty)
          _EmptyState(
            icon: AppIcons.portfolio,
            title: 'No experience yet',
            subtitle: context.tr('addExperience'),
          ),
        ...List.generate(experiences.length, (index) {
          final exp = experiences[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.compact,
              ),
              onTap: () => _editExperience(index),
              title: Text(exp.position ?? ''),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exp.company ?? ''),
                  Text(
                    exp.dateRange.format(languageCode: context.languageCode),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(AppIcons.delete),
                onPressed: () => _deleteExperience(index),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: _addExperience,
          icon: const Icon(AppIcons.add),
          label: Text(context.tr('addExperience')),
        ),
      ],
    );
  }

  Widget _buildEducationStep() {
    final education = _profile?.education ?? const <EducationEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (education.isEmpty)
          _EmptyState(
            icon: AppIcons.education,
            title: 'No education yet',
            subtitle: context.tr('addEducation'),
          ),
        ...List.generate(education.length, (index) {
          final edu = education[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.compact,
              ),
              title: Text(edu.qualification ?? ''),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(edu.institution ?? ''),
                  Text(
                    edu.dateRange.format(languageCode: context.languageCode),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(AppIcons.delete),
                onPressed: () => _deleteEducation(index),
              ),
              onTap: () => _editEducation(index),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: _addEducation,
          icon: const Icon(AppIcons.add),
          label: Text(context.tr('addEducation')),
        ),
      ],
    );
  }

  Widget _buildProjectsStep() {
    final projects = _profile?.projects ?? const <ProjectEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (projects.isEmpty)
          _EmptyState(
            icon: AppIcons.projects,
            title: context.tr('noProjects'),
            subtitle: context.tr('addFirstProject'),
          ),
        ...List.generate(projects.length, (index) {
          final project = projects[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.compact,
              ),
              title: Text(project.title ?? ''),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!project.dateRange.isEmpty)
                    Text(
                      project.dateRange.format(
                        languageCode: context.languageCode,
                      ),
                    ),
                  if ((project.summary ?? '').trim().isNotEmpty)
                    Text(project.summary!),
                  if (project.technologies.isNotEmpty)
                    Text(
                      project.technologies.join(', '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(AppIcons.delete),
                onPressed: () => _deleteProject(index),
              ),
              onTap: () => _editProject(index),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: _addProject,
          icon: const Icon(AppIcons.add),
          label: Text(context.tr('addProject')),
        ),
      ],
    );
  }

  Widget _buildSkillsStep() {
    final skills = _profile?.skills ?? const <SkillEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (skills.isEmpty)
          _EmptyState(
            icon: AppIcons.skills,
            title: 'No skills yet',
            subtitle: context.tr('addSkill'),
          ),
        ...List.generate(skills.length, (index) {
          final skill = skills[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.compact,
              ),
              leading: SkillIconView(skill.iconId),
              onTap: () => _showSkill(index: index),
              title: Text(skill.name ?? ''),
              subtitle: Text(
                proficiencyLabel(
                  skill.proficiency,
                  languageCode: context.languageCode,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(AppIcons.delete),
                onPressed: () => _deleteSkill(index),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: _addSkill,
          icon: const Icon(AppIcons.add),
          label: Text(context.tr('addSkill')),
        ),
      ],
    );
  }

  Widget _buildLanguagesStep() {
    final languages = _profile?.languages ?? const <LanguageEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (languages.isEmpty)
          _EmptyState(
            icon: AppIcons.language,
            title: 'No languages yet',
            subtitle: context.tr('addLanguage'),
          ),
        ...List.generate(languages.length, (index) {
          final lang = languages[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.compact,
              ),
              title: Text(lang.name),
              subtitle: Text(
                proficiencyLabel(
                  lang.proficiency,
                  languageCode: context.languageCode,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(AppIcons.delete),
                onPressed: () => _deleteLanguage(index),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: _addLanguage,
          icon: const Icon(AppIcons.add),
          label: Text(context.tr('addLanguage')),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final profile = _profile;

    // Explicit element types are essential here: `?? []` would make the loop
    // variables `dynamic`, and dynamic dispatch cannot see the DateRange
    // formatting extension, which is exactly the crash this guards against.
    final experiences = profile?.experiences ?? const <ExperienceEntry>[];
    final education = profile?.education ?? const <EducationEntry>[];
    final skills = profile?.skills ?? const <SkillEntry>[];
    final languages = profile?.languages ?? const <LanguageEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewSectionCard(
          title: context.tr('stepPersonal'),
          icon: AppIcons.person,
          children: [
            if (profile?.details.fullName != null)
              _ReviewRow(
                label: context.tr('fullName'),
                value: profile!.details.fullName!,
              ),
            if (profile?.details.professionalTitle != null)
              _ReviewRow(
                label: context.tr('professionalTitle'),
                value: profile!.details.professionalTitle!,
              ),
            if (profile?.details.email != null)
              _ReviewRow(
                label: context.tr('email'),
                value: profile!.details.email!,
              ),
            if (profile?.details.phone != null)
              _ReviewRow(
                label: context.tr('phone'),
                value: profile!.details.phone!,
              ),
            if (profile?.details.location != null)
              _ReviewRow(
                label: context.tr('location'),
                value: profile!.details.location!,
              ),
            if (profile?.details.summary != null)
              _ReviewRow(
                label: context.tr('summary'),
                value: profile!.details.summary!,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewSectionCard(
          title: context.tr('stepExperience'),
          icon: AppIcons.portfolio,
          children: [
            for (final exp in experiences)
              _ReviewRow(
                label: exp.position ?? '',
                value:
                    '${exp.company} · ${exp.dateRange.format(languageCode: context.languageCode)}',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewSectionCard(
          title: context.tr('stepEducation'),
          icon: AppIcons.education,
          children: [
            for (final edu in education)
              _ReviewRow(
                label: edu.qualification ?? '',
                value:
                    '${edu.institution} · ${edu.dateRange.format(languageCode: context.languageCode)}',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewSectionCard(
          title: context.tr('stepProjects'),
          icon: AppIcons.projects,
          children: [
            for (final project in profile?.projects ?? <ProjectEntry>[])
              _ReviewRow(
                label: project.title ?? '',
                value: [
                  project.summary ?? '',
                  project.dateRange.format(languageCode: context.languageCode),
                  project.technologies.join(', '),
                  project.demoUrl ?? '',
                  project.sourceUrl ?? '',
                ].where((value) => value.isNotEmpty).join('\n'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewSectionCard(
          title: context.tr('stepSkills'),
          icon: AppIcons.skills,
          children: [
            for (final skill in skills)
              _ReviewRow(
                label: skill.name ?? '',
                value: proficiencyLabel(
                  skill.proficiency,
                  languageCode: context.languageCode,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewSectionCard(
          title: context.tr('stepLanguages'),
          icon: AppIcons.language,
          children: [
            for (final lang in languages)
              _ReviewRow(
                label: lang.name,
                value: proficiencyLabel(
                  lang.proficiency,
                  languageCode: context.languageCode,
                ),
              ),
          ],
        ),
        for (final section in profile?.customSections ?? <CustomSection>[]) ...[
          const SizedBox(height: AppSpacing.md),
          _ReviewSectionCard(
            title: section.title,
            icon: AppIcons.viewAgenda,
            children: [
              for (final entry in section.entries.where(
                (entry) => entry.visible,
              )) ...[
                _ReviewRow(
                  label: entry.title,
                  value: [
                    entry.formatMetadata(languageCode: context.languageCode),
                    entry.content ?? '',
                    entry.url ?? '',
                  ].where((value) => value.isNotEmpty).join('\n'),
                ),
                if ((entry.imageUrl ?? '').isNotEmpty)
                  SizedBox(
                    height: 120,
                    child: PortfolioImage(
                      source: entry.imageUrl,
                      ownerId: profile!.id,
                      fit: BoxFit.contain,
                      fallback: const SizedBox.shrink(),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  void _addExperience() {
    showDialog(
      context: context,
      builder: (dialogContext) => _ExperienceEntryDialog(
        onSave: (entry) {
          final list = <ExperienceEntry>[...?(_profile?.experiences), entry];
          _updateProfileExperiences(list);
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _editExperience(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ExperienceEntryDialog(
        initial: _profile!.experiences[index],
        onSave: (entry) {
          final entries = [..._profile!.experiences];
          entries[index] = entry;
          _updateProfileExperiences(entries);
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _deleteExperience(int index) {
    final list = <ExperienceEntry>[...?(_profile?.experiences)];
    list.removeAt(index);
    _updateProfileExperiences(list);
  }

  void _updateProfileExperiences(List<ExperienceEntry> experiences) {
    if (_profile == null) return;
    setState(() => _profile = _profile!.copyWith(experiences: experiences));
    _draftChanged();
  }

  void _addEducation() {
    showDialog(
      context: context,
      builder: (dialogContext) => _EducationEntryDialog(
        onSave: (entry) {
          final list = <EducationEntry>[
            ...?(_profile?.education),
            entry.copyWith(id: newId()),
          ];
          _updateProfileEducation(list);
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _editEducation(int index) {
    final education = <EducationEntry>[...?(_profile?.education)];
    if (index < 0 || index >= education.length) return;
    final existing = education[index];
    showDialog(
      context: context,
      builder: (dialogContext) => _EducationEntryDialog(
        initial: existing,
        onSave: (entry) {
          education[index] = entry.copyWith(id: existing.id);
          _updateProfileEducation(education);
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _updateProfileEducation(List<EducationEntry> education) {
    if (_profile == null) return;
    setState(() => _profile = _profile!.copyWith(education: education));
    _draftChanged();
  }

  void _deleteEducation(int index) {
    final list = <EducationEntry>[...?(_profile?.education)];
    list.removeAt(index);
    _updateProfileEducation(list);
  }

  void _addProject() => _showProject();

  void _editProject(int index) => _showProject(index: index);

  void _showProject({int? index}) {
    final profile = _profile;
    if (profile == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProjectEntryDialog(
        initial: index == null ? null : profile.projects[index],
        ownerId: profile.id,
        mediaRepository: ref.read(backendProvider),
        onSave: (entry) async {
          final projects = [..._profile!.projects];
          if (index == null) {
            projects.add(entry);
          } else {
            projects[index] = entry;
          }
          await _persistEntries(_profile!.copyWith(projects: projects));
        },
      ),
    );
  }

  Future<void> _persistEntries(UserProfile updated) async {
    if (!mounted || ref.read(sessionProvider2).value?.id != updated.id) {
      throw StateError('Account changed');
    }
    final previous = _profile;
    setState(() => _profile = updated);
    _hasDraftChanges = true;
    _draftDirty = true;
    try {
      await _saveDraft();
    } catch (_) {
      if (mounted) setState(() => _profile = previous);
      rethrow;
    }
  }

  Future<void> _deleteProject(int index) async {
    final projects = [..._profile!.projects]..removeAt(index);
    try {
      await _persistEntries(_profile!.copyWith(projects: projects));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: UiText('Could not remove project. Please retry.'),
          ),
        );
      }
    }
  }

  void _addSkill() => _showSkill();

  void _showSkill({int? index}) {
    final profile = _profile;
    if (profile == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SkillEntryDialog(
        initial: index == null ? null : profile.skills[index],
        existingSkills: [
          for (var i = 0; i < profile.skills.length; i++)
            if (i != index) profile.skills[i].name ?? '',
        ],
        onSave: (entry) async {
          final skills = [..._profile!.skills];
          if (index == null) {
            skills.add(entry);
          } else {
            skills[index] = entry;
          }
          await _persistEntries(_profile!.copyWith(skills: skills));
        },
      ),
    );
  }

  Future<void> _deleteSkill(int index) async {
    final skills = [..._profile!.skills]..removeAt(index);
    try {
      await _persistEntries(_profile!.copyWith(skills: skills));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: UiText('Could not remove skill. Please retry.'),
          ),
        );
      }
    }
  }

  void _addLanguage() {
    showDialog(
      context: context,
      builder: (dialogContext) => _LanguageEntryDialog(
        onSave: (name, level) {
          final list = <LanguageEntry>[
            ...?(_profile?.languages),
            LanguageEntry(id: newId(), name: name, proficiency: level),
          ];
          _updateProfileLanguages(list);
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _updateProfileLanguages(List<LanguageEntry> languages) {
    if (_profile == null) return;
    setState(() => _profile = _profile!.copyWith(languages: languages));
    _draftChanged();
  }

  void _deleteLanguage(int index) {
    final list = <LanguageEntry>[...?(_profile?.languages)];
    list.removeAt(index);
    _updateProfileLanguages(list);
  }
}

/// Empty state widget with icon, title and helper text.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            UiText(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            UiText(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A card used in the review step to group one section.
class _ReviewSectionCard extends StatelessWidget {
  const _ReviewSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A label/value row inside [_ReviewSectionCard].
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.compact),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final name = Text(label, style: Theme.of(context).textTheme.bodySmall);
        final content = Text(value);
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              name,
              const SizedBox(height: AppSpacing.sm),
              content,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 180, child: name),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: content),
          ],
        );
      },
    ),
  );
}

/// Dialog for adding a professional experience entry.
class _ExperienceEntryDialog extends StatefulWidget {
  const _ExperienceEntryDialog({this.initial, required this.onSave});
  final ExperienceEntry? initial;

  final void Function(ExperienceEntry) onSave;

  @override
  State<_ExperienceEntryDialog> createState() => _ExperienceEntryDialogState();
}

class _ExperienceEntryDialogState extends State<_ExperienceEntryDialog> {
  late final _positionController = TextEditingController(
    text: widget.initial?.position,
  );
  late final _companyController = TextEditingController(
    text: widget.initial?.company,
  );
  late final _locationController = TextEditingController(
    text: widget.initial?.location,
  );
  final _descriptionEditor = GlobalKey<DescriptionItemsEditorState>();
  late List<DescriptionItem> _descriptionItems = [
    ...?widget.initial?.resolvedDescriptions,
  ];
  late DateRange _range = widget.initial?.dateRange ?? const DateRange();

  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _positionController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('addExperience')),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _positionController,
                validator: (v) =>
                    context.validateText(v, required: true, max: 160),
                decoration: InputDecoration(labelText: context.ui('Position')),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _companyController,
                validator: (v) =>
                    context.validateText(v, required: true, max: 160),
                decoration: InputDecoration(labelText: context.ui('Company')),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _locationController,
                validator: (v) => context.validateText(v, max: 200),
                decoration: InputDecoration(labelText: context.ui('Location')),
              ),
              const SizedBox(height: AppSpacing.md),
              DescriptionItemsEditor(
                key: _descriptionEditor,
                items: _descriptionItems,
                onChanged: (items) => setState(() => _descriptionItems = items),
              ),
              const SizedBox(height: AppSpacing.md),
              DateRangeFields(
                value: _range,
                onChanged: (value) => _range = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            if (!(_descriptionEditor.currentState?.commitPending() ?? true)) {
              return;
            }
            widget.onSave(
              (widget.initial ?? ExperienceEntry(id: newId())).copyWith(
                position: _positionController.text.trim(),
                company: _companyController.text.trim(),
                location: _locationController.text.trim(),
                dateRange: _range,
                descriptions: _descriptionItems
                    .map((e) => e.formatted)
                    .toList(),
                descriptionItems: _descriptionItems,
              ),
            );
          },
          child: Text(context.tr('add')),
        ),
      ],
    );
  }
}

/// Dialog for adding a skill with proficiency, rejecting duplicates.
/// Dialog for adding a language with CEFR / native proficiency.
class _LanguageEntryDialog extends StatefulWidget {
  const _LanguageEntryDialog({required this.onSave});

  final void Function(String, int) onSave;

  @override
  State<_LanguageEntryDialog> createState() => _LanguageEntryDialogState();
}

class _LanguageEntryDialogState extends State<_LanguageEntryDialog> {
  final _nameController = TextEditingController();
  int _level = 1;

  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('addLanguage')),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                validator: (v) =>
                    context.validateText(v, required: true, max: 100),
                decoration: InputDecoration(
                  labelText: context.ui('Language name'),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _level,
                items: [
                  const DropdownMenuItem(value: 1, child: UiText('A1')),
                  const DropdownMenuItem(value: 2, child: UiText('A2')),
                  const DropdownMenuItem(value: 3, child: UiText('B1')),
                  const DropdownMenuItem(value: 4, child: UiText('B2')),
                  const DropdownMenuItem(value: 5, child: UiText('C1')),
                  const DropdownMenuItem(value: 6, child: UiText('C2')),
                  DropdownMenuItem(value: 7, child: Text(context.tr('native'))),
                ],
                onChanged: (v) => setState(() => _level = v ?? 1),
                decoration: InputDecoration(
                  labelText: context.ui('Proficiency'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            final name = _nameController.text.trim();
            if (name.isNotEmpty) widget.onSave(name, _level);
          },
          child: Text(context.tr('add')),
        ),
      ],
    );
  }
}

/// Dialog for adding or editing an education entry.
class _EducationEntryDialog extends StatefulWidget {
  const _EducationEntryDialog({this.initial, required this.onSave});

  final EducationEntry? initial;
  final void Function(EducationEntry) onSave;

  @override
  State<_EducationEntryDialog> createState() => _EducationEntryDialogState();
}

class _EducationEntryDialogState extends State<_EducationEntryDialog> {
  late DateRange _range = widget.initial?.dateRange ?? const DateRange();
  late final TextEditingController _institution;
  late final TextEditingController _qualification;
  late final TextEditingController _field;
  late final TextEditingController _grade;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _institution = TextEditingController(text: initial?.institution ?? '');
    _qualification = TextEditingController(text: initial?.qualification ?? '');
    _field = TextEditingController(text: initial?.fieldOfStudy ?? '');
    _grade = TextEditingController(text: initial?.grade ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
  }

  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _institution.dispose();
    _qualification.dispose();
    _field.dispose();
    _grade.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('addEducation')),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _institution,
                validator: (v) =>
                    context.validateText(v, required: true, max: 200),
                decoration: InputDecoration(
                  labelText: context.tr('institution'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _qualification,
                validator: (v) => context.validateText(v, max: 160),
                decoration: InputDecoration(
                  labelText: context.tr('qualification'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _field,
                validator: (v) => context.validateText(v, max: 160),
                decoration: InputDecoration(
                  labelText: context.tr('fieldOfStudy'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _grade,
                validator: (v) =>
                    context.validationMessage(InputValidation.grade(v)),
                decoration: InputDecoration(labelText: context.tr('grade')),
              ),
              const SizedBox(height: AppSpacing.md),
              DateRangeFields(
                value: _range,
                onChanged: (value) => _range = value,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _description,
                validator: context.validateText,
                maxLines: 2,
                decoration: InputDecoration(labelText: context.tr('summary')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            final base = widget.initial;
            final entry = (base ?? const EducationEntry(id: '')).copyWith(
              dateRange: _range,
              institution: _institution.text.trim(),
              qualification: _qualification.text.trim(),
              fieldOfStudy: _field.text.trim(),
              grade: _grade.text.trim(),
              description: _description.text.trim(),
            );
            widget.onSave(entry);
          },
          child: Text(context.tr('save')),
        ),
      ],
    );
  }
}
