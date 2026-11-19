import '../about/about_app_screen.dart';
import 'portfolio_cv_picker.dart';

import 'package:file_picker/file_picker.dart';

import '../../core/utils/project_media.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/profile_content.dart';
import '../../core/design/app_icons.dart';
import '../../core/theme/app_tokens.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../app/session.dart';
import '../../core/design/portfolio_themes.dart';
import '../../core/domain/document_entity.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/profile_models.dart';
import '../../core/render/resolved_document.dart';
import '../../core/render/section_titles.dart';
import '../export/export_sheet.dart';
import 'portfolio_controller.dart';
import 'portfolio_settings_screen.dart';
import 'portfolio_tabs.dart';
import 'portfolio_widgets.dart';
import 'portfolio_theme.dart';
import 'portfolio_navigation.dart';

/// One routed feature, one app bar and four retained tab bodies.
class PortfolioBuilderScreen extends ConsumerStatefulWidget {
  const PortfolioBuilderScreen({
    super.key,
    this.initialTab = 0,
    this.settingsOnly = false,
    this.embeddedSettings = false,
  });
  final int initialTab;
  final bool settingsOnly;
  final bool embeddedSettings;
  @override
  ConsumerState<PortfolioBuilderScreen> createState() =>
      _PortfolioBuilderScreenState();
}

