import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/calculation_summary.dart';
import 'package:vibecare_pilot/models/models.dart';

void main() {
  const profile = ParticipantProfile(
    id: 'synthetic',
    age: 75,
    sex: ParticipantSex.female,
    heightCm: 150,
  );
  AlgorithmResult result({
    RecommendationStatus status = RecommendationStatus.ready,
    int count = 4,
  }) => AlgorithmResult(
    status: status,
    average: const BiaValues(
      weightKg: 42,
      bmi: 18.7,
      bodyFatPct: 18,
      fatMassKg: 7.6,
      skeletalMuscleMassKg: 18.1,
    ),
    warnings: const [],
    adjustments: const [],
    recommendation: status == RecommendationStatus.ready
        ? const Recommendation(
            durationSec: 1500,
            frequencyHz: 8,
            intensityPct: 80,
            baseIntensityPct: 80,
          )
        : null,
    algorithmVersion: 'test',
    bodyPart: BodyPart.wholeBody,
    factors: status == RecommendationStatus.ready
        ? const AlgorithmFactors(
            genderCoefficient: 1,
            ageCoefficient: 1,
            bodyFatCoefficient: 1,
            muscleMassCoefficient: 1,
            totalCoefficient: 1,
            calculatedIntensityPct: 80,
            muscleLevel: 'low',
            muscleIndexKgM2: 5.7,
          )
        : null,
    measurementIds: List.generate(count, (i) => '$i'),
  );
  String explain(AlgorithmResult value) => calculationSummary(
    result: value,
    profile: profile,
    selectedIntensityPct: 80,
  ).map((step) => '${step.title}\n${step.detail}').join('\n');

  test('explains the fixed skeletal-muscle level mapping and final value', () {
    final text = explain(result());
    expect(text, contains('25분 · 8Hz · 출력 80%'));
    expect(text, contains('근육지수 5.70kg/m²'));
    expect(text, contains('낮음 등급'));
    expect(text, contains('추가 보정 없이 적용'));
    expect(text, contains('강도 80%'));
  });
  test('blocked result never shows a candidate', () {
    final text = explain(result(status: RecommendationStatus.blocked));
    expect(text, contains('사용 보류'));
    expect(text, isNot(contains('8Hz')));
  });
  test('insufficient records require review', () {
    expect(explain(result(count: 3)), contains('측정값 확인 필요'));
  });
}
