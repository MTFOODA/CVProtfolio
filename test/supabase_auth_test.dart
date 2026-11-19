import 'dart:convert';
import 'dart:io';

import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/data/auth/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('email login, refreshed session, recovery callback and logout use the SDK correctly', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'anon',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final service = SupabaseAuthService(
      AppConfig.fromEnvironment(),
      client: client,
    );
    final events = <String?>[];
    final subscription = service.authStateChanges.listen(
      (user) => events.add(user?.id),
    );
    addTearDown(() async {
      await subscription.cancel();
      await client.dispose();
      await server.close(force: true);
    });
    final user = {
      'id': '11111111-1111-1111-1111-111111111111',
      'aud': 'authenticated',
      'email': 'user@example.test',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': {'full_name': 'Test User'},
    };
    var refreshed = false;
    var resetRequested = false;
    String? updatedPassword;
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map;
      request.response.headers.contentType = ContentType.json;
      Object response = {};
      switch (request.uri.path) {
        case '/auth/v1/token':
          if (request.uri.queryParameters['grant_type'] == 'refresh_token') {
            expect(body['refresh_token'], 'refresh-token');
            refreshed = true;
          } else {
            expect(body['email'], 'user@example.test');
          }
          response = {
            'access_token': refreshed
                ? 'refreshed-access-token'
                : 'access-token',
            'refresh_token': 'refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user,
          };
        case '/auth/v1/user':
          if (request.method == 'PUT') {
            updatedPassword = body['password'] as String;
          }
          response = user;
        case '/auth/v1/recover':
          expect(body['email'], 'user@example.test');
          resetRequested = true;
        case '/auth/v1/logout':
          request.response.statusCode = 204;
        default:
          fail('Unexpected authentication endpoint: ${request.uri.path}');
      }
      if (request.response.statusCode != 204) {
        request.response.write(jsonEncode(response));
      }
      await request.response.close();
    });
    expect(
      (await service.signInWithEmail(
        email: ' user@example.test ',
        password: 'password',
      )).id,
      user['id'],
    );
    expect((await service.restoreSession())?.id, user['id']);
    await client.auth.refreshSession();
    expect(refreshed, isTrue);
    expect(client.auth.currentSession?.accessToken, 'refreshed-access-token');
    await service.resetPassword(' user@example.test ');
    expect(resetRequested, isTrue);
    await client.auth.getSessionFromUrl(
      Uri.parse(
        'http://localhost:8080/?auth=recovery#access_token=recovery-token&refresh_token=refresh-token&expires_in=3600&token_type=bearer&type=recovery',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(service.isRecoveringPassword, isTrue);
    await service.updatePassword('new-password');
    expect(updatedPassword, 'new-password');
    expect(service.isRecoveringPassword, isFalse);
    await service.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(await service.restoreSession(), isNull);
    expect(events.last, isNull);
  });

  test('signup awaiting confirmation does not authenticate the user', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'anon',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });
    server.listen((request) async {
      expect(request.uri.path, '/auth/v1/signup');
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['email'], 'new@example.test');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'id': '11111111-1111-1111-1111-111111111111',
          'aud': 'authenticated',
          'email': 'new@example.test',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': <String, dynamic>{},
          'user_metadata': {'full_name': 'New User'},
        }),
      );
      await request.response.close();
    });
    final service = SupabaseAuthService(
      AppConfig.fromEnvironment(),
      client: client,
    );
    final user = await service.registerWithEmail(
      email: ' new@example.test ',
      password: 'test-password',
      fullName: 'New User',
    );
    expect(user, isNull);
    expect(service.currentUser, isNull);
    expect(await service.restoreSession(), isNull);
  });
}
