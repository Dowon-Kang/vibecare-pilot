import 'dart:async';

import 'package:dio/dio.dart';

import '../models/models.dart';
import 'device_gateway.dart';
import 'device_state_machine.dart';

/// Uses the VibeCare backend API safety boundary.
///
/// This gateway never talks directly to a vibration device. The backend API
/// recalculates the recommendation, issues a one-time authorization and then
/// starts only the server-side simulator. Physical device mode is rejected.
class BackendDeviceGateway implements DeviceGateway {
  BackendDeviceGateway(
    this._dio, {
    this.ackTimeout = const Duration(seconds: 10),
    this.stopTimeout = const Duration(seconds: 10),
  });

  final Dio _dio;
  final Duration ackTimeout;
  final Duration stopTimeout;
  final _states = StreamController<DeviceConnectionState>.broadcast();
  final _machine = DeviceStateMachine();
  String? _deviceId;
  String? _activeSessionId;
  bool _disposed = false;

  @override
  Stream<DeviceConnectionState> get statusStream => _states.stream;

  void _emit(DeviceConnectionState value) {
    _machine.transition(value);
    if (!_disposed) _states.add(value);
  }

  @override
  Future<void> connect(String deviceId) async {
    _emit(DeviceConnectionState.connecting);
    try {
      final response = await _dio.get<Map<String, dynamic>>('/ready');
      if (response.data?['ready'] != true) {
        throw StateError('서버가 실행 준비 상태가 아닙니다.');
      }
      _deviceId = deviceId;
      _emit(DeviceConnectionState.ready);
    } catch (_) {
      _emit(DeviceConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<DeviceAuthorization> authorize({
    required AlgorithmResult result,
    required ParticipantProfile participant,
    required SafetyCheck safety,
    required int intensityPct,
    required String sourceDeviceId,
  }) async {
    final local = result.recommendation;
    final deviceId = _deviceId;
    if (!safety.isComplete ||
        safety.hasSymptoms ||
        !result.canRequestAuthorization ||
        local == null ||
        deviceId == null) {
      throw StateError('시뮬레이션 준비 상태와 연결된 서버가 필요합니다.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/recommendations/authorize',
      data: {
        'measurementIds': result.measurementIds,
        'safety': {
          'acutePain': safety.acutePain,
          'dizziness': safety.dizziness,
          'clinicianHold': safety.clinicianHold,
        },
        'deviceId': deviceId,
        'sourceDeviceId': sourceDeviceId,
        'algorithmVersion': result.algorithmVersion,
        'muscleMassBasis': result.muscleAssessment?.basis.name.toUpperCase(),
        'requestedIntensityPct': intensityPct,
      },
    );
    final json = response.data ?? const <String, dynamic>{};
    final serverResult = json['result'] as Map<String, dynamic>?;
    final serverRecommendation =
        serverResult?['recommendation'] as Map<String, dynamic>?;
    if (json['authorized'] != true ||
        json['mode'] != 'mock' ||
        serverResult?['realDeviceSendAllowed'] != false ||
        serverResult?['physicalExecution'] != 'PROHIBITED' ||
        serverResult?['simulationEligibility'] != 'ELIGIBLE' ||
        serverRecommendation == null) {
      throw StateError('서버가 실행을 허가하지 않았습니다.');
    }
    final serverDuration = serverRecommendation['durationSec'] as num;
    final serverFrequency = serverRecommendation['frequencyHz'] as num;
    final serverIntensity = serverRecommendation['intensityPct'] as num;
    if (serverResult?['algorithmVersion'] != result.algorithmVersion ||
        serverDuration != local.durationSec ||
        serverFrequency != local.frequencyHz ||
        serverIntensity != intensityPct) {
      throw StateError('앱 미리보기와 서버 계산이 달라 실행을 중단했습니다.');
    }
    final now = DateTime.now();
    _emit(DeviceConnectionState.authorized);
    return DeviceAuthorization(
      command: DeviceCommand(
        authorizationId: json['authorizationId'] as String,
        participantId: participant.id,
        deviceId: deviceId,
        durationSec: serverDuration.toInt(),
        frequencyHz: serverFrequency.toInt(),
        intensityPct: serverIntensity.toInt(),
        algorithmVersion: serverResult?['algorithmVersion'] as String,
        issuedAt: now,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        idempotencyKey:
            'mobile-${participant.id}-${now.microsecondsSinceEpoch}',
        executionMode: 'SIMULATOR_ONLY',
      ),
    );
  }

  @override
  Future<DeviceSession> start(DeviceAuthorization authorization) async {
    if (_deviceId == null || authorization.command.deviceId != _deviceId) {
      throw StateError('실행 허가와 현재 연결 대상이 다릅니다.');
    }
    _emit(DeviceConnectionState.starting);
    try {
      final command = authorization.command;
      final response = await _dio
          .post<Map<String, dynamic>>(
            '/v1/device-sessions',
            data: {
              'authorizationId': command.authorizationId,
              'deviceId': command.deviceId,
            },
            options: Options(
              headers: {'Idempotency-Key': command.idempotencyKey},
            ),
          )
          .timeout(ackTimeout);
      final json = response.data ?? const <String, dynamic>{};
      if (json['status'] != 'RUNNING' || json['mode'] != 'mock') {
        throw StateError('기기 ACK를 확인하지 못했습니다.');
      }
      _emit(DeviceConnectionState.running);
      _activeSessionId = json['sessionId'] as String;
      return DeviceSession(
        id: _activeSessionId!,
        startedAt: DateTime.now(),
        command: command,
      );
    } catch (_) {
      _emit(DeviceConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<void> stop(String sessionId, String reason) async {
    if (_activeSessionId != sessionId) {
      throw StateError('중지할 활성 세션을 찾을 수 없습니다.');
    }
    _emit(DeviceConnectionState.stopping);
    try {
      final response = await _dio
          .post<Map<String, dynamic>>(
            '/v1/device-sessions/$sessionId/stop',
            data: {'reason': reason},
          )
          .timeout(stopTimeout);
      if (!['STOPPED', 'COMPLETED'].contains(response.data?['status'])) {
        throw StateError('중지 완료 응답을 확인하지 못했습니다. 다시 요청해 주세요.');
      }
      _activeSessionId = null;
      _emit(DeviceConnectionState.completed);
      _emit(DeviceConnectionState.ready);
    } catch (_) {
      _emit(DeviceConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect(String reason) async {
    if (_activeSessionId != null) {
      throw StateError('실행 중에는 중지 확인 없이 연결을 해제할 수 없습니다.');
    }
    _deviceId = null;
    _emit(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    if (!_disposed && _activeSessionId == null) {
      _deviceId = null;
      if (_machine.state != DeviceConnectionState.disconnected) {
        _emit(DeviceConnectionState.disconnected);
      }
    }
    _disposed = true;
    await _states.close();
  }
}
