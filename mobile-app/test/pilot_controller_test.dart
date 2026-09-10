import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';
import 'package:vibecare_pilot/controllers/pilot_controller.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/services/auth_repository.dart';
import 'package:vibecare_pilot/services/device_gateway.dart';
import 'package:vibecare_pilot/services/fitrus_repository.dart';

void main() {
  test('데이터 연결과 장치 실행 모드를 독립적으로 구분한다', () {
    const local = AppEnvironment(apiBaseUrl: '');
    const backend = AppEnvironment(apiBaseUrl: 'https://example.test');

    expect(local.usesSampleData, isTrue);
    expect(local.usesBackendApi, isFalse);
    expect(local.usesDeviceSimulator, isTrue);
    expect(backend.usesSampleData, isFalse);
    expect(backend.usesBackendApi, isTrue);
    expect(backend.usesDeviceSimulator, isTrue);
  });

  test('로그인 후 입력 변경은 계산을 갱신하고 기존 실행 허가를 취소한다', () async {
    final gateway = _FakeDeviceGateway();
    final container = _container(gateway: gateway);
    addTearDown(container.dispose);

    final controller = container.read(pilotControllerProvider.notifier);
    await controller.login('TEST-001', '123456');
    expect(container.read(pilotControllerProvider).isLoggedIn, isTrue);

    controller.updateSafety(pain: false, dizziness: false, hold: false);
    await controller.sendToDevice();
    expect(
      container.read(pilotControllerProvider).pendingAuthorization,
      isNotNull,
    );

    final automaticIntensity = container
        .read(pilotControllerProvider)
        .automaticIntensityPct!;
    controller.updateIntensity(automaticIntensity - 1);
    final state = container.read(pilotControllerProvider);
    expect(state.selectedIntensityPct, automaticIntensity - 1);
    expect(state.isIntensityManual, isTrue);
    expect(state.pendingAuthorization, isNull);
    expect(state.deviceState, DeviceConnectionState.disconnected);
  });

  test('전송, 시작, 완료와 피드백 상태 전이를 순서대로 유지한다', () async {
    final gateway = _FakeDeviceGateway();
    final container = _container(gateway: gateway);
    addTearDown(container.dispose);

    final controller = container.read(pilotControllerProvider.notifier);
    await controller.login('TEST-001', '123456');
    controller.updateSafety(pain: false, dizziness: false, hold: false);
    await controller.sendToDevice();
    await controller.startSession();
    expect(container.read(pilotControllerProvider).session, isNotNull);

    await controller.stopSession('completed');
    final finished = container.read(pilotControllerProvider);
    expect(finished.session, isNull);
    expect(finished.feedbackSession, isNotNull);
    expect(gateway.stopReason, 'completed');
  });

  test('인증 실패는 로그인 상태를 만들지 않고 사용자 오류를 남긴다', () async {
    final gateway = _FakeDeviceGateway();
    final container = _container(
      gateway: gateway,
      authRepository: _FailingAuthRepository(),
    );
    addTearDown(container.dispose);

    await container
        .read(pilotControllerProvider.notifier)
        .login('UNKNOWN', '000000');
    final state = container.read(pilotControllerProvider);
    expect(state.isLoggedIn, isFalse);
    expect(state.isBusy, isFalse);
    expect(state.error, '로그인 거부');
  });

  test('피드백 조정값은 nullable intensityCap 응답을 허용한다', () {
    final adjustment = FeedbackAdjustment.fromJson({
      'intensityCap': null,
      'requiresReview': false,
      'reason': '유지',
      'reasonCode': 'FEEDBACK_MAINTAINED',
    });
    expect(adjustment.intensityCap, isNull);
    expect(adjustment.requiresReview, isFalse);
  });

  test('백그라운드 전환은 미사용 허가를 폐기하고 연결을 해제한다', () async {
    final gateway = _FakeDeviceGateway();
    final container = _container(gateway: gateway);
    addTearDown(container.dispose);
    final controller = container.read(pilotControllerProvider.notifier);

    await controller.login('USER-001', '123456');
    controller.updateSafety(pain: false, dizziness: false, hold: false);
    await controller.sendToDevice();
    expect(
      container.read(pilotControllerProvider).pendingAuthorization,
      isNotNull,
    );

    await controller.onAppBackgrounded();
    final state = container.read(pilotControllerProvider);
    expect(state.pendingAuthorization, isNull);
    expect(state.deviceState, DeviceConnectionState.disconnected);
    expect(gateway.disconnectReason, 'app_backgrounded');
  });
}