class _PortfolioBuilderScreenState
    extends ConsumerState<PortfolioBuilderScreen> {
  static const _legacyPages = [
    PortfolioPage.about,
    PortfolioPage.projects,
    PortfolioPage.skills,
  ];
  late PortfolioPage _page = _legacyPages[widget.initialTab.clamp(0, 2)];
  bool _busy = false;
  final _shareKey = GlobalKey();

  @override
  void didUpdateWidget(PortfolioBuilderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _page = _legacyPages[widget.initialTab.clamp(0, 2)];
    }
  }

  void _selectPage(PortfolioPage page) {
    if (_page == page) return;
    setState(() => _page = page);
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: UiText(message)));
  }

  Future<void> _run(
    Future<void> Function() operation, {
    String? success,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      if (success != null) _feedback(success);
    } catch (_) {
      _feedback(
        'The action could not be completed. Check your connection and backend configuration, then try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _url(CvDocument document) => portfolioShareUrl(
    document,
    ref.read(appConfigProvider).shareBaseUrl,
    local: ref.read(backendProvider).isLocal,
  );

  Future<void> _share(CvDocument document, {bool copy = false}) => _run(
    () async {
      final url = _url(document);
      if (url == null) {
        _feedback(
          'Publish your portfolio with a configured backend and share host in Settings first.',
        );
        if (mounted) context.push('/settings?section=portfolio');
        return;
      }
      if (copy) {
        await Clipboard.setData(ClipboardData(text: url));
        _feedback('Portfolio link copied');
      } else {
        final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            text: url,
            subject: context.ui('My Portfolio'),
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      }
    },
  );

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: UiText(title),
          content: UiText(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const UiText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const UiText('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _publication(bool publish) async {
    if (_busy) return;
    if (!publish &&
        !await _confirm(
          'Unpublish portfolio?',
          'Existing portfolio links will stop opening until you publish again.',
        )) {
      return;
    }
    if (!mounted) return;
    await _run(() async {
      final controller = ref.read(portfolioProvider.notifier);
      if (publish) {
        await controller.publish();
      } else {
        await controller.save(
          ref.read(portfolioProvider).requireValue!.copyWith(published: false),
        );
      }
    }, success: publish ? 'Portfolio published' : 'Portfolio unpublished');
  }

  Future<void> _password(bool enable) async {
    if (_busy) return;
    if (!enable) {
      if (!await _confirm(
        'Remove password protection?',
        'Anyone with your published portfolio link will be able to view it.',
      )) {
        return;
      }
      if (!mounted) return;
      await _run(
        () => ref.read(portfolioProvider.notifier).setPassword(null),
        success: 'Password protection removed',
      );
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (password == null || !mounted) return;
    await _run(
      () => ref.read(portfolioProvider.notifier).setPassword(password),
      success: 'Portfolio password saved',
    );
  }

  Future<void> _open(Uri uri) => _run(() async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _feedback('No application could open this link.');
    }
  });
  Future<void> _edit() => _run(() async {
    final user = ref.read(sessionProvider2).value;
    if (user == null) return;
    final documents = await ref.read(backendProvider).listDocuments(user.id);
    if (!mounted) return;
    final sourceId = ref.read(portfolioProvider).value?.design.sourceCvId;
    final cv = documents
        .where(
          (d) =>
              d.type == DocumentType.cv &&
              (sourceId == null || d.id == sourceId),
        )
        .firstOrNull;
    context.push(cv == null ? '/wizard' : '/wizard/${cv.id}');
  });

  Future<void> _download(UserProfile profile) => _run(() async {
    final documents = await ref.read(documentsProvider(profile.id).future);
    final sourceId = ref.read(portfolioProvider).value?.design.sourceCvId;
    final cvs = documents.where(
      (d) =>
          d.type == DocumentType.cv && (sourceId == null || d.id == sourceId),
    );
    final cv = cvs.isEmpty
        ? CvDocument(
            id: 'portfolio-cv',
            ownerId: profile.id,
            title: profile.details.fullName ?? 'CV',
          )
        : cvs.first;
    if (!mounted) return;
    await showExportSheet(context, document: cv, profile: profile);
  });

  Future<void> _uploadPhoto(CvDocument document) => _run(() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedImageExtensions,
    );
    if (file == null || !mounted) return;
    final path = await uploadProjectMedia(
      file: file,
      repository: ref.read(backendProvider),
      ownerId: document.ownerId,
      avatar: true,
    );
    if (!mounted) return;
    final current = ref.read(portfolioProvider).value;
    if (current?.id != document.id) return;
    await ref
        .read(portfolioProvider.notifier)
        .save(
          current!.copyWith(
            design: current.design.copyWith(
              portfolioAvatar: current.design.portfolioAvatar.copyWith(
                path: () => path,
                visible: true,
              ),
            ),
          ),
        );
  });

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider2).value;
    final profileAsync = user == null
        ? const AsyncValue<UserProfile?>.data(null)
        : ref.watch(profileProvider(user.id));
    final portfolioAsync = ref.watch(portfolioProvider);
    final stored = portfolioAsync.value;
    final profile = stored?.profileSnapshot ?? profileAsync.value;
    final document = stored == null || profile == null
        ? stored
        : stored.copyWith(
            design: withProfileCustomSections(stored.design, profile),
          );
    final base = Theme.of(context);
    final theme = portfolioUiTheme(
      base,
      portfolioThemeById(document?.design.templateId),
    );
    final accent = theme.colorScheme.primary;
    final url = document == null ? null : _url(document);
    Widget body;
    var pages = <PortfolioPage>[PortfolioPage.about];
    if ((profileAsync.hasError && stored?.profileSnapshot == null) ||
        portfolioAsync.hasError) {
      body = Center(
        child: PortfolioEmpty(
          message: 'Unable to load your portfolio. Check your connection and try again.',
          onEdit: null,
        ),
      );
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          body,
          TextButton(
            onPressed: () {
              ref.invalidate(portfolioProvider);
              if (user != null) ref.invalidate(profileProvider(user.id));
            },
            child: const UiText('Retry'),
          ),
        ],
      );
    } else if ((profileAsync.isLoading && profile == null) ||
        (portfolioAsync.isLoading && document == null)) {
      body = const AppLoading();
    } else if (profile == null || document == null) {
      body = Center(
        child: PortfolioEmpty(
          message: 'Create your saved profile to start your portfolio.',
          onEdit: _edit,
        ),
      );
    } else {
      final resolved = ResolvedDocument.resolve(
        document: document,
        profile: profile,
        defaultTitle: defaultTitleResolver(context.languageCode),
      );
      final content = PortfolioContent(resolved, profile);
      pages = content.pages;
      if (!pages.contains(_page)) _page = PortfolioPage.about;
      final tabs = <Widget>[
        for (final page in pages)
          KeyedSubtree(
            key: ValueKey(page),
            child: PortfolioPageView(
              page: page,
              content: content,
              active: _page == page,
              onWork: () => _selectPage(PortfolioPage.projects),
              onOpen: _open,
              onEdit: _edit,
              onDownload: () => _download(profile),
            ),
          ),
      ];
      final settings = PortfolioSettingsTab(
        document: document,
        profile: profile,
        customSectionTitles: {
          for (final section in profile.customSections)
            section.id: section.title,
        },
        busy: _busy,
        shareUrl: url,
        onSave: (updated) => _run(
          () => ref.read(portfolioProvider.notifier).save(updated),
          success: 'Portfolio settings saved',
        ),
        onPublish: _publication,
        onPassword: _password,
        onCopy: () => _share(document, copy: true),
        onUploadPhoto: () => _uploadPhoto(document),
        embedded: widget.embeddedSettings,
      );
      body = widget.settingsOnly
          ? settings
          : IndexedStack(index: pages.indexOf(_page), children: tabs);
    }
    if (widget.embeddedSettings) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PortfolioCvPicker(busy: _busy),
          body,
        ],
      );
    }
    body = Column(
      children: [
        PortfolioCvPicker(busy: _busy),
        Expanded(child: body),
      ],
    );
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.ui('Back'),
            icon: const Icon(AppIcons.back, size: 21),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          titleSpacing: 0,
          title: widget.settingsOnly
              ? Text(context.tr('portfolioSettingsTitle'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UiText(
                      'My Portfolio',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: AppTypography.semibold,
                      ),
                    ),
                    Text(
                      url ??
                          (document?.published == true
                              ? context.ui('Share host not configured')
                              : context.ui('Unpublished portfolio')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
          actions: [
            AppInfoButton(
              portfolioThemeId: document?.design.templateId ?? 'ocean',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.icon(
                key: _shareKey,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: base.brightness == Brightness.dark
                      ? AppPalette.primaryDark
                      : Colors.white,
                ),
                onPressed: _busy || document == null
                    ? null
                    : () => _share(document),
                icon: const Icon(AppIcons.share, size: 16),
                label: const UiText('Share'),
              ),
            ),
          ],
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: SafeArea(
          top: false,
          child: PortfolioBackdrop(
            palette: portfolioThemeById(document?.design.templateId),
            child: AppContentTransition(
              identity: '${document?.id}:$_page',
              child: body,
            ),
          ),
        ),
        bottomNavigationBar: widget.settingsOnly || pages.length <= 1
            ? null
            : NavigationBar(
                height: 80,
                backgroundColor: base.colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                indicatorColor: accent.withValues(alpha: .08),
                selectedIndex: pages.indexOf(_page),
                onDestinationSelected: (index) => _selectPage(pages[index]),
                destinations: [
                  for (final page in pages)
                    NavigationDestination(
                      icon: Icon(page.icon),
                      label: page.label(context),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const UiText('Portfolio password'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _password,
              autofocus: true,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.ui('Password'),
                helperText: context.ui('At least 4 characters'),
              ),
              validator: (value) => (value?.length ?? 0) < 4
                  ? context.ui('Enter at least 4 characters')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.ui('Confirm password'),
              ),
              validator: (value) => value != _password.text
                  ? context.ui('Passwords do not match')
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const UiText('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _password.text);
          }
        },
        child: const UiText('Save password'),
      ),
    ],
  );
}
