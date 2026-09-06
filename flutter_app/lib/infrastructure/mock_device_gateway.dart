import 'dart:async';

import '../domain/models.dart';
import 'device_gateway.dart';

class MockDeviceGateway implements DeviceGateway {
  final _states = StreamController<DeviceConnectionState>.broadcast();
  String? _deviceId;
  String? _activeSessionId;
  bool _disposed = false;

  @override
  Stream<DeviceConnectionState> get statusStream => _states.stream;

  void _emit(DeviceConnectionState state) {
    if (!_disposed) _states.add(state);
  }

  @override
  Future<void> connect(String deviceId) async {
    if (_activeSessionId != null) throw StateError('이미 실행 중인 세션이 있습니다.');
    _emit(DeviceConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _deviceId = deviceId;
    _emit(DeviceConnectionState.ready);
  }

  @override
  Future<DeviceAuthorization> authorize({
    required AlgorithmResult result,
    required ParticipantProfile participant,
  }) async {
    final recommendation = result.recommendation;
    if (!result.canRequestAuthorization ||
        recommendation == null ||
        _deviceId == null) {
      throw StateError('READY 상태와 연결된 Mock 기기가 필요합니다.');
    }
    final now = DateTime.now();
    _emit(DeviceConnectionState.authorized);
    return DeviceAuthorization(
      command: DeviceCommand(
        authorizationId: 'MOCK-AUTH-${now.microsecondsSinceEpoch}',
        participantId: participant.id,
        deviceId: _deviceId!,
        durationSec: recommendation.durationSec,
        frequencyHz: recommendation.frequencyHz,
        intensityPct: recommendation.intensityPct,
        algorithmVersion: result.algorithmVersion,
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
        idempotencyKey: 'mock-${participant.id}-${now.microsecondsSinceEpoch}',
      ),
    );
  }

  @override
  Future<DeviceSession> start(DeviceAuthorization authorization) async {
    if (_activeSessionId != null) throw StateError('중복 실행은 허용되지 않습니다.');
    if (authorization.command.expiresAt.isBefore(DateTime.now())) {
      throw StateError('실행 허가가 만료되었습니다.');
    }
    if (authorization.command.deviceId != _deviceId) {
      throw StateError('실행 허가와 연결 기기가 다릅니다.');
    }
    _emit(DeviceConnectionState.starting);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final id = 'MOCK-${DateTime.now().millisecondsSinceEpoch}';
    _activeSessionId = id;
    _emit(DeviceConnectionState.running);
    return DeviceSession(
      id: id,
      startedAt: DateTime.now(),
      command: authorization.command,
    );
  }

  @override
  Future<void> stop(String sessionId, String reason) async {
    if (_activeSessionId != sessionId) return;
    _emit(DeviceConnectionState.stopping);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _activeSessionId = null;
    _emit(DeviceConnectionState.completed);
    _emit(DeviceConnectionState.ready);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _states.close();
  }
}