ProviderContainer _container({
  required DeviceGateway gateway,
  AuthRepository authRepository = const _SuccessfulAuthRepository(),
}) => ProviderContainer(
  overrides: [
    appEnvironmentProvider.overrideWithValue(
      const AppEnvironment(
        apiBaseUrl: '',
        sourceDeviceId: 'TEST-BIA',
        targetDeviceId: 'TEST-VIBRATION',
      ),
    ),
    authRepositoryProvider.overrideWithValue(authRepository),
    fitrusRepositoryProvider.overrideWithValue(const _SnapshotRepository()),
    deviceGatewayProvider.overrideWithValue(gateway),
  ],
);

class _SuccessfulAuthRepository implements AuthRepository {
  const _SuccessfulAuthRepository();

  @override
  Future<AuthSession> login({
    required String participantCode,
    required String pin,
  }) async => const AuthSession(
    participant: ParticipantProfile(
      id: 'TEST-001',
      code: 'TEST-001',
      age: 60,
      sex: ParticipantSex.male,
      heightCm: 150,
    ),
    accessToken: 'access',
    refreshToken: 'refresh',
  );
}

class _FailingAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String participantCode,
    required String pin,
  }) => throw StateError('로그인 거부');
}

class _SnapshotRepository implements FitrusRepository {
  const _SnapshotRepository();

  @override
  Future<MeasurementSnapshot> loadSnapshot({
    required ParticipantProfile participant,
    required String deviceId,
  }) async {
    final measurements = [
      for (var index = 0; index < 4; index++)
        BiaMeasurement(
          id: 'M-$index',
          participantId: participant.id,
          deviceId: deviceId,
          measuredAt: DateTime.utc(2026, 9, 1, 12, index),
          qualityPassed: true,
          values: const BiaValues(
            weightKg: 60,
            bmi: 26.6666666667,
            bodyFatPct: 20,
            fatMassKg: 12,
            skeletalMuscleMassKg: 22.5,
          ),
        ),
    ];
    return MeasurementSnapshot(
      bodyCompositionHistory: measurements,
      selectedMeasurements: measurements,
      vitals: const [],
      syncedAt: DateTime.utc(2026, 9, 1, 12, 4),
      ruleSet: pilotRuleSet,
    );
  }
}

class _FakeDeviceGateway implements DeviceGateway {
  final _states = StreamController<DeviceConnectionState>.broadcast();
  DeviceCommand? _command;
  String? stopReason;
  String? disconnectReason;

  @override
  Stream<DeviceConnectionState> get statusStream => _states.stream;

  @override
  Future<void> connect(String deviceId) async {
    _states.add(DeviceConnectionState.ready);
  }

  @override
  Future<DeviceAuthorization> authorize({
    required AlgorithmResult result,
    required ParticipantProfile participant,
    required SafetyCheck safety,
    required int intensityPct,
    required String sourceDeviceId,
  }) async {
    final now = DateTime.now();
    final recommendation = result.recommendation!;
    _command = DeviceCommand(
      authorizationId: 'AUTH-1',
      participantId: participant.id,
      deviceId: 'TEST-VIBRATION',
      durationSec: recommendation.durationSec,
      frequencyHz: recommendation.frequencyHz,
      intensityPct: intensityPct,
      algorithmVersion: result.algorithmVersion,
      issuedAt: now,
      expiresAt: now.add(const Duration(minutes: 1)),
      idempotencyKey: 'KEY-1',
    );
    return DeviceAuthorization(command: _command!);
  }

  @override
  Future<DeviceSession> start(DeviceAuthorization authorization) async {
    _states.add(DeviceConnectionState.running);
    return DeviceSession(
      id: 'SESSION-1',
      startedAt: DateTime.now(),
      command: authorization.command,
    );
  }

  @override
  Future<void> stop(String sessionId, String reason) async {
    stopReason = reason;
    _states.add(DeviceConnectionState.completed);
  }

  @override
  Future<void> disconnect(String reason) async {
    disconnectReason = reason;
    _states.add(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> dispose() => _states.close();
}
