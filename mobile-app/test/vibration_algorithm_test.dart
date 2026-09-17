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

  test('Case B: female coefficient only', () {
    final result = evaluate(age: 30, sex: ParticipantSex.female, bodyFat: 25);
    expect(result.recommendation?.intensityPct, 86);
    expect(result.factors?.genderCoefficient, .95);
  });

  test('Case C: female and age-70 coefficients multiply', () {
    final result = evaluate(age: 75, sex: ParticipantSex.female, bodyFat: 25);
    expect(result.recommendation?.intensityPct, 77);
    expect(result.factors?.totalCoefficient, .855);
  });

  test('Case D: low body fat adds another five-percent reduction', () {
    final result = evaluate(age: 75, sex: ParticipantSex.female, bodyFat: 18);
    expect(result.recommendation?.intensityPct, 73);
    expect(result.factors?.bodyFatCoefficient, .95);
    expect(result.factors?.bodyFatBand, 'low');
  });

  test('Case E: clamp prevents output below configured minimum', () {
    final rules = AlgorithmRuleSet(
      version: pilotRuleSet.version,
      enabled: true,
      baselines: pilotRuleSet.baselines,
      femaleCoefficient: .5,
      maleCoefficient: 1,
      ageUnder60Coefficient: 1,
      ageSixtiesCoefficient: .95,
      ageSeventiesCoefficient: .9,
      ageEightyPlusCoefficient: .85,
      femaleBodyFat: pilotRuleSet.femaleBodyFat,
      maleBodyFat: pilotRuleSet.maleBodyFat,
      lowBodyFatCoefficient: .95,
      normalBodyFatCoefficient: 1,
      highBodyFatCoefficient: .95,
      muscleMassCoefficient: 1,
      minimumPct: 70,
      maximumPct: 99,
    );
    final result = evaluate(
      age: 85,
      sex: ParticipantSex.female,
      bodyFat: 18,
      part: BodyPart.calf,
      rules: rules,
    );
    expect(result.factors!.calculatedIntensityPct, lessThan(70));
    expect(result.recommendation?.intensityPct, 70);
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
