/// Public product identity.
///
/// The display name is spelled exactly as approved. Every user-facing surface
/// that needs the full product name reads it from here so branding cannot
/// drift between platforms, exports and screens.
///
/// The Dart package name, Android application ID, iOS bundle identifier and
/// storage keys stay `cv_portfolio_maker`; only the human-readable name is
/// defined below.
library;

/// Official application display name.
const String kAppDisplayName = 'CV & Portfolio Builder';

/// Approved continuous CV monogram, in graphite and sky blue (proposal 4).
/// Editable source: assets/branding/brand_mark.svg; tools/create_identity.py.
const String kAppLogoAsset = 'assets/branding/app_logo.png';

/// Same CV mark on white for the portfolio's row of contact icons.
const String kPortfolioLinkLogoAsset =
    'assets/branding/portfolio_link_logo.png';

/// Public developer credits and official distribution destinations.
const String kDeveloperName = 'MOHAMED TAREK FOODA';
const String kDeveloperGitHubUrl = 'https://github.com/MTFOODA';
const String kDeveloperLinkedInUrl =
    'https://www.linkedin.com/in/mohamed-fooda-08b00132a/';
const String kOfficialWebAppUrl =
    'https://cvprotfolio.mohamed-fooda-mtf.workers.dev';
const String kAndroidAppDownloadUrl =
    'https://github.com/MTFOODA/CVProtfolio/releases/latest/download/cv-portfolio-builder.apk';
