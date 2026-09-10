import 'dart:async';

import '../models/models.dart';
import 'device_gateway.dart';
import 'device_state_machine.dart';

class MockDeviceGateway implements DeviceGateway {
  MockDeviceGateway({
    this.connectDelay = const Duration(milliseconds: 250),
    this.ackDelay = const Duration(milliseconds: 200),
    this.stopDelay = const Duration(milliseconds: 100),
    this.ackTimeout = const Duration(seconds: 5),
    this.stopTimeout = const Duration(seconds: 5),
  });

  final Duration connectDelay;
  final Duration ackDelay;
  final Duration stopDelay;
  final Duration ackTimeout;
  final Duration stopTimeout;
  final _states = StreamController<DeviceConnectionState>.broadcast();
  final _machine = DeviceStateMachine();
  String? _deviceId;
  String? _activeSessionId;
  bool _disposed = false;
  bool _starting = false;
  final _usedAuthorizations = <String>{};

  @override
  Stream<DeviceConnectionState> get statusStream => _states.stream;

  void _emit(DeviceConnectionState state) {
    _machine.transition(state);
    if (!_disposed) _states.add(state);
  }

  @override
  Future<void> connect(String deviceId) async {
    if (_activeSessionId != null || _starting) {
      throw StateError('이미 실행 중인 세션이 있습니다.');
    }
    _emit(DeviceConnectionState.connecting);
    await Future<void>.delayed(connectDelay);
    _deviceId = deviceId;
    _emit(DeviceConnectionState.ready);
  }

  @override
  Future<DeviceAuthorization> authorize({
    required AlgorithmResult result,
    required ParticipantProfile participant,
    required SafetyCheck safety,
    required int intensityPct,
    required String sourceDeviceId,
  }) async {
    final recommendation = result.recommendation;
    if (!safety.isComplete ||
        safety.hasSymptoms ||
        !result.canRequestAuthorization ||
        recommendation == null ||
        _deviceId == null) {
      throw StateError('READY 상태와 연결된 Mock 기기가 필요합니다.');
    }
    final now = DateTime.now();
    if (intensityPct < 20 || intensityPct > recommendation.intensityPct) {
      throw StateError('시연 허용 강도를 벗어났습니다.');
    }
    _emit(DeviceConnectionState.authorized);
    return DeviceAuthorization(
      command: DeviceCommand(
        authorizationId: 'MOCK-AUTH-${now.microsecondsSinceEpoch}',
        participantId: participant.id,
        deviceId: _deviceId!,
        durationSec: recommendation.durationSec,
        frequencyHz: recommendation.frequencyHz,
        intensityPct: intensityPct,
        algorithmVersion: result.algorithmVersion,
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
        idempotencyKey: 'mock-${participant.id}-${now.microsecondsSinceEpoch}',
      ),
    );
  }

  @override
  Future<DeviceSession> start(DeviceAuthorization authorization) async {
    if (_activeSessionId != null || _starting) {
      throw StateError('중복 실행은 허용되지 않습니다.');
    }
    if (_usedAuthorizations.contains(authorization.command.authorizationId)) {
      throw StateError('이미 사용한 허가입니다.');
    }
    if (authorization.command.expiresAt.isBefore(DateTime.now())) {
      throw StateError('실행 허가가 만료되었습니다.');
    }
    if (authorization.command.deviceId != _deviceId) {
      throw StateError('실행 허가와 연결 기기가 다릅니다.');
    }
    _emit(DeviceConnectionState.starting);
    _starting = true;
    _usedAuthorizations.add(authorization.command.authorizationId);
    try {
      await Future<void>.delayed(ackDelay).timeout(ackTimeout);
      final id = 'MOCK-${DateTime.now().millisecondsSinceEpoch}';
      _activeSessionId = id;
      _starting = false;
      _emit(DeviceConnectionState.running);
      return DeviceSession(
        id: id,
        startedAt: DateTime.now(),
        command: authorization.command,
      );
    } on TimeoutException {
      _starting = false;
      _emit(DeviceConnectionState.error);
      throw StateError('시뮬레이터 ACK 제한 시간을 초과했습니다.');
    }
  }

  @override
  Future<void> stop(String sessionId, String reason) async {
    if (_activeSessionId != sessionId) {
      throw StateError('중지할 활성 세션을 찾을 수 없습니다.');
    }
    _emit(DeviceConnectionState.stopping);
    try {
      await Future<void>.delayed(stopDelay).timeout(stopTimeout);
      _activeSessionId = null;
      _emit(DeviceConnectionState.completed);
      _emit(DeviceConnectionState.ready);
    } on TimeoutException {
      _emit(DeviceConnectionState.error);
      throw StateError('시뮬레이터 중지 확인 제한 시간을 초과했습니다.');
    }
  }

  @override
  Future<void> disconnect(String reason) async {
    if (_activeSessionId != null || _starting) {
      throw StateError('실행 중에는 중지 확인 없이 연결을 해제할 수 없습니다.');
    }
    _deviceId = null;
    _emit(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    if (!_disposed && _activeSessionId == null && !_starting) {
      _deviceId = null;
      if (_machine.state != DeviceConnectionState.disconnected) {
        _emit(DeviceConnectionState.disconnected);
      }
    }
    _disposed = true;
    await _states.close();
  }
}
