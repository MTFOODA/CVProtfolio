import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_controller.dart';

class _Session extends SessionController {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(id: 'owner', email: 'owner@example.test');
  void switchTo(String id) =>
      state = AsyncData(AuthUser(id: id, email: '$id@example.test'));
}

class _Backend extends Fake implements LocalBackendOrSupabase {
  final docs = <CvDocument>[];
  final started = Completer<void>();
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<List<CvDocument>> listDocuments(String owner) async =>
      docs.where((d) => d.ownerId == owner).toList();
  @override
  Future<CvDocument> saveDocument(CvDocument document) async {
    writes++;
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    docs.removeWhere((d) => d.id == document.id);
    docs.add(document);
    return document;
  }
}

void main() {
  late _Backend backend;
  late ProviderContainer container;
  setUp(() async {
    backend = _Backend();
    container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(backend),
        sessionProvider2.overrideWith(_Session.new),
      ],
    );
    await container.read(sessionProvider2.future);
  });
  tearDown(() => container.dispose());

  test(
    'reloading during initial creation reuses the in-flight portfolio draft',
    () async {
      backend.gate = Completer<void>();
      container.listen(portfolioProvider, (_, _) {});
      await backend.started.future;
      container.invalidate(portfolioProvider);
      await container.pump();
      expect(backend.writes, 1);
      backend.gate!.complete();
      await container.read(portfolioProvider.future);
      await container.pump();
      expect(backend.docs.length, 1);
    },
  );

  test(
    'a previous account save cannot replace the active account portfolio',
    () async {
      backend.docs.addAll([
        const CvDocument(
          id: 'a',
          ownerId: 'owner',
          title: 'Owner portfolio',
          type: DocumentType.portfolio,
        ),
        const CvDocument(
          id: 'b',
          ownerId: 'other',
          title: 'Other portfolio',
          type: DocumentType.portfolio,
        ),
      ]);
      container.listen(portfolioProvider, (_, _) {});
      final first = (await container.read(portfolioProvider.future))!;
      backend.gate = Completer<void>();
      final saving = container
          .read(portfolioProvider.notifier)
          .save(first.copyWith(title: 'Updated owner portfolio'));
      await backend.started.future;
      (container.read(sessionProvider2.notifier) as _Session).switchTo('other');
      await container.pump();
      expect((await container.read(portfolioProvider.future))!.id, 'b');
      backend.gate!.complete();
      await saving;
      expect(container.read(portfolioProvider).value!.id, 'b');
    },
  );
}
