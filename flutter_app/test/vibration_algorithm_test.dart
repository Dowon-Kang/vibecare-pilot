import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/domain/models.dart';
import 'package:vibecare_pilot/domain/vibration_algorithm.dart';

void main() {
  final measurements = <BiaMeasurement>[
    _m('M1', 42, 17.7, 18.8, 7.9, 18.1),
    _m('M2', 42.2, 17.8, 18.7, 7.9, 18),
    _m('M3', 41.9, 17.7, 19.1, 8, 18.2),
    _m('M4', 42.1, 17.8, 18.9, 8, 18.1),
  ];

  test('4회 평균과 여성 PILOT 결과가 fixture와 일치한다', () {
    final result = calculateRecommendation(
      profile: const ParticipantProfile(
        id: 'USER-001',
        age: 72,
        sex: ParticipantSex.female,
        heightCm: 154,
      ),
      measurements: measurements,
      safety: const SafetyCheck(),
    );
    expect(result.average?.weightKg, 42.05);
    expect(result.average?.bodyFatPct, 18.88);
    expect(result.recommendation?.intensityPct, 38);
    expect(result.status, RecommendationStatus.review);
  });

  test('같은 값의 남성 결과는 45%다', () {
    final result = calculateRecommendation(
      profile: const ParticipantProfile(
        id: 'USER-001',
        age: 72,
        sex: ParticipantSex.male,
        heightCm: 154,
      ),
      measurements: measurements,
      safety: const SafetyCheck(),
    );
    expect(result.recommendation?.intensityPct, 45);
  });

  test('어지럼은 추천과 실행을 차단한다', () {
    final result = calculateRecommendation(
      profile: const ParticipantProfile(
        id: 'USER-001',
        age: 72,
        sex: ParticipantSex.female,
        heightCm: 154,
      ),
      measurements: measurements,
      safety: const SafetyCheck(dizziness: true),
    );
    expect(result.status, RecommendationStatus.blocked);
    expect(result.recommendation, isNull);
    expect(result.canRequestAuthorization, isFalse);
  });

  test('3건 또는 중복 ID는 실행할 수 없다', () {
    final three = calculateRecommendation(
      profile: const ParticipantProfile(
        id: 'USER-001',
        age: 60,
        sex: ParticipantSex.male,
        heightCm: 154,
      ),
      measurements: measurements.take(3).toList(),
      safety: const SafetyCheck(),
    );
    expect(three.status, RecommendationStatus.review);
    expect(three.recommendation, isNull);

    final duplicate = calculateRecommendation(
      profile: const ParticipantProfile(
        id: 'USER-001',
        age: 60,
        sex: ParticipantSex.male,
        heightCm: 154,
      ),
      measurements: [
        measurements[0],
        measurements[0],
        measurements[2],
        measurements[3],
      ],
      safety: const SafetyCheck(),
    );
    expect(duplicate.status, RecommendationStatus.review);
  });

  test('최근 유효한 서로 다른 4건만 선택한다', () {
    final history = [
      ...measurements,
      _m('M5', 42, 17.7, 18.8, 7.9, 18.1, minute: 5),
      _m('M5', 42, 17.7, 18.8, 7.9, 18.1, minute: 4),
      BiaMeasurement(
        id: 'OTHER',
        participantId: 'OTHER-USER',
        deviceId: 'FITRUS-PLUS-01',
        measuredAt: DateTime.utc(2026, 8, 22, 0, 6),
        qualityPassed: true,
        values: measurements.first.values,
      ),
    ];
    final selected = selectLatestValidMeasurements(
      participantId: 'USER-001',
      deviceId: 'FITRUS-PLUS-01',
      candidates: history,
    );
    expect(selected, hasLength(4));
    expect(selected.first.id, 'M5');
    expect(selected.map((item) => item.id).toSet(), hasLength(4));
    expect(selected.any((item) => item.participantId != 'USER-001'), isFalse);
  });
}

BiaMeasurement _m(
  String id,
  double weight,
  double bmi,
  double bodyFat,
  double fatMass,
  double muscle, {
  int minute = 0,
}) {
  return BiaMeasurement(
    id: id,
    participantId: 'USER-001',
    deviceId: 'FITRUS-PLUS-01',
    measuredAt: DateTime.utc(2026, 8, 22, 0, minute),
    qualityPassed: true,
    values: BiaValues(
      weightKg: weight,
      bmi: bmi,
      bodyFatPct: bodyFat,
      fatMassKg: fatMass,
      skeletalMuscleMassKg: muscle,
    ),
  );
}
