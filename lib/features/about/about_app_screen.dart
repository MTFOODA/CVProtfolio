import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/branding/app_branding.dart';
import '../../core/design/app_icons.dart';
import '../../core/design/portfolio_themes.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_surfaces.dart';
import '../portfolio/portfolio_theme.dart';

/// Public product/developer credits; independent of any portfolio owner's data.
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({
    super.key,
    this.portfolioThemeId = 'ocean',
    this.onOpen,
  });
  final String portfolioThemeId;
  final Future<bool> Function(Uri)? onOpen;

  Future<void> _open(BuildContext context, String destination) async {
    try {
      final uri = Uri.parse(destination);
      final opened =
          await (onOpen?.call(uri) ??
              launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
              ));
      if (opened) return;
    } catch (_) {
      // Keep the page available when the OS cannot launch a destination.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('aboutOpenFailed'))));
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: portfolioUiTheme(
      Theme.of(context),
      portfolioThemeById(portfolioThemeId),
    ),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('aboutApp'))),
        body: SizedBox.expand(
          child: AppBackdrop(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: AppSpacing.pagePadding(context),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: AppHeroSurface(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadii.lg),
                              child: Image.asset(
                                kAppLogoAsset,
                                width: 88,
                                height: 88,
                                semanticLabel: kAppDisplayName,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            kAppDisplayName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            context.tr('aboutAppDescription'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            context.tr('developedBy'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const SelectableText(
                            kDeveloperName,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.md,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey('about-linkedin'),
                                onPressed: () =>
                                    _open(context, kDeveloperLinkedInUrl),
                                icon: const Icon(
                                  IconData(0xf08c, fontFamily: 'CvBrandIcons'),
                                ),
                                label: const Text('LinkedIn'),
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey('about-github'),
                                onPressed: () =>
                                    _open(context, kDeveloperGitHubUrl),
                                icon: const Icon(
                                  IconData(0xf09b, fontFamily: 'CvBrandIcons'),
                                ),
                                label: const Text('GitHub'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FilledButton.icon(
                            key: const ValueKey('about-android-download'),
                            onPressed: () =>
                                _open(context, kAndroidAppDownloadUrl),
                            icon: const Icon(
                              IconData(0xf17b, fontFamily: 'CvBrandIcons'),
                            ),
                            label: Text(
                              context.tr('downloadAndroidApp'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            key: const ValueKey('about-web-app'),
                            onPressed: () => _open(context, kOfficialWebAppUrl),
                            icon: const Icon(AppIcons.web),
                            label: Text(
                              context.tr('openOfficialWebApp'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Consistent, accessible circled information button on owner and public pages.
class AppInfoButton extends StatelessWidget {
  const AppInfoButton({
    super.key,
    this.buttonKey,
    this.portfolioThemeId = 'ocean',
  });
  final Key? buttonKey;
  final String portfolioThemeId;
  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: context.tr('aboutApp'),
    icon: const Icon(AppIcons.infoOutline),
    onPressed: () => context.push(
      Uri(
        path: '/about',
        queryParameters: {'theme': portfolioThemeId},
      ).toString(),
    ),
  );
}
