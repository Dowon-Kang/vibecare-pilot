import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/services/device_gateway.dart';
import 'package:vibecare_pilot/services/device_state_machine.dart';
import 'package:vibecare_pilot/services/mock_device_gateway.dart';

void main() {
  test('state machine rejects running without authorization and start', () {
    final machine = DeviceStateMachine();
    expect(
      () => machine.transition(DeviceConnectionState.running),
      throwsStateError,
    );
    expect(machine.state, DeviceConnectionState.disconnected);
  });

  test('mock fails closed when ACK is not received before timeout', () async {
    final gateway = MockDeviceGateway(
      connectDelay: Duration.zero,
      ackDelay: const Duration(milliseconds: 30),
      ackTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(gateway.dispose);
    final authorization = await _authorization(gateway);

    await expectLater(gateway.start(authorization), throwsStateError);
    await expectLater(gateway.start(authorization), throwsStateError);
  });

  test('mock rejects unknown stop and disconnects only while idle', () async {
    final gateway = MockDeviceGateway(
      connectDelay: Duration.zero,
      ackDelay: Duration.zero,
      stopDelay: Duration.zero,
    );
    addTearDown(gateway.dispose);
    final authorization = await _authorization(gateway);
    await expectLater(gateway.stop('unknown', 'user_stop'), throwsStateError);
    final session = await gateway.start(authorization);
    await expectLater(gateway.disconnect('background'), throwsStateError);
    await gateway.stop(session.id, 'user_stop');
    await gateway.disconnect('background');
  });
}

Future<DeviceAuthorization> _authorization(MockDeviceGateway gateway) async {
  const participant = ParticipantProfile(
    id: 'TEST',
    age: 72,
    sex: ParticipantSex.female,
    heightCm: 150,
  );
  const safety = SafetyCheck.confirmedClear();
  final measurements = <BiaMeasurement>[
    for (var index = 0; index < 4; index++)
      BiaMeasurement(
        id: 'M$index',
        participantId: 'TEST',
        deviceId: 'BIA',
        measuredAt: DateTime.utc(2026, 9, 1),
        qualityPassed: true,
        values: const BiaValues(
          weightKg: 60,
          bmi: 26.6666666667,
          bodyFatPct: 25,
          fatMassKg: 15,
          skeletalMuscleMassKg: 20,
        ),
      ),
  ];
  final result = calculateRecommendation(
    profile: participant,
    measurements: measurements,
    safety: safety,
  );
  await gateway.connect('SIMULATOR');
  return gateway.authorize(
    result: result,
    participant: participant,
    safety: safety,
    intensityPct: result.recommendation!.intensityPct,
    sourceDeviceId: 'BIA',
  );
}
