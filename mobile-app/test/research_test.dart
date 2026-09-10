import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/services/feedback_repository.dart';
import 'package:vibecare_pilot/services/mock_device_gateway.dart';

void main() {
  final fixture = jsonDecode(
    File(
      '../shared-contracts/fixtures/pilot-0.6.0-boundaries.json',
    ).readAsStringSync(),
  );
  for (final c in fixture['cases']) {
    test('shared precision: ${c['id']}', () {
      final result = calculateRecommendation(
        profile: ParticipantProfile(
          id: 'TEST',
          age: c['age'],
          sex: ParticipantSex.values.byName(c['sex']),
          heightCm: 200,
        ),
        measurements: rows(
          (c['muscles'] as List).map((v) => (v as num).toDouble()).toList(),
          (c['bmi'] as num).toDouble(),
        ),
        safety: SafetyCheck(
          acutePain: false,
          dizziness: c['dizziness'] ?? false,
          clinicianHold: false,
        ),
      );
      expect(result.status.name.toUpperCase(), c['status']);
      expect(result.executionStatus, c['executionStatus']);
      expect(result.muscleAssessment?.level.name, c['tier']);
      expect(result.realDeviceSendAllowed, isFalse);
      if (c['tier'] != null) {
        final p = {
          'low': [180, 12, 30],
          'medium': [240, 16, 40],
          'reference': [300, 20, 50],
        }[c['tier']];
        expect([
          result.recommendation!.durationSec,
          result.recommendation!.frequencyHz,
          result.recommendation!.intensityPct,
        ], p);
      }
    });
  }
  test(
    'feedback is idempotent, rejects conflicting retries and never raises',
    () async {
      final repo = FeedbackRepository();
      const strong = SessionFeedback(
        rpe: 2,
        pain: 0,
        dizziness: false,
        intensityRating: FeedbackRating.strong,
        durationRating: FeedbackRating.suitable,
        frequencyRating: FeedbackRating.suitable,
      );
      final first = await repo.save('T', 'S', 50, strong);
      expect(first.intensityCap, 45);
      expect((await repo.save('T', 'S', 50, strong)).intensityCap, 45);
      await expectLater(
        repo.save('T', 'S', 50, strong.withExecution(earlyStopped: true)),
        throwsStateError,
      );
      expect(
        first.next(strong.withExecution(earlyStopped: true), 45).requiresReview,
        isTrue,
      );
    },
  );
  test('mock prevents concurrent start and reuse after stop', () async {
    final gateway = MockDeviceGateway();
    addTearDown(gateway.dispose);
    const p = ParticipantProfile(
      id: 'TEST',
      age: 72,
      sex: ParticipantSex.female,
      heightCm: 200,
    );
    const safety = SafetyCheck.confirmedClear();
    final result = calculateRecommendation(
      profile: p,
      measurements: rows([28, 28, 28, 28], 20),
      safety: safety,
    );
    await gateway.connect('MOCK');
    final auth = await gateway.authorize(
      result: result,
      participant: p,
      safety: safety,
      intensityPct: 50,
      sourceDeviceId: 'BIA',
    );
    final pending = gateway.start(auth);
    await expectLater(gateway.start(auth), throwsStateError);
    final session = await pending;
    await gateway.stop(session.id, 'completed');
    await expectLater(gateway.start(auth), throwsStateError);
  });
}

List<BiaMeasurement> rows(List<double> masses, double bmi) => [
  for (var i = 0; i < masses.length; i++)
    BiaMeasurement(
      id: 'M$i',
      participantId: 'TEST',
      deviceId: 'BIA',
      measuredAt: DateTime.utc(2026, 9, 1),
      qualityPassed: true,
      values: BiaValues(
        weightKg: bmi * 4,
        bmi: bmi,
        bodyFatPct: 25,
        fatMassKg: bmi,
        skeletalMuscleMassKg: masses[i],
      ),
    ),
];
