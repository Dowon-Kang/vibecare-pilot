import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/domain/models.dart';
import 'package:vibecare_pilot/infrastructure/auth_repository.dart';
import 'package:vibecare_pilot/infrastructure/authenticated_client.dart';
import 'package:vibecare_pilot/infrastructure/server_device_gateway.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.handle);
  final Future<ResponseBody> Function(RequestOptions) handle;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody body(int status, Object json) => ResponseBody.fromString(
  jsonEncode(json),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
Future<MemorySessionStore> loggedIn() async {
  final store = MemorySessionStore();
  await store.save(
    const AuthSession(
      participant: ParticipantProfile(
        id: 'TEST',
        age: 72,
        sex: ParticipantSex.female,
        heightCm: 150,
      ),
      accessToken: 'old',
      refreshToken: 'refresh',
    ),
  );
  return store;
}

void main() {
  test('동시 401은 한 번 갱신하고 같은 멱등 키로 요청을 재시도한다', () async {
    final store = await loggedIn();
    final dio = createAuthenticatedClient('https://test.invalid', store);
    addTearDown(dio.close);
    int refreshes = 0;
    final oldRequests = Completer<void>();
    int oldCount = 0;
    dio.httpClientAdapter = Adapter((r) async {
      if (r.path == '/v1/auth/refresh') {
        refreshes++;
        await oldRequests.future;
        return body(200, {'accessToken': 'new'});
      }
      expect(r.headers['Idempotency-Key'], 'stable-idempotency-test');
      if (r.headers['Authorization'] == 'Bearer old') {
        if (++oldCount == 2) oldRequests.complete();
        return body(401, {'error': 'EXPIRED'});
      }
      expect(r.headers['Authorization'], 'Bearer new');
      return body(200, {'ok': true});
    });
    final responses = await Future.wait(
      List.generate(
        2,
        (_) => dio.post(
          '/v1/device-sessions',
          options: Options(
            headers: {'Idempotency-Key': 'stable-idempotency-test'},
          ),
        ),
      ),
    );
    expect(responses.every((r) => r.statusCode == 200), isTrue);
    expect(refreshes, 1);
    expect(await store.readAccessToken(), 'new');
  });
  test('갱신 거절은 재귀 재시도하지 않는다', () async {
    final dio = createAuthenticatedClient(
      'https://test.invalid',
      await loggedIn(),
    );
    addTearDown(dio.close);
    int refreshes = 0;
    dio.httpClientAdapter = Adapter((r) async {
      if (r.path == '/v1/auth/refresh') refreshes++;
      return body(401, {'error': 'INVALID_TOKEN'});
    });
    await expectLater(
      dio.get('/v1/participants/me/vitals'),
      throwsA(isA<DioException>()),
    );
    expect(refreshes, 1);
  });
  test('갱신 도중 로그아웃하면 이전 세션을 복원하지 않는다', () async {
    final store = await loggedIn();
    final dio = createAuthenticatedClient('https://test.invalid', store);
    addTearDown(dio.close);
    dio.httpClientAdapter = Adapter((r) async {
      if (r.path == '/v1/auth/refresh') {
        await store.clear();
        return body(200, {'accessToken': 'new'});
      }
      return body(401, {});
    });
    await expectLater(
      dio.get('/v1/participants/me/vitals'),
      throwsA(isA<DioException>()),
    );
    expect(await store.readAccessToken(), isNull);
  });
  test('HTTP 200이어도 중지 상태가 없으면 중지 성공으로 처리하지 않는다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.httpClientAdapter = Adapter(
      (_) async => body(200, {'status': 'RUNNING'}),
    );
    final gateway = ServerDeviceGateway(dio);
    addTearDown(dio.close);
    addTearDown(gateway.dispose);
    await expectLater(gateway.stop('session', 'user_stop'), throwsStateError);
  });
}
