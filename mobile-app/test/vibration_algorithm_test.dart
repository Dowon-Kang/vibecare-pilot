import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';
import 'package:vibecare_pilot/models/models.dart';

const safety = SafetyCheck.confirmedClear();

List<BiaMeasurement> measurements(double bodyFatPct, double muscleKg) =>
    [1, 2, 3, 4]
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
              skeletalMuscleMassKg: muscleKg,
            ),
          ),
        )
        .toList();

AlgorithmResult evaluate({
  required int age,
  required ParticipantSex sex,
  required double bodyFat,
  required double muscleKg,
  BodyPart part = BodyPart.wholeBody,
  AlgorithmRuleSet rules = pilotRuleSet,
}) => calculateRecommendation(
  profile: ParticipantProfile(id: 'P1', age: age, sex: sex, heightCm: 170),
  measurements: measurements(bodyFat, muscleKg),
  safety: safety,
  bodyPart: part,
  ruleSet: rules,
  evaluatedAt: DateTime.utc(2026, 9, 10),
);

void main() {
  test('three illustrative 0.95 factors reduce simulator intensity', () {
    final result = evaluate(
      age: 75,
      sex: ParticipantSex.female,
      bodyFat: 36,
      muscleKg: 18,
    );
    expect(result.factors?.totalCoefficient, closeTo(0.857375, 0.000001));
    expect(result.recommendation?.baseIntensityPct, 90);
    expect(result.recommendation?.intensityPct, 77);
  });
  test('Case A: male medium muscle index keeps baseline', () {
    final result = evaluate(
      age: 30,
      sex: ParticipantSex.male,
      bodyFat: 20,
      muscleKg: 28,
    );
    expect(result.recommendation?.baseIntensityPct, 90);
    expect(result.recommendation?.intensityPct, 90);
    expect(result.factors?.totalCoefficient, 1);
  });

  test('Case B: female medium muscle index uses a 0.95 intensity factor', () {
    final result = evaluate(
      age: 30,
      sex: ParticipantSex.female,
      bodyFat: 20,
      muscleKg: 18,
    );
    expect(result.recommendation?.intensityPct, 86);
    expect(result.recommendation?.durationSec, 1800);
    expect(result.factors?.genderCoefficient, 0.95);
  });

  test('Case C: female and 70-plus factors reduce intensity', () {
    final result = evaluate(
      age: 75,
      sex: ParticipantSex.female,
      bodyFat: 20,
      muscleKg: 18,
    );
    expect(result.recommendation?.intensityPct, 81);
    expect(result.factors?.totalCoefficient, 0.9025);
  });

  test(
    'Case D: low skeletal muscle index selects the exact low whole-body preset',
    () {
      final result = evaluate(
        age: 75,
        sex: ParticipantSex.female,
        bodyFat: 20,
        muscleKg: 14,
      );
      expect(result.recommendation?.durationSec, 1500);
      expect(result.recommendation?.frequencyHz, 8);
      expect(result.recommendation?.intensityPct, 72);
      expect(result.factors?.bodyFatCoefficient, 1);
      expect(result.factors?.muscleLevel, 'low');
    },
  );

  test(
    'Case E: high skeletal muscle index selects the exact high whole-body preset',
    () {
      final result = evaluate(
        age: 85,
        sex: ParticipantSex.female,
        bodyFat: 20,
        muscleKg: 22,
      );
      expect(result.recommendation?.durationSec, 2100);
      expect(result.recommendation?.frequencyHz, 8);
      expect(result.recommendation?.intensityPct, 89);
      expect(result.factors?.muscleLevel, 'high');
    },
  );

  test(
    'classifies with the unrounded muscle index at a threshold boundary',
    () {
      final result = evaluate(
        age: 30,
        sex: ParticipantSex.male,
        bodyFat: 20,
        muscleKg: 24.57,
      );

      expect(24.57 / (1.7 * 1.7), greaterThan(8.5));
      expect(result.factors?.muscleIndexKgM2, 8.5);
      expect(result.factors?.muscleLevel, 'medium');
    },
  );

  test('calculates all six body parts from data', () {
    final all = calculateAllRecommendations(
      profile: const ParticipantProfile(
        id: 'P1',
        age: 30,
        sex: ParticipantSex.male,
        heightCm: 170,
      ),
      measurements: measurements(20, 28),
      safety: safety,
      evaluatedAt: DateTime.utc(2026, 9, 10),
    );
    expect(all.keys, containsAll(BodyPart.values));
    expect(all[BodyPart.shoulder]?.recommendation?.frequencyHz, 15);
    expect(all[BodyPart.thigh]?.recommendation?.durationSec, 600);
    expect(all[BodyPart.calf]?.recommendation?.intensityPct, 70);
  });

  test('applies configured reduction coefficients to simulator intensity', () {
    final rules = AlgorithmRuleSet(
      version: pilotRuleSet.version,
      enabled: pilotRuleSet.enabled,
      baselines: pilotRuleSet.baselines,
      femaleCoefficient: 0.95,
      maleCoefficient: pilotRuleSet.maleCoefficient,
      ageUnder60Coefficient: pilotRuleSet.ageUnder60Coefficient,
      ageSixtiesCoefficient: pilotRuleSet.ageSixtiesCoefficient,
      ageSeventiesCoefficient: 0.9,
      ageEightyPlusCoefficient: pilotRuleSet.ageEightyPlusCoefficient,
      femaleBodyFat: pilotRuleSet.femaleBodyFat,
      maleBodyFat: pilotRuleSet.maleBodyFat,
      femaleMuscleIndex: pilotRuleSet.femaleMuscleIndex,
      maleMuscleIndex: pilotRuleSet.maleMuscleIndex,
      lowBodyFatCoefficient: pilotRuleSet.lowBodyFatCoefficient,
      normalBodyFatCoefficient: pilotRuleSet.normalBodyFatCoefficient,
      highBodyFatCoefficient: 0.95,
      muscleMassCoefficient: pilotRuleSet.muscleMassCoefficient,
      minimumPct: pilotRuleSet.minimumPct,
      maximumPct: pilotRuleSet.maximumPct,
    );
    final result = evaluate(
      age: 75,
      sex: ParticipantSex.female,
      bodyFat: 36,
      muscleKg: 18,
      rules: rules,
    );
    expect(result.recommendation?.baseIntensityPct, 90);
    expect(result.recommendation?.intensityPct, 73);
    expect(result.factors?.genderCoefficient, 0.95);
    expect(result.factors?.ageCoefficient, 0.9);
    expect(result.factors?.bodyFatCoefficient, 0.95);
    expect(result.factors?.totalCoefficient, closeTo(0.81225, 0.000001));
    expect(result.factors?.calculatedIntensityPct, closeTo(73.1025, 0.000001));
  });
}
