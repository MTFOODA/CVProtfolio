import 'dart:convert';
import 'dart:io';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/data/supabase/supabase_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Supabase records authorized opens once and never counts denied links or passwords', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'anon',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });
    final backend = SupabaseBackend(client);
    final recorded = <String>[];
    var authorized = true;
    var counterAvailable = true;
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      request.response.headers.contentType = ContentType.json;
      Object? response;
      if (request.uri.path == '/rest/v1/rpc/record_share_view') {
        recorded.add(body['p_share_id'] as String);
        if (!counterAvailable) {
          request.response.statusCode = 400;
          response = {'code': '42501', 'message': 'Counter unavailable'};
        }
      } else {
        expect(
          request.uri.path,
          isIn([
            '/rest/v1/rpc/resolve_share_by_slug',
            '/rest/v1/rpc/resolve_share_by_token',
            '/rest/v1/rpc/resolve_share_with_password',
          ]),
        );
        response = authorized
            ? {
                'shareId': '11111111-1111-1111-1111-111111111111',
                'document': const CvDocument(
                  id: 'portfolio',
                  ownerId: 'owner',
                  title: 'Portfolio',
                  type: DocumentType.portfolio,
                  published: true,
                ).toJson(),
                'profile': const UserProfile(id: 'owner').toJson(),
              }
            : null;
      }
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    expect(await backend.resolveBySlug('public'), isNotNull);
    expect(await backend.resolveByToken('token'), isNotNull);
    expect(
      await backend.resolveBySlugWithPassword('protected', 'correct'),
      isNotNull,
    );
    expect(recorded, List.filled(3, '11111111-1111-1111-1111-111111111111'));
    authorized = false;
    expect(await backend.resolveBySlug('private-or-expired'), isNull);
    expect(
      await backend.resolveBySlugWithPassword('protected', 'wrong'),
      isNull,
    );
    await expectLater(
      backend.resolveByToken('revoked'),
      throwsA(isA<ShareNotFoundException>()),
    );
    expect(recorded.length, 3);
    authorized = true;
    counterAvailable = false;
    expect(await backend.resolveBySlug('public'), isNotNull);
    expect(recorded.length, 4);
  });
}
