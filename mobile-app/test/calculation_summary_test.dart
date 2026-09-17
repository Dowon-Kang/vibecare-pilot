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
            durationSec: 1800,
            frequencyHz: 8,
            intensityPct: 73,
            baseIntensityPct: 90,
          )
        : null,
    algorithmVersion: 'test',
    bodyPart: BodyPart.wholeBody,
    factors: status == RecommendationStatus.ready
        ? const AlgorithmFactors(
            genderCoefficient: .95,
            ageCoefficient: .9,
            bodyFatCoefficient: .95,
            muscleMassCoefficient: 1,
            totalCoefficient: .8123,
            calculatedIntensityPct: 73.1,
            bodyFatBand: 'low',
          )
        : null,
    measurementIds: List.generate(count, (i) => '$i'),
  );
  String explain(AlgorithmResult value) => calculationSummary(
    result: value,
    profile: profile,
    selectedIntensityPct: 73,
  ).map((step) => '${step.title}\n${step.detail}').join('\n');

  test('explains baseline, each coefficient and final value', () {
    final text = explain(result());
    expect(text, contains('30분 · 8Hz · 출력 90%'));
    expect(text, contains('성별 ×0.95'));
    expect(text, contains('연령 ×0.90'));
    expect(text, contains('90% × 0.8123 = 73.10%'));
    expect(text, contains('프로토타입 가설'));
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
