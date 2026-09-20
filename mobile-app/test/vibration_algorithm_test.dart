import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';
import 'package:vibecare_pilot/models/models.dart';

const safety = SafetyCheck.confirmedClear();

List<BiaMeasurement> measurements(double bodyFatPct) => [1, 2, 3, 4]
    .map(
      (index) => BiaMeasurement(
        id: 'M$index',
        participantId: 'P1',
        deviceId: 'BIA',
        measuredAt: DateTime.utc(2026, 9, index),
        qualityPassed: true,
        muscleDefinition: MuscleMassBasis.smm,
        muscleMeasurementMethod: 'BIA',
        acquisitionProtocolRef: 'TEST',
        values: BiaValues(
          weightKg: 60,
          bmi: 22,
          bodyFatPct: bodyFatPct,
          fatMassKg: 60 * bodyFatPct / 100,
          skeletalMuscleMassKg: 24,
        ),
      ),
    )
    .toList();

AlgorithmResult evaluate({
  required int age,
  required ParticipantSex sex,
  required double bodyFat,
  BodyPart part = BodyPart.wholeBody,
  AlgorithmRuleSet rules = pilotRuleSet,
}) => calculateRecommendation(
  profile: ParticipantProfile(id: 'P1', age: age, sex: sex, heightCm: 170),
  measurements: measurements(bodyFat),
  safety: safety,
  bodyPart: part,
  ruleSet: rules,
  evaluatedAt: DateTime.utc(2026, 9, 10),
);

void main() {
  test('Case A: male under 60 and normal body fat keeps baseline', () {
    final result = evaluate(age: 30, sex: ParticipantSex.male, bodyFat: 20);
    expect(result.recommendation?.baseIntensityPct, 90);
    expect(result.recommendation?.intensityPct, 90);
    expect(result.factors?.totalCoefficient, 1);
  });

  test('Case B: female medium body fat uses the fixed medium preset', () {
    final result = evaluate(age: 30, sex: ParticipantSex.female, bodyFat: 25);
    expect(result.recommendation?.intensityPct, 90);
    expect(result.recommendation?.durationSec, 1800);
    expect(result.factors?.genderCoefficient, 1);
  });

  test('Case C: age does not alter the fixed body-fat preset', () {
    final result = evaluate(age: 75, sex: ParticipantSex.female, bodyFat: 25);
    expect(result.recommendation?.intensityPct, 90);
    expect(result.factors?.totalCoefficient, 1);
  });

  test('Case D: low body fat selects the exact low whole-body preset', () {
    final result = evaluate(age: 75, sex: ParticipantSex.female, bodyFat: 18);
    expect(result.recommendation?.durationSec, 1500);
    expect(result.recommendation?.frequencyHz, 8);
    expect(result.recommendation?.intensityPct, 80);
    expect(result.factors?.bodyFatCoefficient, 1);
    expect(result.factors?.bodyFatBand, 'low');
  });

  test('Case E: high body fat selects the exact high whole-body preset', () {
    final result = evaluate(age: 85, sex: ParticipantSex.female, bodyFat: 36);
    expect(result.recommendation?.durationSec, 2100);
    expect(result.recommendation?.frequencyHz, 8);
    expect(result.recommendation?.intensityPct, 99);
    expect(result.factors?.bodyFatBand, 'high');
  });

  test('calculates all six body parts from data', () {
    final all = calculateAllRecommendations(
      profile: const ParticipantProfile(
        id: 'P1',
        age: 30,
        sex: ParticipantSex.male,
        heightCm: 170,
      ),
      measurements: measurements(20),
      safety: safety,
      evaluatedAt: DateTime.utc(2026, 9, 10),
    );
    expect(all.keys, containsAll(BodyPart.values));
    expect(all[BodyPart.shoulder]?.recommendation?.frequencyHz, 15);
    expect(all[BodyPart.thigh]?.recommendation?.durationSec, 600);
    expect(all[BodyPart.calf]?.recommendation?.intensityPct, 70);
  });
}
