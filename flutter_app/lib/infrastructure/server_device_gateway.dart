import 'dart:async';

import 'package:dio/dio.dart';

import '../domain/models.dart';
import 'device_gateway.dart';

/// Uses the VibeCare Worker safety boundary.
///
/// This gateway never talks directly to a vibration device. The Worker
/// recalculates the recommendation, issues a one-time authorization and then
/// starts either its configured device adapter or the server-side simulator.
class ServerDeviceGateway implements DeviceGateway {
  ServerDeviceGateway(this._dio);

  final Dio _dio;
  final _states = StreamController<DeviceConnectionState>.broadcast();
  String? _deviceId;
  bool _disposed = false;

  @override
  Stream<DeviceConnectionState> get statusStream => _states.stream;

  void _emit(DeviceConnectionState value) {
    if (!_disposed) _states.add(value);
  }

  @override
  Future<void> connect(String deviceId) async {
    _emit(DeviceConnectionState.connecting);
    try {
      await _dio.get<Map<String, dynamic>>('/health');
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
  }) async {
    final local = result.recommendation;
    final deviceId = _deviceId;
    if (!result.canRequestAuthorization || local == null || deviceId == null) {
      throw StateError('READY 상태와 연결된 서버가 필요합니다.');
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
        'algorithmVersion': result.algorithmVersion,
        'requestedIntensityPct': intensityPct,
      },
    );
    final json = response.data ?? const <String, dynamic>{};
    final serverResult = json['result'] as Map<String, dynamic>?;
    final serverRecommendation =
        serverResult?['recommendation'] as Map<String, dynamic>?;
    if (json['authorized'] != true || serverRecommendation == null) {
      throw StateError('서버가 실행을 허가하지 않았습니다.');
    }
    final serverDuration = (serverRecommendation['durationSec'] as num).round();
    final serverFrequency = (serverRecommendation['frequencyHz'] as num)
        .round();
    final serverIntensity = (serverRecommendation['intensityPct'] as num)
        .round();
    if (serverDuration != local.durationSec ||
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
        durationSec: serverDuration,
        frequencyHz: serverFrequency,
        intensityPct: serverIntensity,
        algorithmVersion: serverResult?['algorithmVersion'] as String,
        issuedAt: now,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        idempotencyKey:
            'mobile-${participant.id}-${now.microsecondsSinceEpoch}',
      ),
    );
  }

  @override
  Future<DeviceSession> start(DeviceAuthorization authorization) async {
    _emit(DeviceConnectionState.starting);
    try {
      final command = authorization.command;
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/device-sessions',
        data: {
          'authorizationId': command.authorizationId,
          'deviceId': command.deviceId,
        },
        options: Options(headers: {'Idempotency-Key': command.idempotencyKey}),
      );
      final json = response.data ?? const <String, dynamic>{};
      if (json['status'] != 'RUNNING') {
        throw StateError('기기 ACK를 확인하지 못했습니다.');
      }
      _emit(DeviceConnectionState.running);
      return DeviceSession(
        id: json['sessionId'] as String,
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
    _emit(DeviceConnectionState.stopping);
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/device-sessions/$sessionId/stop',
        data: {'reason': reason},
      );
      _emit(DeviceConnectionState.completed);
      _emit(DeviceConnectionState.ready);
    } catch (_) {
      _emit(DeviceConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _states.close();
  }
}
