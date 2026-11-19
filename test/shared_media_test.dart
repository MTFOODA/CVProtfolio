import 'dart:convert';
import 'dart:io';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/supabase/supabase_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final type in DocumentType.values) {
    for (final legacy in [false, true]) {
      test('anonymous $type visitor refreshes ${legacy ? 'legacy URLs' : 'storage paths'} using share credentials', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final origin = 'http://127.0.0.1:${server.port}';
        final client = SupabaseClient(
          origin,
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(() async {
          await client.dispose();
          await server.close(force: true);
        });
        final cover = legacy
            ? '$origin/storage/v1/object/public/document-media/owner/cover.png'
            : 'owner/cover.png';
        final profile = UserProfile(
          id: 'owner',
          projects: [
            ProjectEntry(id: 'p', media: [cover]),
          ],
        );
        final document = CvDocument(
          id: 'd',
          ownerId: 'owner',
          title: 'Shared',
          type: type,
          published: true,
          profileSnapshot: type == DocumentType.cv ? profile : null,
        );
        final calls = <Map>[];
        server.listen((request) async {
          final body =
              jsonDecode(await utf8.decoder.bind(request).join()) as Map;
          request.response.headers.contentType = ContentType.json;
          Object? response;
          if (request.uri.path == '/functions/v1/share-media') {
            expect(client.auth.currentSession, isNull);
            calls.add(body);
            response = {
              'urls': {
                cover:
                    '$origin/storage/v1/object/sign/document-media/owner/cover.png?token=fresh',
              },
            };
          } else if (request.uri.path.startsWith(
            '/rest/v1/rpc/resolve_share_',
          )) {
            response = {
              'document': document.toJson(),
              // A CV's snapshot is authoritative even when the live profile differs.
              'profile': type == DocumentType.cv
                  ? const UserProfile(id: 'owner').toJson()
                  : profile.toJson(),
            };
          } else {
            fail(
              'Anonymous viewer attempted owner storage access: ${request.uri.path}',
            );
          }
          request.response.write(jsonEncode(response));
          await request.response.close();
        });
        final backend = SupabaseBackend(client);
        for (final result in [
          await backend.resolveBySlug('public'),
          await backend.resolveBySlugWithPassword('protected', 'password'),
          await backend.resolveByToken('recipient'),
        ]) {
          expect(
            result!.profile.projects.single.media.single,
            endsWith('?token=fresh'),
          );
          if (type == DocumentType.cv) {
            expect(
              result.document.profileSnapshot!.projects.single.media.single,
              endsWith('?token=fresh'),
            );
          }
        }
        expect(calls, [
          {
            'resolver': 'resolve_share_by_slug',
            'params': {'p_slug': 'public'},
          },
          {
            'resolver': 'resolve_share_with_password',
            'params': {'p_slug': 'protected', 'p_password': 'password'},
          },
          {
            'resolver': 'resolve_share_by_token',
            'params': {'p_token': 'recipient'},
          },
        ]);
      });
    }
  }
}
