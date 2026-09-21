import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/skeletal_muscle_assessment.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';
import 'package:vibecare_pilot/models/models.dart';

void main() {
  test('최신 골격근량을 여성 근육지수 경계로 분류하고 직전값과 비교한다', () {
    final assessment = buildSkeletalMuscleAssessment(
      profile: const ParticipantProfile(
        id: 'P1',
        age: 72,
        sex: ParticipantSex.female,
        heightCm: 150,
      ),
      history: [
        _measurement('new', DateTime.utc(2026, 9, 18), muscleKg: 12.8),
        _measurement('old', DateTime.utc(2026, 9, 17), muscleKg: 12.6),
      ],
      ruleSet: pilotRuleSet,
    );

    expect(assessment, isNotNull);
    expect(assessment!.level, SkeletalMuscleLevel.low);
    expect(assessment.currentKg, 12.8);
    expect(assessment.currentIndexKgM2, closeTo(5.69, 0.01));
    expect(assessment.deltaKg, closeTo(0.2, 0.001));
  });

  test('체지방률이 같아도 남성 골격근지수는 낮음, 중간, 높음을 구분한다', () {
    const profile = ParticipantProfile(
      id: 'P1',
      age: 45,
      sex: ParticipantSex.male,
      heightCm: 180,
    );

    SkeletalMuscleAssessment? assess(double muscleKg) =>
        buildSkeletalMuscleAssessment(
          profile: profile,
          history: [
            _measurement(
              'M-$muscleKg',
              DateTime.utc(2026, 9, 18),
              muscleKg: muscleKg,
            ),
          ],
          ruleSet: pilotRuleSet,
        );

    expect(assess(26)!.level, SkeletalMuscleLevel.low);
    expect(assess(30)!.level, SkeletalMuscleLevel.medium);
    expect(assess(36)!.level, SkeletalMuscleLevel.high);
  });

  test('화면 판정도 경계에서 반올림 전 근육지수를 사용한다', () {
    final assessment = buildSkeletalMuscleAssessment(
      profile: const ParticipantProfile(
        id: 'P1',
        age: 45,
        sex: ParticipantSex.male,
        heightCm: 170,
      ),
      history: [
        _measurement('boundary', DateTime.utc(2026, 9, 18), muscleKg: 24.57),
      ],
      ruleSet: pilotRuleSet,
    );

    expect(assessment, isNotNull);
    expect(assessment!.currentIndexKgM2, greaterThan(8.5));
    expect(assessment.level, SkeletalMuscleLevel.medium);
  });
}

BiaMeasurement _measurement(
  String id,
  DateTime measuredAt, {
  required double muscleKg,
}) => BiaMeasurement(
  id: id,
  participantId: 'P1',
  deviceId: 'BIA-1',
  measuredAt: measuredAt,
  qualityPassed: true,
  muscleDefinition: MuscleMassBasis.smm,
  muscleMeasurementMethod: 'BIA_TEST',
  acquisitionProtocolRef: 'TEST',
  values: BiaValues(
    weightKg: 60,
    bmi: 22,
    bodyFatPct: 20,
    fatMassKg: 12,
    skeletalMuscleMassKg: muscleKg,
  ),
);
