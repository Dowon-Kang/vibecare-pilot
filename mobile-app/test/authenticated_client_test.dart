import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/services/auth_repository.dart';
import 'package:vibecare_pilot/services/authenticated_client.dart';
import 'package:vibecare_pilot/services/backend_device_gateway.dart';
import 'package:vibecare_pilot/services/device_gateway.dart';
import 'package:vibecare_pilot/services/fitrus_repository.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';

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
  test('서버 버전·수치·실행 모드가 다르면 허가를 사용하지 않는다', () async {
    const participant = ParticipantProfile(
      id: 'TEST',
      age: 72,
      sex: ParticipantSex.female,
      heightCm: 150,
    );
    final snapshot = await MockFitrusRepository().loadSnapshot(
      participant: participant,
      deviceId: 'BIA',
    );
    final result = calculateRecommendation(
      profile: participant,
      measurements: snapshot.selectedMeasurements,
      safety: const SafetyCheck.confirmedClear(),
    );
    expect(result.canRequestAuthorization, isTrue);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    final gateway = BackendDeviceGateway(dio);
    addTearDown(dio.close);
    addTearDown(gateway.dispose);
    for (final change in ['version', 'frequency', 'real']) {
      dio.httpClientAdapter = Adapter(
        (r) async => r.path == '/health'
            ? body(200, {})
            : body(201, {
                'authorized': true,
                'mode': change == 'real' ? 'real' : 'mock',
                'result': {
                  'realDeviceSendAllowed': false,
                  'algorithmVersion': change == 'version'
                      ? 'pilot-0.5.0'
                      : algorithmVersion,
                  'recommendation': {
                    'durationSec': result.recommendation!.durationSec,
                    'frequencyHz': change == 'frequency'
                        ? 99
                        : result.recommendation!.frequencyHz,
                    'intensityPct': result.recommendation!.intensityPct,
                  },
                },
              }),
      );
      await gateway.connect('MOCK');
      await expectLater(
        gateway.authorize(
          result: result,
          participant: participant,
          safety: const SafetyCheck.confirmedClear(),
          intensityPct: result.recommendation!.intensityPct,
          sourceDeviceId: 'BIA',
        ),
        throwsStateError,
      );
    }
  });
  test('네트워크·ACK 실패는 실행 성공이 아니며 재시도 키를 유지한다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    final gateway = BackendDeviceGateway(dio);
    addTearDown(dio.close);
    addTearDown(gateway.dispose);
    final states = <DeviceConnectionState>[];
    final sub = gateway.statusStream.listen(states.add);
    addTearDown(sub.cancel);
    final now = DateTime.now();
    final auth = DeviceAuthorization(
      command: DeviceCommand(
        authorizationId: 'A',
        participantId: 'TEST',
        deviceId: 'MOCK',
        durationSec: 180,
        frequencyHz: 12,
        intensityPct: 30,
        algorithmVersion: algorithmVersion,
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
        idempotencyKey: 'stable-retry-123456',
      ),
    );
    for (final failure in ['network', 'timeout', 'missing_ack']) {
      dio.httpClientAdapter = Adapter((r) async {
        expect(r.headers['Idempotency-Key'], 'stable-retry-123456');
        if (failure != 'missing_ack') {
          throw DioException(
            requestOptions: r,
            type: failure == 'timeout'
                ? DioExceptionType.receiveTimeout
                : DioExceptionType.connectionError,
          );
        }
        return body(200, {'mode': 'mock', 'status': 'STARTING'});
      });
      await expectLater(
        gateway.start(auth),
        throwsA(anyOf(isA<DioException>(), isA<StateError>())),
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(states, isNot(contains(DeviceConnectionState.running)));
    expect(states.where((s) => s == DeviceConnectionState.error).length, 3);
  });
  test('서버 규칙의 근육량 프로토콜이 없으면 기본값으로 대체하지 않는다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    addTearDown(dio.close);
    dio.httpClientAdapter = Adapter((r) async {
      if (r.path.endsWith('/current') && r.path.contains('algorithm-rules')) {
        return body(200, {'version': algorithmVersion});
      }
      if (r.path.endsWith('/vitals')) return body(200, {'items': []});
      return body(200, {
        'history': [],
        'selectedMeasurementIds': [],
        'syncedAt': '2026-09-09T00:00:00Z',
      });
    });
    await expectLater(
      BackendFitrusRepository(dio).loadSnapshot(
        participant: const ParticipantProfile(
          id: 'TEST',
          age: 72,
          sex: ParticipantSex.female,
          heightCm: 150,
        ),
        deviceId: 'BIA',
      ),
      throwsFormatException,
    );
  });
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
    final gateway = BackendDeviceGateway(dio);
    addTearDown(dio.close);
    addTearDown(gateway.dispose);
    await expectLater(gateway.stop('session', 'user_stop'), throwsStateError);
  });
}
