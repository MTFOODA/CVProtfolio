import '../../core/design/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/portfolio_themes.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/domain/document_entity.dart';
import '../../core/domain/profile_models.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/ui_text.dart';
import '../../core/render/resolved_document.dart';
import '../../core/render/section_titles.dart';
import 'portfolio_tabs.dart';
import 'portfolio_theme.dart';
import 'portfolio_navigation.dart';

/// Receives content only after the existing server share/password gate succeeds.
/// There are no owner actions or settings widgets on the visitor surface.
class PublicPortfolioView extends StatefulWidget {
  const PublicPortfolioView({
    super.key,
    required this.document,
    required this.profile,
    required this.resolved,
    required this.onOpen,
    required this.onDownload,
    this.downloading = false,
  });
  final CvDocument document;
  final UserProfile profile;
  final ResolvedDocument resolved;
  final ValueChanged<Uri> onOpen;
  final VoidCallback onDownload;
  final bool downloading;
  @override
  State<PublicPortfolioView> createState() => _PublicPortfolioViewState();
}

class _PublicPortfolioViewState extends State<PublicPortfolioView> {
  PortfolioPage _page = PortfolioPage.about;
  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final resolved = ResolvedDocument.resolve(
      document: document,
      profile: widget.profile,
      defaultTitle: defaultTitleResolver(context.languageCode),
    );
    final content = PortfolioContent(resolved, widget.profile);
    final pages = content.pages;
    if (!pages.contains(_page)) _page = PortfolioPage.about;
    return Theme(
      data: portfolioUiTheme(
        Theme.of(context),
        portfolioThemeById(document.design.templateId),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const UiText('My Portfolio'),
          actions: [
            IconButton(
              key: const ValueKey('portfolio-app-about'),
              tooltip: context.tr('aboutApp'),
              onPressed: () => context.push(
                Uri(
                  path: '/about',
                  queryParameters: {
                    'theme': portfolioThemeById(document.design.templateId).id,
                  },
                ).toString(),
              ),
              icon: const Icon(AppIcons.infoOutline),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: AppContentTransition(
            identity: _page,
            child: IndexedStack(
              index: pages.indexOf(_page),
              children: [
                for (final page in pages)
                  KeyedSubtree(
                    key: ValueKey(page),
                    child: PortfolioPageView(
                      page: page,
                      content: content,
                      active: _page == page,
                      editable: false,
                      showDownload: false,
                      onEdit: () {},
                      onDownload: widget.onDownload,
                      onOpen: widget.onOpen,
                      onWork: () =>
                          setState(() => _page = PortfolioPage.projects),
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: pages.length <= 1
            ? null
            : NavigationBar(
                selectedIndex: pages.indexOf(_page),
                onDestinationSelected: (index) =>
                    setState(() => _page = pages[index]),
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
