import 'dart:convert';
import 'dart:io';
import 'package:vibecare_pilot/services/device_gateway.dart';

// Synthetic command: validates serialization only; not an execution permit.
void main() {
  final command = DeviceCommand(
    authorizationId: 'EXAMPLE-NOT-ACTIVE',
    participantId: 'SYNTHETIC',
    deviceId: 'VIBECARE-SIM-01',
    durationSec: 300,
    frequencyHz: 20,
    intensityPct: 50,
    algorithmVersion: 'pilot-0.6.0',
    issuedAt: DateTime.utc(2026, 9, 7),
    expiresAt: DateTime.utc(2026, 9, 7, 0, 1),
    idempotencyKey: 'example-not-an-active-permit',
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(command.toJson()));
}
