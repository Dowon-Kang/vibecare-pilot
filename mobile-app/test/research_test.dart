import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/services/feedback_repository.dart';
import 'package:vibecare_pilot/services/mock_device_gateway.dart';

void main() {
  test('UNKNOWN 정의는 통계·추천·시뮬레이션 허가를 차단한다', () {
    const profile = ParticipantProfile(
      id: 'TEST',
      age: 72,
      sex: ParticipantSex.female,
      heightCm: 200,
    );
    final unknown = [
      for (final measurement in rows([28, 28, 28, 28], 20))
        BiaMeasurement(
          id: measurement.id,
          participantId: measurement.participantId,
          deviceId: measurement.deviceId,
          measuredAt: measurement.measuredAt,
          qualityPassed: true,
          muscleDefinition: MuscleMassBasis.unknown,
          values: measurement.values,
        ),
    ];
    final result = calculateRecommendation(
      profile: profile,
      measurements: unknown,
      safety: const SafetyCheck.confirmedClear(),
    );
    expect(result.status, RecommendationStatus.review);
    expect(result.muscleAssessment, isNull);
    expect(result.recommendation, isNull);
    expect(result.simulationEligibility, 'INELIGIBLE');
    expect(result.physicalExecution, 'PROHIBITED');
  });
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
      muscleDefinition: MuscleMassBasis.smm,
      muscleMeasurementMethod: 'BIA_TEST',
      methodEvidenceRef: 'TEST-METHOD-EVIDENCE-V1',
      definitionRef: 'SMM-TEST-V1',
      acquisitionProtocolRef: 'TEST-STANDARD-V1',
      values: BiaValues(
        weightKg: bmi * 4,
        bmi: bmi,
        bodyFatPct: 25,
        fatMassKg: bmi,
        skeletalMuscleMassKg: masses[i],
      ),
    ),
];
