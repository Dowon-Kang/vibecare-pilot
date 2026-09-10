import '../models/models.dart';

enum DeviceConnectionState {
  disconnected,
  connecting,
  ready,
  authorized,
  starting,
  running,
  stopping,
  completed,
  error,
}

class DeviceCommand {
  const DeviceCommand({
    required this.authorizationId,
    required this.participantId,
    required this.deviceId,
    required this.durationSec,
    required this.frequencyHz,
    required this.intensityPct,
    required this.algorithmVersion,
    required this.issuedAt,
    required this.expiresAt,
    required this.idempotencyKey,
    this.executionMode = 'SIMULATOR_ONLY',
  });

  final String authorizationId;
  final String participantId;
  final String deviceId;
  final int durationSec;
  final int frequencyHz;
  final int intensityPct;
  final String algorithmVersion;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String idempotencyKey;
  final String executionMode;

  Map<String, Object> toJson() => {
    'authorizationId': authorizationId,
    'participantId': participantId,
    'deviceId': deviceId,
    'durationSec': durationSec,
    'frequencyHz': frequencyHz,
    'intensityPct': intensityPct,
    'algorithmVersion': algorithmVersion,
    'issuedAt': issuedAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'idempotencyKey': idempotencyKey,
    'executionMode': executionMode,
  };
}

class DeviceAuthorization {
  const DeviceAuthorization({required this.command});

  final DeviceCommand command;
}

class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.startedAt,
    required this.command,
  });

  final String id;
  final DateTime startedAt;
  final DeviceCommand command;
}

abstract interface class DeviceGateway {
  Stream<DeviceConnectionState> get statusStream;
  Future<void> connect(String deviceId);
  Future<DeviceAuthorization> authorize({
    required AlgorithmResult result,
    required ParticipantProfile participant,
    required SafetyCheck safety,
    required int intensityPct,
    required String sourceDeviceId,
  });
  Future<DeviceSession> start(DeviceAuthorization authorization);
  Future<void> stop(String sessionId, String reason);
  Future<void> disconnect(String reason);
  Future<void> dispose();
}
