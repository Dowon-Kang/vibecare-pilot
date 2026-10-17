import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibecare_pilot/services/account_profile_repository.dart';

Future<void> _login(SupabaseClient client, String owner) =>
    client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-token',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': owner,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': false,
        },
      }),
    );

void main() {
  test(
    'SDK upsert persists own row and a new login/client loads saved values',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      Map<String, dynamic>? saved;
      var writes = 0;
      server.listen((request) async {
        expect(request.uri.path, '/rest/v1/account_profiles');
        expect(
          request.headers.value('authorization'),
          'Bearer synthetic-token',
        );
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST') {
          writes++;
          saved =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          expect(saved!['user_id'], 'account-a');
          request.response.write(jsonEncode(saved));
        } else {
          expect(request.uri.queryParameters['user_id'], 'eq.account-a');
          request.response.write(jsonEncode(saved == null ? [] : [saved]));
        }
        await request.response.close();
      });
      SupabaseClient createClient() => SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final first = createClient();
      addTearDown(first.dispose);
      await _login(first, 'account-a');
      final repo = SupabaseAccountProfileRepository(first, 'account-a');
      expect(await repo.load(), isNull);
      await repo.save(
        const AccountProfile(age: 70, sex: 'female', heightCm: 162.5),
      );
      await repo.save(
        const AccountProfile(age: 71, sex: 'male', heightCm: 163),
      );
      final next = createClient();
      addTearDown(next.dispose);
      await _login(next, 'account-a');
      final loaded = await SupabaseAccountProfileRepository(
        next,
        'account-a',
      ).load();
      expect(loaded!.age, 71);
      expect(loaded.sex, 'male');
      expect(loaded.heightCm, 163);
      expect(writes, 2);
    },
  );
  test(
    'unauthenticated and changed accounts cannot write or consume pending profile',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<void>(), release = Completer<void>();
      var calls = 0;
      server.listen((request) async {
        calls++;
        received.complete();
        await release.future;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode([
            {
              'user_id': 'account-a',
              'age': 65,
              'sex': 'female',
              'height_cm': 155,
            },
          ]),
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final repo = SupabaseAccountProfileRepository(client, 'account-a');
      await expectLater(repo.load(), throwsStateError);
      expect(calls, 0);
      await _login(client, 'account-a');
      final pending = repo.load();
      final rejected = expectLater(pending, throwsStateError);
      await received.future;
      await _login(client, 'account-b');
      release.complete();
      await rejected;
      await expectLater(
        repo.save(const AccountProfile(age: 65, sex: 'female', heightCm: 155)),
        throwsStateError,
      );
      expect(calls, 1);
    },
  );
}
