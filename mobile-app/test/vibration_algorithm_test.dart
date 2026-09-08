import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/algorithm/vibration_algorithm.dart';

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
      safety: const SafetyCheck.confirmedClear(),
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
      safety: const SafetyCheck.confirmedClear(),
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
      safety: const SafetyCheck.confirmedClear(),
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
      safety: const SafetyCheck.confirmedClear(),
    );
    expect(duplicate.status, RecommendationStatus.review);
  });

  test('공유 fixture JSON으로 웹과 서버와 같은 결과를 확인한다', () {
    final f =
        jsonDecode(
              File('../shared-contracts/fixtures/pilot-0.3.0.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final rows = (f['measurements'] as List).map((m) {
      final v = m['values'];
      return _m(
        m['id'],
        (v['weightKg'] as num).toDouble(),
        (v['bmi'] as num).toDouble(),
        (v['bodyFatPct'] as num).toDouble(),
        (v['fatMassKg'] as num).toDouble(),
        (v['skeletalMuscleMassKg'] as num).toDouble(),
      );
    }).toList();
    final p = f['profile'];
    final result = calculateRecommendation(
      profile: ParticipantProfile(
        id: p['participantId'],
        age: p['age'],
        sex: ParticipantSex.values.byName(p['sex']),
        heightCm: (p['heightCm'] as num).toDouble(),
      ),
      measurements: rows,
      safety: const SafetyCheck.confirmedClear(),
    );
    expect(
      result.recommendation?.intensityPct,
      f['expected']['femaleIntensityPct'],
    );
    expect(result.average?.bmi, f['expected']['averageBmi']);
    expect(result.status, RecommendationStatus.review);
  });

  test('미응답 안전 확인은 미리보기만 허용한다', () {
    final rows = [for (var i = 0; i < 4; i++) _m('S$i', 45, 20, 25, 11.25, 18)];
    final result = calculateRecommendation(
      profile: const ParticipantProfile(
        id: 'USER-001',
        age: 72,
        sex: ParticipantSex.female,
        heightCm: 150,
      ),
      measurements: rows,
      safety: const SafetyCheck(),
    );
    expect(result.status, RecommendationStatus.review);
    expect(result.recommendation, isNotNull);
    expect(result.canRequestAuthorization, isFalse);
    expect(result.average?.waistCm, isNull);
  });

  test('숫자 오류와 모순된 체지방량은 충돌 없이 차단한다', () {
    for (final fat in [double.nan, double.infinity, 0.0, -1.0, 101.0]) {
      final rows = [
        for (var i = 0; i < 4; i++) _m('S$i', 45, 20, fat, 11.25, 18),
      ];
      final result = calculateRecommendation(
        profile: const ParticipantProfile(
          id: 'USER-001',
          age: 72,
          sex: ParticipantSex.female,
          heightCm: 150,
        ),
        measurements: rows,
        safety: const SafetyCheck.confirmedClear(),
      );
      expect(result.recommendation, isNull);
      expect(result.average, isNull);
    }
    final result = calculateRecommendation(
      profile: const ParticipantProfile(
        id: 'USER-001',
        age: 72,
        sex: ParticipantSex.female,
        heightCm: 150,
      ),
      measurements: [for (var i = 0; i < 4; i++) _m('S$i', 45, 20, 25, 1, 18)],
      safety: const SafetyCheck.confirmedClear(),
    );
    expect(result.recommendation, isNull);
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
