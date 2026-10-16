/// Application router: auth gate, dashboard, editors and public viewer.
///
/// Anonymous share routes (`/p/:slug`, `/s/:token`) never require a session.
library;

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:cv_portfolio_maker/features/auth/login_screen.dart';
import 'package:cv_portfolio_maker/features/dashboard/dashboard_screen.dart';
import 'package:cv_portfolio_maker/features/editor/document_editor_screen.dart';
import 'package:cv_portfolio_maker/features/profile/profile_screen.dart';
import 'package:cv_portfolio_maker/features/settings/settings_screen.dart';
import 'package:cv_portfolio_maker/features/templates/templates_screen.dart';
import 'package:cv_portfolio_maker/features/viewer/public_viewer_screen.dart';

/// Builds the router. [isSignedIn] gates authenticated routes.
GoRouter buildRouter({
  required ValueListenable<bool> isSignedIn,
  required String Function() currentUserId,
}) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: isSignedIn,
    redirect: (context, state) {
      final signedIn = isSignedIn.value;
      final location = state.matchedLocation;
      final isPublic =
          location.startsWith('/p/') ||
          location.startsWith('/s/') ||
          location == '/login';
      if (!signedIn && !isPublic) return '/login';
      if (signedIn && location == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'templates',
            builder: (context, state) => const TemplatesScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'doc/:id',
            builder: (context, state) =>
                DocumentEditorScreen(documentId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/p/:slug',
        builder: (context, state) =>
            PublicViewerScreen(slug: state.pathParameters['slug']),
      ),
      GoRoute(
        path: '/s/:token',
        builder: (context, state) =>
            PublicViewerScreen(token: state.pathParameters['token']),
      ),
    ],
  );
}
