import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/data/portfolio_documents.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_controller.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_settings_screen.dart';

class _Session extends SessionController {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(id: 'owner', email: 'a@test.dev');
}

void main() {
  late Directory directory;
  late LocalBackend backend;
  late ProviderContainer container;
  const first = CvDocument(
    id: 'cv-a',
    ownerId: 'owner',
    title: 'Mobile CV',
    profileSnapshot: UserProfile(
      id: 'owner',
      details: ProfileDetails(fullName: 'Mobile Developer'),
      projects: [ProjectEntry(id: 'a', title: 'Mobile project')],
    ),
  );
  const second = CvDocument(
    id: 'cv-b',
    ownerId: 'owner',
    title: 'Backend CV',
    profileSnapshot: UserProfile(
      id: 'owner',
      details: ProfileDetails(fullName: 'Backend Developer'),
      projects: [ProjectEntry(id: 'b', title: 'Backend project')],
    ),
  );
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('portfolio_independence');
    backend = LocalBackend(LocalStore.forDirectory(directory));
    await backend.saveProfile(
      const UserProfile(
        id: 'owner',
        projects: [ProjectEntry(id: 'unrelated', title: 'Unrelated project')],
      ),
    );
    container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(
          LocalBackendOrSupabase.local(backend),
        ),
        sessionProvider2.overrideWith(_Session.new),
      ],
    );
    await container.read(sessionProvider2.future);
  });
  tearDown(() async {
    container.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'saving, duplicating and retrying CVs creates exactly one portfolio per CV',
    () async {
      await backend.saveDocument(first);
      await backend.saveDocument(second);
      await backend.saveDocument(first);
      final portfolios = (await backend.listDocuments('owner'))
          .where((d) => d.type == DocumentType.portfolio)
          .toList();
      expect(portfolios.length, 2);
      final a = portfolios.singleWhere((p) => p.design.sourceCvId == first.id);
      final b = portfolios.singleWhere((p) => p.design.sourceCvId == second.id);
      expect(a.id, isNot(b.id));
      expect(a.profileSnapshot!.projects.single.id, 'a');
      expect(b.profileSnapshot!.projects.single.id, 'b');
      final copied = first.copyWith(id: 'cv-copy');
      await backend.saveDocument(copied);
      expect(
        (await backend.listDocuments('owner'))
            .where((d) => d.type == DocumentType.portfolio)
            .length,
        3,
      );
      expect(CvDocument.fromJson(a.toJson()).design.sourceCvId, first.id);
    },
  );

  test('selection, settings, passwords, shared content and deletion stay independent', () async {
    await backend.saveDocument(first);
    await backend.saveDocument(second);
    container.listen(portfolioProvider, (_, _) {});
    container.read(portfolioCvIdProvider.notifier).select(first.id);
    final a = (await container.read(portfolioProvider.future))!;
    await container
        .read(portfolioProvider.notifier)
        .save(a.copyWith(design: a.design.copyWith(templateId: 'forest')));
    await container.read(portfolioProvider.notifier).publish();
    final publishedA = (await container.read(portfolioProvider.future))!;
    await container.read(portfolioProvider.notifier).setPassword('secret');
    await container.read(portfolioProvider.future);
    container.read(portfolioCvIdProvider.notifier).select(second.id);
    final b = (await container.read(portfolioProvider.future))!;
    expect(b.design.templateId, 'ocean');
    expect(b.accessPasswordHash, isNull);
    expect(b.published, isFalse);
    await container.read(portfolioProvider.notifier).publish();
    final publishedB = (await container.read(portfolioProvider.future))!;
    expect(publishedB.publicSlug, isNot(publishedA.publicSlug));
    final publicA = await backend.resolveBySlugWithPassword(
      publishedA.publicSlug!,
      'secret',
    );
    final publicB = await backend.resolveBySlug(publishedB.publicSlug!);
    expect(publicA!.profile.projects.single.id, 'a');
    expect(publicB!.profile.projects.single.id, 'b');
    await backend.saveDocument(
      first.copyWith(
        profileSnapshot: first.profileSnapshot!.copyWith(
          projects: const [
            ProjectEntry(id: 'updated', title: 'Updated mobile'),
          ],
        ),
      ),
    );
    final updatedA = (await backend.loadDocument(a.id, 'owner'))!;
    expect(updatedA.design.templateId, 'forest');
    expect(updatedA.publicSlug, publishedA.publicSlug);
    expect(updatedA.accessPasswordHash, isNotNull);
    expect(
      (await backend.resolveBySlug(publishedB.publicSlug!))!
          .profile
          .projects
          .single
          .id,
      'b',
    );
    await backend.deleteDocument(first.id, 'owner');
    expect(await backend.loadDocument(a.id, 'owner'), isNull);
    expect(await backend.resolveBySlug(publishedA.publicSlug!), isNull);
    expect(await backend.resolveBySlug(publishedB.publicSlug!), isNotNull);
  });

  test('legacy portfolio keeps its URL and styling when paired', () async {
    const legacy = CvDocument(
      id: 'legacy',
      ownerId: 'owner',
      title: 'Old portfolio',
      type: DocumentType.portfolio,
      published: true,
      shareMode: ShareMode.publicLink,
      publicSlug: 'original-url',
      design: DocumentDesign(templateId: 'rose'),
    );
    await backend.saveDocument(legacy);
    await backend.saveDocument(first);
    final paired = await syncCvPortfolio(backend, first);
    expect(paired.id, legacy.id);
    expect(paired.publicSlug, legacy.publicSlug);
    expect(paired.design.templateId, 'rose');
    expect(paired.profileSnapshot!.projects.single.id, 'a');
  });

  test(
    'visibility includes populated hidden sections and excludes empty sections',
    () {
      final profile = first.profileSnapshot!;
      expect(
        portfolioSectionHasContent(
          const SectionConfig(
            id: 'projects',
            kind: SectionKind.projects,
            visible: false,
          ),
          profile,
          null,
        ),
        isTrue,
      );
      expect(
        portfolioSectionHasContent(
          const SectionConfig(id: 'education', kind: SectionKind.education),
          profile,
          null,
        ),
        isFalse,
      );
      expect(
        portfolioSectionHasContent(
          const SectionConfig(id: 'projects', kind: SectionKind.projects),
          profile,
          ['other'],
        ),
        isFalse,
      );
      expect(
        portfolioSectionHasContent(
          const SectionConfig(id: 'summary', kind: SectionKind.profile),
          profile,
          null,
        ),
        isFalse,
      );
    },
  );
}
