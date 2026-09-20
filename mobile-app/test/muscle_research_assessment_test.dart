import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/muscle_research_assessment.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';
import 'package:vibecare_pilot/models/models.dart';

void main() {
  test('최신 체지방률을 여성 경계로 분류하고 직전값과 비교한다', () {
    final assessment = buildBodyFatResearchAssessment(
      profile: const ParticipantProfile(
        id: 'P1',
        age: 72,
        sex: ParticipantSex.female,
        heightCm: 150,
      ),
      history: [
        _measurement('new', 18.8, DateTime.utc(2026, 9, 18)),
        _measurement('old', 18.7, DateTime.utc(2026, 9, 17)),
      ],
      ruleSet: pilotRuleSet,
    );

    expect(assessment, isNotNull);
    expect(assessment!.level, BodyFatResearchLevel.low);
    expect(assessment.currentPct, 18.8);
    expect(assessment.deltaPct, closeTo(0.1, 0.001));
  });

  test('남성 체지방 경계는 낮음, 중간, 높음을 구분한다', () {
    const profile = ParticipantProfile(
      id: 'P1',
      age: 45,
      sex: ParticipantSex.male,
      heightCm: 180,
    );

    BodyFatResearchAssessment? assess(double bodyFat) =>
        buildBodyFatResearchAssessment(
          profile: profile,
          history: [
            _measurement('M-$bodyFat', bodyFat, DateTime.utc(2026, 9, 18)),
          ],
          ruleSet: pilotRuleSet,
        );

    expect(assess(9)!.level, BodyFatResearchLevel.low);
    expect(assess(20)!.level, BodyFatResearchLevel.medium);
    expect(assess(29)!.level, BodyFatResearchLevel.high);
  });
}

BiaMeasurement _measurement(
  String id,
  double bodyFatPct,
  DateTime measuredAt,
) => BiaMeasurement(
  id: id,
  participantId: 'P1',
  deviceId: 'BIA-1',
  measuredAt: measuredAt,
  qualityPassed: true,
  values: BiaValues(
    weightKg: 60,
    bmi: 22,
    bodyFatPct: bodyFatPct,
    fatMassKg: 60 * bodyFatPct / 100,
    skeletalMuscleMassKg: 24,
  ),
);
