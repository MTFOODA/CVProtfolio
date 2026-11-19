/// Application router: auth gate, dashboard, editors and public viewer.
///
/// Anonymous share routes (`/p/:slug`, `/s/:token`) never require a session.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/auth_redirect.dart';
import '../features/about/about_app_screen.dart';
import 'session.dart';

import 'package:cv_portfolio_maker/features/auth/forgot_password_screen.dart';
import 'package:cv_portfolio_maker/features/auth/login_screen.dart';
import 'package:cv_portfolio_maker/features/auth/register_screen.dart';
import 'package:cv_portfolio_maker/features/auth/reset_password_screen.dart';
import 'package:cv_portfolio_maker/features/dashboard/dashboard_screen.dart';
import 'package:cv_portfolio_maker/features/editor/document_editor_screen.dart';
import 'package:cv_portfolio_maker/features/cv_builder/cv_builder_wizard_screen.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_builder_screen.dart';
import 'package:cv_portfolio_maker/features/profile/profile_screen.dart';
import 'package:cv_portfolio_maker/features/settings/credentials_screen.dart';
import 'package:cv_portfolio_maker/features/templates/templates_screen.dart';
import 'package:cv_portfolio_maker/features/viewer/public_viewer_screen.dart';

/// Builds the router. [isSignedIn] gates authenticated routes.
GoRouter buildRouter({
  required ValueListenable<bool> isSignedIn,
  required String Function() currentUserId,
  ValueListenable<bool>? isRecoveringPassword,
}) {
  // Parsing can stay unchanged during an A -> B account switch. Watch identity
  // in the widget tree too, so retained forms are rebuilt for their owner.
  Widget accountScreen(Widget Function(String owner) build) => Consumer(
    builder: (context, ref, _) => build(
      ref.watch(sessionProvider2.select((value) => value.value?.id)) ??
          currentUserId(),
    ),
  );
  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([isSignedIn, ?isRecoveringPassword]),
    redirect: (context, state) {
      final signedIn = isSignedIn.value;
      final location = state.matchedLocation;
      final isPublic =
          location == '/about' ||
          location.startsWith('/p/') ||
          location.startsWith('/s/') ||
          location == '/login' ||
          location == '/register' ||
          location == '/reset-password' ||
          location == '/forgot-password';
      if (!signedIn && !isPublic) {
        return Uri(
          path: '/login',
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      if (signedIn &&
          (isRecoveringPassword?.value ?? false) &&
          location != '/reset-password') {
        final destination =
            internalReturnLocation(state.uri.queryParameters['from']) ??
            internalReturnLocation(state.uri.toString());
        return Uri(
          path: '/reset-password',
          queryParameters: destination == null ? null : {'from': destination},
        ).toString();
      }
      if (signedIn &&
          {'/login', '/register', '/forgot-password'}.contains(location)) {
        return internalReturnLocation(state.uri.queryParameters['from']) ?? '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/about',
        builder: (context, state) => AboutAppScreen(
          portfolioThemeId: state.uri.queryParameters['theme'] ?? 'ocean',
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => accountScreen(
          (owner) => DashboardScreen(key: ValueKey('dashboard:$owner')),
        ),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => accountScreen(
              (owner) => ProfileScreen(key: ValueKey('profile:$owner')),
            ),
          ),
          GoRoute(
            path: 'templates',
            builder: (context, state) => const TemplatesScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => accountScreen(
              (owner) => DashboardScreen(
                key: ValueKey('settings:$owner'),
                settingsRoute: true,
              ),
            ),
            routes: [
              GoRoute(
                path: 'portfolio',
                redirect: (context, state) => '/settings?section=portfolio',
              ),
              GoRoute(
                path: 'credentials/:kind',
                builder: (context, state) => accountScreen(
                  (owner) => CredentialsScreen(
                    key: ValueKey(
                      'credentials:$owner:${state.pathParameters['kind']}',
                    ),
                    courses: state.pathParameters['kind'] == 'courses',
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'doc/:id',
            builder: (context, state) => accountScreen(
              (owner) => DocumentEditorScreen(
                key: ValueKey('document:$owner:${state.pathParameters['id']}'),
                documentId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: 'wizard',
            builder: (context, state) => accountScreen(
              (owner) =>
                  CvBuilderWizardScreen(key: ValueKey('wizard:$owner:new')),
            ),
          ),
          GoRoute(
            path: 'wizard/:documentId',
            builder: (context, state) => accountScreen(
              (owner) => CvBuilderWizardScreen(
                key: ValueKey(
                  'wizard:$owner:${state.pathParameters['documentId']}',
                ),
                documentId: state.pathParameters['documentId']!,
              ),
            ),
          ),
          GoRoute(
            path: 'portfolio',
            redirect: (context, state) =>
                state.uri.queryParameters['tab'] == 'settings'
                ? '/settings?section=portfolio'
                : null,
            builder: (context, state) => accountScreen(
              (owner) => PortfolioBuilderScreen(
                key: ValueKey('portfolio:$owner'),
                initialTab: state.uri.queryParameters['tab'] == 'settings'
                    ? 3
                    : 0,
              ),
            ),
          ),
          GoRoute(
            path: 'portfolio/settings',
            redirect: (context, state) => '/settings?section=portfolio',
          ),
        ],
      ),
      GoRoute(
        path: '/p/:slug',
        builder: (context, state) => PublicViewerScreen(
          key: ValueKey('slug:${state.pathParameters['slug']}'),
          slug: state.pathParameters['slug'],
        ),
      ),
      GoRoute(
        path: '/s/:token',
        builder: (context, state) => PublicViewerScreen(
          key: ValueKey('token:${state.pathParameters['token']}'),
          token: state.pathParameters['token'],
        ),
      ),
    ],
  );
}
