import 'dart:async';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/app/statistics.dart';
import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/local/export_counter.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const owner = AuthUser(id: 'owner', email: 'owner@example.test');
const other = AuthUser(id: 'other', email: 'other@example.test');
const documents = [
  CvDocument(
    id: 'p1',
    ownerId: 'owner',
    title: 'Portfolio 1',
    type: DocumentType.portfolio,
  ),
  CvDocument(
    id: 'p2',
    ownerId: 'owner',
    title: 'Portfolio 2',
    type: DocumentType.portfolio,
  ),
  CvDocument(id: 'cv', ownerId: 'owner', title: 'CV'),
  CvDocument(
    id: 'other-p',
    ownerId: 'other',
    title: 'Other portfolio',
    type: DocumentType.portfolio,
  ),
];
const shares = [
  DocumentShare(id: 's1', documentId: 'p1', viewCount: 3),
  DocumentShare(id: 's2', documentId: 'p2', viewCount: 5),
  DocumentShare(
    id: 's3',
    documentId: 'p1',
    viewCount: 2,
    revokedAtIso: '2026-01-01T00:00:00Z',
  ),
  DocumentShare(id: 'cv-s', documentId: 'cv', viewCount: 100),
  DocumentShare(id: 'other-s', documentId: 'other-p', viewCount: 50),
];

class _Backend extends Fake implements LocalBackendOrSupabase {
  bool failDelete = false;
  Completer<void>? deletionGate;
  List<CvDocument> docs = [...documents];
  List<DocumentShare> links = [...shares];
  @override
  Future<List<CvDocument>> listDocuments(String userId) async =>
      docs.where((d) => d.ownerId == userId).toList();
  @override
  Future<List<DocumentShare>> listSharesForOwner(String userId) async {
    final ids = (await listDocuments(userId)).map((d) => d.id).toSet();
    return links.where((s) => ids.contains(s.documentId)).toList();
  }

  @override
  Future<UserProfile?> loadProfile(String userId) async =>
      UserProfile(id: userId);
  @override
  Future<CvBuilderDraft?> loadCvDraft(String userId, String draftKey) async =>
      null;
  @override
  Future<void> deleteAccount(String userId) async {
    if (deletionGate != null) await deletionGate!.future;
    if (failDelete) throw StateError('Account deletion failed');
    final ids = (await listDocuments(userId)).map((d) => d.id).toSet();
    docs.removeWhere((d) => d.ownerId == userId);
    links.removeWhere((s) => ids.contains(s.documentId));
  }
}

class _Auth extends Fake implements AuthService {
  AuthUser? user = owner;
  final events = StreamController<AuthUser?>.broadcast();
  @override
  AuthUser? get currentUser => user;
  @override
  bool get isRecoveringPassword => false;
  @override
  Stream<AuthUser?> get authStateChanges => events.stream;
  @override
  Future<AuthUser?> restoreSession() async => user;
  @override
  Future<void> signOut() async {
    user = null;
    events.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Backend backend;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'stats.exports.count': 99});
    auth = _Auth();
    backend = _Backend();
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        backendProvider.overrideWithValue(backend),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            supabaseUrl: '',
            supabaseAnonKey: '',
            googleWebClientId: '',
            googleIosClientId: '',
            shareBaseUrl: 'https://example.test',
          ),
        ),
      ],
    );
    container.listen(sessionProvider2, (_, _) {});
    await container.read(sessionProvider2.future);
  });
  tearDown(() async {
    container.dispose();
    await auth.events.close();
  });

  test('download totals are isolated by account and discard the unowned legacy count', () async {
    expect(await readExportCount(owner.id), 0);
    await recordExport(owner.id);
    await recordExport(owner.id);
    await recordExport(other.id);
    expect(await readExportCount(owner.id), 2);
    expect(await readExportCount(other.id), 1);
    await clearExportCount(owner.id);
    expect(await readExportCount(owner.id), 0);
    expect(await readExportCount(other.id), 1);
  });

  test('finishing deletion of a previous account never signs out a newly active account', () async {
    backend.deletionGate = Completer<void>();
    final deleting = container
        .read(sessionProvider2.notifier)
        .deleteAccount(owner.id);
    auth.user = other;
    auth.events.add(other);
    await container.pump();
    backend.deletionGate!.complete();
    await deleting;
    expect(auth.currentUser?.id, other.id);
    expect(container.read(sessionProvider2).value?.id, other.id);
  });

  test('successful account deletion clears downloads and views without changing another account', () async {
    await recordExport(owner.id);
    await recordExport(other.id);
    container.listen(downloadCountProvider(owner.id), (_, _) {});
    expect(await container.read(downloadCountProvider(owner.id).future), 1);
    await container.read(sessionProvider2.notifier).deleteAccount(owner.id);
    expect(await readExportCount(owner.id), 0);
    expect(await container.read(downloadCountProvider(owner.id).future), 0);
    expect(await readExportCount(other.id), 1);
    expect(await backend.listSharesForOwner(owner.id), isEmpty);
    expect(portfolioViewTotal(owner.id, backend.docs, backend.links), 0);
    expect(portfolioViewTotal(other.id, backend.docs, backend.links), 50);
    expect(auth.currentUser, isNull);
  });

  test(
    'failed account deletion preserves downloads and the signed-in account',
    () async {
      await recordExport(owner.id);
      backend.failDelete = true;
      await expectLater(
        container.read(sessionProvider2.notifier).deleteAccount(owner.id),
        throwsStateError,
      );
      expect(await readExportCount(owner.id), 1);
      expect(container.read(sessionProvider2).value?.id, owner.id);
      expect(portfolioViewTotal(owner.id, backend.docs, backend.links), 10);
    },
  );

  test('portfolio views include all owned portfolios and exclude CVs and other owners', () {
    expect(portfolioViewTotal(owner.id, documents, shares), 10);
    expect(portfolioViewTotal(other.id, documents, shares), 50);
    expect(portfolioViewTotal('new-account', documents, shares), 0);
  });

  test(
    'a stale delete confirmation cannot delete a different account',
    () async {
      await recordExport(other.id);
      await expectLater(
        container.read(sessionProvider2.notifier).deleteAccount(other.id),
        throwsA(isA<AuthException>()),
      );
      expect(await readExportCount(other.id), 1);
      expect(backend.docs.length, documents.length);
      expect(auth.currentUser?.id, owner.id);
    },
  );

  testWidgets(
    'home shows account-specific statistics and updates after export and account switching',
    (tester) async {
      Future<void> settle() async {
        // The container was bootstrapped before the widget's fake async zone.
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await recordExport(owner.id);
      await recordExport(other.id);
      await recordExport(other.id);
      await recordExport(other.id);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await settle();
      Finder value(String key, String text) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.text(text),
      );
      expect(value('downloads-stat', '1'), findsOneWidget);
      expect(value('portfolio-views-stat', '10'), findsOneWidget);
      await recordExport(owner.id);
      container.invalidate(downloadCountProvider(owner.id));
      await settle();
      expect(value('downloads-stat', '2'), findsOneWidget);
      await tester.tap(find.byType(NavigationDestination).at(3));
      await settle();
      backend.links = backend.links
          .map((s) => s.id == 's1' ? s.copyWith(viewCount: 7) : s)
          .toList();
      await tester.tap(find.byType(NavigationDestination).first);
      await settle();
      expect(value('portfolio-views-stat', '14'), findsOneWidget);
      auth.user = other;
      auth.events.add(other);
      await settle();
      expect(value('downloads-stat', '3'), findsOneWidget);
      expect(value('portfolio-views-stat', '50'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
